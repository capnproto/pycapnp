import pytest

import capnp
import test_capability_capnp as capability


@pytest.fixture(autouse=True)
async def kj_loop():
    async with capnp.kj_loop():
        yield


class Server(capability.TestInterface.Server):
    def __init__(self, val=1):
        self.val = val

    async def foo_context(self, context):
        extra = 0
        if context.params.j:
            extra = 1
        context.results.x = str(context.params.i * 5 + extra + self.val)

    async def buz_context(self, context):
        context.results.x = context.params.i.host + "_test"


class PipelineServer(capability.TestPipeline.Server):
    async def getCap_context(self, context):
        response = await context.params.inCap.foo(i=context.params.n)
        context.results.s = response.x + "_foo"
        context.results.outBox.cap = Server(100)


async def test_client_context():
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


async def test_simple_client_context():
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


async def test_pipeline_context():
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

    async def foo_context(self, context):
        context.results.x = str(context.params.i * 5 + self.val)
        context.results.x2 = 5  # raises exception


async def test_exception_client_context():
    client = capability.TestInterface._new_client(BadServer())

    remote = client._send("foo", i=5)
    with pytest.raises(capnp.KjException):
        await remote


class BadPipelineServer(capability.TestPipeline.Server):
    async def getCap_context(self, context):
        try:
            await context.params.inCap.foo(i=context.params.n)
        except capnp.KjException:
            raise Exception("test was a success")


async def test_exception_chain_context():
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    try:
        await remote
    except Exception as e:
        assert "test was a success" in str(e)


async def test_pipeline_exception_context():
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    with pytest.raises(Exception):
        await pipelinePromise

    with pytest.raises(Exception):
        await remote


async def test_casting_context():
    client = capability.TestExtends._new_client(Server())
    client2 = client.upcast(capability.TestInterface)
    _ = client2.cast_as(capability.TestInterface)

    with pytest.raises(Exception):
        client.upcast(capability.TestPipeline)


class TailCallOrder(capability.TestCallOrder.Server):
    def __init__(self):
        self.count = -1

    async def getCallSequence_context(self, context):
        self.count += 1
        context.results.n = self.count


class TailCaller(capability.TestTailCaller.Server):
    def __init__(self):
        self.count = 0

    async def foo_context(self, context):
        self.count += 1

        tail = context.params.callee.foo_request(
            i=context.params.i, t="from TailCaller"
        )
        await context.tail_call(tail)


class TailCallee(capability.TestTailCallee.Server):
    def __init__(self):
        self.count = 0

    async def foo_context(self, context):
        self.count += 1

        results = context.results
        results.i = context.params.i
        results.t = context.params.t
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
