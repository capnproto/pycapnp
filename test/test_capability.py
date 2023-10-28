import pytest
import asyncio

import capnp
import test_capability_capnp as capability


@pytest.fixture(autouse=True)
async def kj_loop():
    async with capnp.kj_loop():
        yield


class Server(capability.TestInterface.Server):
    def __init__(self, val=1):
        self.val = val

    async def foo(self, i, j, **kwargs):
        extra = 0
        if j:
            extra = 1
        return str(i * 5 + extra + self.val)

    async def buz(self, i, **kwargs):
        return i.host + "_test"

    async def bam(self, i, **kwargs):
        return str(i) + "_test", i

    async def bak1(self, **kwargs):
        return [1, 2, 3, 4, 5]

    async def bak2(self, i, **kwargs):
        assert i[4] == 5


class PipelineServer(capability.TestPipeline.Server):
    async def getCap(self, n, inCap, _context, **kwargs):
        response = await inCap.foo(i=n)
        _results = _context.results
        _results.s = response.x + "_foo"
        _results.outBox.cap = Server(100)


async def test_client():
    client = capability.TestInterface._new_client(Server())

    req = client._request("foo")
    req.i = 5

    remote = req.send()
    response = await remote

    assert response.x == "26"

    req = client.foo_request()
    req.i = 5

    remote = req.send()
    response = await remote

    assert response.x == "26"

    with pytest.raises(AttributeError):
        client.foo2_request()

    req = client.foo_request()

    with pytest.raises(Exception):
        req.i = "foo"

    req = client.foo_request()

    with pytest.raises(AttributeError):
        req.baz = 1

    resp = await client.bak1()
    # Used to fail with
    # capnp.lib.capnp.KjException: Tried to set field: 'i' with a value of: '[1, 2, 3, 4, 5]'
    # which is an unsupported type: '<class 'capnp.lib.capnp._DynamicListReader'>'
    await client.bak2(resp.i)


async def test_simple_client():
    client = capability.TestInterface._new_client(Server())

    remote = client._send("foo", i=5)
    response = await remote

    assert response.x == "26"

    remote = client.foo(i=5)
    response = await remote

    assert response.x == "26"

    remote = client.foo(i=5, j=True)
    response = await remote

    assert response.x == "27"

    remote = client.foo(5)
    response = await remote

    assert response.x == "26"

    remote = client.foo(5, True)
    response = await remote

    assert response.x == "27"

    remote = client.foo(5, j=True)
    response = await remote

    assert response.x == "27"

    remote = client.buz(capability.TestSturdyRefHostId.new_message(host="localhost"))
    response = await remote

    assert response.x == "localhost_test"

    remote = client.bam(i=5)
    response = await remote

    assert response.x == "5_test"
    assert response.i == 5

    with pytest.raises(Exception):
        remote = client.foo(5, 10)

    with pytest.raises(Exception):
        remote = client.foo(5, True, 100)

    with pytest.raises(Exception):
        remote = client.foo(i="foo")

    with pytest.raises(AttributeError):
        remote = client.foo2(i=5)

    with pytest.raises(Exception):
        remote = client.foo(baz=5)


async def test_pipeline():
    client = capability.TestPipeline._new_client(PipelineServer())
    foo_client = capability.TestInterface._new_client(Server())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    response = await pipelinePromise
    assert response.x == "150"

    response = await remote
    assert response.s == "26_foo"


class BadServer(capability.TestInterface.Server):
    def __init__(self, val=1):
        self.val = val

    async def foo(self, i, j, **kwargs):
        extra = 0
        if j:
            extra = 1
        return str(i * 5 + extra + self.val), 10  # returning too many args


async def test_exception_client():
    client = capability.TestInterface._new_client(BadServer())

    remote = client._send("foo", i=5)
    with pytest.raises(capnp.KjException):
        await remote


class BadPipelineServer(capability.TestPipeline.Server):
    async def getCap(self, n, inCap, _context, **kwargs):
        try:
            await inCap.foo(i=n)
        except capnp.KjException:
            raise Exception("test was a success")


async def test_exception_chain():
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    try:
        await remote
    except Exception as e:
        assert "test was a success" in str(e)


async def test_pipeline_exception():
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    with pytest.raises(Exception):
        await pipelinePromise

    with pytest.raises(Exception):
        await remote


async def test_casting():
    client = capability.TestExtends._new_client(Server())
    client2 = client.upcast(capability.TestInterface)
    _ = client2.cast_as(capability.TestInterface)

    with pytest.raises(Exception):
        client.upcast(capability.TestPipeline)


