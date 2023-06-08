import os
import pytest

import capnp

this_dir = os.path.dirname(__file__)

# flake8: noqa: E501


@pytest.fixture
def capability():
    return capnp.load(os.path.join(this_dir, "test_capability.capnp"))


class Server:
    def __init__(self, val=1):
        self.val = val

    async def foo(self, i, j, **kwargs):
        extra = 0
        if j:
            extra = 1
        return str(i * 5 + extra + self.val)

    async def buz(self, i, **kwargs):
        return i.host + "_test"


class PipelineServer:
    def __init__(self, capability):
        self.capability = capability

    async def getCap(self, n, inCap, _context, **kwargs):
        response = await inCap.foo(i=n)
        _results = _context.results
        _results.s = response.x + "_foo"
        _results.outBox.cap = self.capability.TestInterface._new_server(Server(100))


async def test_client(capability):
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


async def test_simple_client(capability):
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


async def test_pipeline(capability):
    client = capability.TestPipeline._new_client(PipelineServer(capability))
    foo_client = capability.TestInterface._new_client(Server())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    response = await pipelinePromise
    assert response.x == "150"

    response = await remote
    assert response.s == "26_foo"


class BadServer:
    def __init__(self, val=1):
        self.val = val

    async def foo(self, i, j, **kwargs):
        extra = 0
        if j:
            extra = 1
        return str(i * 5 + extra + self.val), 10  # returning too many args


async def test_exception_client(capability):
    client = capability.TestInterface._new_client(BadServer())

    remote = client._send("foo", i=5)
    with pytest.raises(capnp.KjException):
        await remote


class BadPipelineServer:
    def __init__(self, capability):
        self.capability = capability

    async def getCap(self, n, inCap, _context, **kwargs):
        try:
            await inCap.foo(i=n)
        except capnp.KjException:
            raise Exception("test was a success")


async def test_exception_chain(capability):
    client = capability.TestPipeline._new_client(BadPipelineServer(capability))
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    try:
        await remote
    except Exception as e:
        assert "test was a success" in str(e)


async def test_pipeline_exception(capability):
    client = capability.TestPipeline._new_client(BadPipelineServer(capability))
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    with pytest.raises(Exception):
        await pipelinePromise

    with pytest.raises(Exception):
        await remote


async def test_casting(capability):
    client = capability.TestExtends._new_client(Server())
    client2 = client.upcast(capability.TestInterface)
    _ = client2.cast_as(capability.TestInterface)

    with pytest.raises(Exception):
        client.upcast(capability.TestPipeline)


class TailCallOrder:
    def __init__(self):
        self.count = -1

    async def getCallSequence(self, expected, **kwargs):
        self.count += 1
        return self.count


class TailCaller:
    def __init__(self):
        self.count = 0

    async def foo(self, i, callee, _context, **kwargs):
        self.count += 1

        tail = callee.foo_request(i=i, t="from TailCaller")
        await _context.tail_call(tail)


class TailCallee:
    def __init__(self, capability):
        self.count = 0
        self.capability = capability

    async def foo(self, i, t, _context, **kwargs):
        self.count += 1

        results = _context.results
        results.i = i
        results.t = t
        results.c = self.capability.TestCallOrder._new_server(TailCallOrder())


async def test_tail_call(capability):
    callee_server = TailCallee(capability)
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
