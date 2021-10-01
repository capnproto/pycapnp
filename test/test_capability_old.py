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

    def foo(self, i, j, **kwargs):
        extra = 0
        if j:
            extra = 1
        return str(i * 5 + extra + self.val)

    def buz(self, i, **kwargs):
        return i.host + "_test"


class PipelineServer:
    def getCap(self, n, inCap, _context, **kwargs):
        def _then(response):
            _results = _context.results
            _results.s = response.x + "_foo"
            _results.outBox.cap = capability().TestInterface._new_server(Server(100))

        return inCap.foo(i=n).then(_then)


def test_client(capability):
    client = capability.TestInterface._new_client(Server())

    req = client._request("foo")
    req.i = 5

    remote = req.send()
    response = remote.wait()

    assert response.x == "26"

    req = client.foo_request()
    req.i = 5

    remote = req.send()
    response = remote.wait()

    assert response.x == "26"

    with pytest.raises(AttributeError):
        client.foo2_request()

    req = client.foo_request()

    with pytest.raises(Exception):
        req.i = "foo"

    req = client.foo_request()

    with pytest.raises(AttributeError):
        req.baz = 1


def test_simple_client(capability):
    client = capability.TestInterface._new_client(Server())

    remote = client._send("foo", i=5)
    response = remote.wait()

    assert response.x == "26"

    remote = client.foo(i=5)
    response = remote.wait()

    assert response.x == "26"

    remote = client.foo(i=5, j=True)
    response = remote.wait()

    assert response.x == "27"

    remote = client.foo(5)
    response = remote.wait()

    assert response.x == "26"

    remote = client.foo(5, True)
    response = remote.wait()

    assert response.x == "27"

    remote = client.foo(5, j=True)
    response = remote.wait()

    assert response.x == "27"

    remote = client.buz(capability.TestSturdyRefHostId.new_message(host="localhost"))
    response = remote.wait()

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


@pytest.mark.xfail
def test_pipeline(capability):
    """
    E   capnp.lib.capnp.KjException: capnp/lib/capnp.pyx:61: failed: <class 'Failed'>:Fixture "capability" called directly. Fixtures are not meant to be called directly,
    E   but are created automatically when test functions request them as parameters.
    E   See https://docs.pytest.org/en/latest/fixture.html for more information about fixtures, and
    E   https://docs.pytest.org/en/latest/deprecations.html#calling-fixtures-directly about how to update your code.
    E   stack: 7f680f7fce40 7f680f4f9250 7f680f4f4260 7f680f4fa9f0 7f680f4f6f50 7f680f4fb540 7f680f50dbf0 7f680f801768 7f680f7e5185 7f680f7e52dc 7f680f7a3a1d 7f68115cb459 7f68115cb713 7f68115fd2eb 7f6811637409 7f68115eb767 7f68115ece7e 7f681163448d 7f68115eb767 7f68115ece7e 7f681163448d 7f68115eb767 7f68115ec7d2 7f68115fd1cf 7f6811633b77 7f68115eb767 7f68115ec7d2 7f68115fd1cf 7f6811637409 7f68115ec632 7f68115fd1cf 7f6811637409
    """
    client = capability.TestPipeline._new_client(PipelineServer())
    foo_client = capability.TestInterface._new_client(Server())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    response = pipelinePromise.wait()
    assert response.x == "150"

    response = remote.wait()
    assert response.s == "26_foo"


class BadServer:
    def __init__(self, val=1):
        self.val = val

    def foo(self, i, j, **kwargs):
        extra = 0
        if j:
            extra = 1
        return str(i * 5 + extra + self.val), 10  # returning too many args


def test_exception_client(capability):
    client = capability.TestInterface._new_client(BadServer())

    remote = client._send("foo", i=5)
    with pytest.raises(capnp.KjException):
        remote.wait()


class BadPipelineServer:
    def getCap(self, n, inCap, _context, **kwargs):
        def _then(response):
            _results = _context.results
            _results.s = response.x + "_foo"
            _results.outBox.cap = capability().TestInterface._new_server(Server(100))

        def _error(error):
            raise Exception("test was a success")

        return inCap.foo(i=n).then(_then, _error)


def test_exception_chain(capability):
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    try:
        remote.wait()
    except Exception as e:
        assert "test was a success" in str(e)


def test_pipeline_exception(capability):
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    with pytest.raises(Exception):
        pipelinePromise.wait()

    with pytest.raises(Exception):
        remote.wait()


def test_casting(capability):
    client = capability.TestExtends._new_client(Server())
    client2 = client.upcast(capability.TestInterface)
    _ = client2.cast_as(capability.TestInterface)

    with pytest.raises(Exception):
        client.upcast(capability.TestPipeline)


class TailCallOrder:
    def __init__(self):
        self.count = -1

    def getCallSequence(self, expected, **kwargs):
        self.count += 1
        return self.count


class TailCaller:
    def __init__(self):
        self.count = 0

    def foo(self, i, callee, _context, **kwargs):
        self.count += 1

        tail = callee.foo_request(i=i, t="from TailCaller")
        return _context.tail_call(tail)


class TailCallee:
    def __init__(self):
        self.count = 0

    def foo(self, i, t, _context, **kwargs):
        self.count += 1

        results = _context.results
        results.i = i
        results.t = t
        results.c = capability().TestCallOrder._new_server(TailCallOrder())


@pytest.mark.xfail
def test_tail_call(capability):
    """
    E   capnp.lib.capnp.KjException: capnp/lib/capnp.pyx:104: failed: <class 'Failed'>:Fixture "capability" called directly. Fixtures are not meant to be called directly,
    E   but are created automatically when test functions request them as parameters.
    E   See https://docs.pytest.org/en/latest/fixture.html for more information about fixtures, and
    E   https://docs.pytest.org/en/latest/deprecations.html#calling-fixtures-directly about how to update your code.
    E   stack: 7f680f4fb540 7f680f4fb1b0 7f680f4fb540 7f680f50dbf0 7f680f801768 7f680f7e5185 7f680f7e52dc 7f680f7a3a1d 7f68115cb459 7f68115cb713 7f68115fd2eb 7f6811637409 7f68115eb767 7f68115ece7e 7f681163448d 7f68115eb767 7f68115ece7e 7f681163448d 7f68115eb767 7f68115ec7d2 7f68115fd1cf 7f6811633b77 7f68115eb767 7f68115ec7d2 7f68115fd1cf 7f6811637409 7f68115ec632 7f68115fd1cf 7f6811637409 7f68115eb767 7f68115ece7e 7f68115c0ce7
    """
    callee_server = TailCallee()
    caller_server = TailCaller()

    callee = capability.TestTailCallee._new_client(callee_server)
    caller = capability.TestTailCaller._new_client(caller_server)

    promise = caller.foo(i=456, callee=callee)
    dependent_call1 = promise.c.getCallSequence()

    response = promise.wait()

    assert response.i == 456
    assert response.i == 456

    dependent_call2 = response.c.getCallSequence()
    dependent_call3 = response.c.getCallSequence()

    result = dependent_call1.wait()
    assert result.n == 0
    result = dependent_call2.wait()
    assert result.n == 1
    result = dependent_call3.wait()
    assert result.n == 2

    assert callee_server.count == 1
    assert caller_server.count == 1