class TailCallOrder(capability.TestCallOrder.Server):
    def __init__(self):
        self.count = -1

    async def getCallSequence(self, expected, **kwargs):
        self.count += 1
        return self.count


class TailCaller(capability.TestTailCaller.Server):
    def __init__(self):
        self.count = 0

    async def foo(self, i, callee, _context, **kwargs):
        self.count += 1

        tail = callee.foo_request(i=i, t="from TailCaller")
        return await _context.tail_call(tail)


class TailCallee(capability.TestTailCallee.Server):
    def __init__(self):
        self.count = 0

    async def foo(self, i, t, _context, **kwargs):
        self.count += 1

        results = _context.results
        results.i = i
        results.t = t
        results.c = TailCallOrder()


async def test_tail_call():
    callee_server = TailCallee()
    caller_server = TailCaller()

    callee = capability.TestTailCallee._new_client(callee_server)
    caller = capability.TestTailCaller._new_client(caller_server)

    promise = caller.foo(i=456, callee=callee)
    dependent_call1 = promise.c.getCallSequence()

    response = await promise

    assert response.i == 456
    assert response.i == 456

    dependent_call2 = response.c.getCallSequence()
    dependent_call3 = response.c.getCallSequence()

    result = await dependent_call1
    assert result.n == 0
    result = await dependent_call2
    assert result.n == 1
    result = await dependent_call3
    assert result.n == 2

    assert callee_server.count == 1
    assert caller_server.count == 1


async def test_cancel():
    client = capability.TestInterface._new_client(Server())

    req = client._request("foo")
    req.i = 5

    remote = req.send()
    remote.cancel()

    with pytest.raises(Exception):
        await remote

    req = client.foo(5)
    await req
    req.cancel()  # Cancel a promise that was already consumed

    req = client.foo(5)
    req.cancel()
    with pytest.raises(Exception):
        await req

    req = client.foo(5)
    assert (await req).x == "26"
    with pytest.raises(Exception):
        await req


async def test_double_send():
    client = capability.TestInterface._new_client(Server())

    req = client._request("foo")
    req.i = 5

    await req.send()
    with pytest.raises(Exception):
        await req.send()


class PromiseJoinServer(capability.TestPipeline.Server):
    async def getCap(self, n, inCap, _context, **kwargs):
        res = await inCap.foo(i=n)
        response = await inCap.foo(i=int(res.x) + 1)
        _results = _context.results
        _results.s = response.x + "_bar"
        _results.outBox.cap = inCap


async def test_promise_joining():
    client = capability.TestPipeline._new_client(PromiseJoinServer())
    foo_client = capability.TestInterface._new_client(Server())

    remote = client.getCap(n=5, inCap=foo_client)
    assert (await remote).s == "136_bar"


class ExtendsServer(Server):
    async def qux(self, **kwargs):
        pass


async def test_inheritance():
    client = capability.TestExtends._new_client(ExtendsServer())
    await client.qux()

    remote = client.foo(i=5)
    response = await remote

    assert response.x == "26"


class PassedCapTest(capability.TestPassedCap.Server):
    async def foo(self, cap, _context, **kwargs):
        res = await cap.foo(5)
        _context.results.x = res.x


async def test_null_cap():
    client = capability.TestPassedCap._new_client(PassedCapTest())
    assert (await client.foo(Server())).x == "26"

    with pytest.raises(capnp.KjException):
        await client.foo()


class StructArgTest(capability.TestStructArg.Server):
    async def bar(self, a, b, **kwargs):
        return a + str(b)


async def test_struct_args():
    client = capability.TestStructArg._new_client(StructArgTest())
    assert (await client.bar(a="test", b=1)).c == "test1"
    with pytest.raises(capnp.KjException):
        assert (await client.bar("test", 1)).c == "test1"


class GenericTest(capability.TestGeneric.Server):
    async def foo(self, a, **kwargs):
        return a.as_text() + "test"


async def test_generic():
    client = capability.TestGeneric._new_client(GenericTest())

    obj = capnp._MallocMessageBuilder().get_root_as_any()
    obj.set_as_text("anypointer_")
    assert (await client.foo(obj)).b == "anypointer_test"


class CancelServer(capability.TestInterface.Server):
    def __init__(self, val=1):
        self.val = val

    async def foo(self, i, j, **kwargs):
        with pytest.raises(asyncio.CancelledError):
            await asyncio.sleep(10)


async def test_cancel2():
    client = capability.TestInterface._new_client(CancelServer())

    task = asyncio.ensure_future(client.foo(1, True))
    await asyncio.sleep(0)  # Make sure that the task runs
    task.cancel()
    with pytest.raises(asyncio.CancelledError):
        await task
