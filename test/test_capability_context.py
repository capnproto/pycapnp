import os
import pytest

import capnp

this_dir = os.path.dirname(__file__)

# flake8: noqa: E501


@pytest.fixture
def capability():
    capnp.cleanup_global_schema_parser()
    return capnp.load(os.path.join(this_dir, "test_capability.capnp"))


class Server:
    def __init__(self, val=1):
        self.val = val

    def foo_context(self, context):
        extra = 0
        if context.params.j:
            extra = 1
        context.results.x = str(context.params.i * 5 + extra + self.val)

    def buz_context(self, context):
        context.results.x = context.params.i.host + "_test"


class PipelineServer:
    def getCap_context(self, context):
        def _then(response):
            context.results.s = response.x + "_foo"
            context.results.outBox.cap = capability().TestInterface._new_server(
                Server(100)
            )

        return context.params.inCap.foo(i=context.params.n).then(_then)


def test_client_context(capability):
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


def test_simple_client_context(capability):
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
def test_pipeline_context(capability):
    """
    E   capnp.lib.capnp.KjException: capnp/lib/capnp.pyx:61: failed: <class 'Failed'>:Fixture "capability" called directly. Fixtures are not meant to be called directly,
    E   but are created automatically when test functions request them as parameters.
    E   See https://docs.pytest.org/en/latest/fixture.html for more information about fixtures, and
    E   https://docs.pytest.org/en/latest/deprecations.html#calling-fixtures-directly about how to update your code.
    E   stack: 7f87c1ac6e40 7f87c17c3250 7f87c17be260 7f87c17c49f0 7f87c17c0f50 7f87c17c5540 7f87c17d7bf0 7f87c1acb768 7f87c1aaf185 7f87c1aaf2dc 7f87c1a6da1d 7f87c3895459 7f87c3895713 7f87c38c72eb 7f87c3901409 7f87c38b5767 7f87c38b6e7e 7f87c38fe48d 7f87c38b5767 7f87c38b6e7e 7f87c38fe48d 7f87c38b5767 7f87c38b67d2 7f87c38c71cf 7f87c38fdb77 7f87c38b5767 7f87c38b67d2 7f87c38c71cf 7f87c3901409 7f87c38b6632 7f87c38c71cf 7f87c3901409
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

    def foo_context(self, context):
        context.results.x = str(context.params.i * 5 + self.val)
        context.results.x2 = 5  # raises exception


def test_exception_client_context(capability):
    client = capability.TestInterface._new_client(BadServer())

    remote = client._send("foo", i=5)
    with pytest.raises(capnp.KjException):
        remote.wait()


class BadPipelineServer:
    def getCap_context(self, context):
        def _then(response):
            context.results.s = response.x + "_foo"
            context.results.outBox.cap = capability().TestInterface._new_server(
                Server(100)
            )

        def _error(error):
            raise Exception("test was a success")

        return context.params.inCap.foo(i=context.params.n).then(_then, _error)


def test_exception_chain_context(capability):
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    try:
        remote.wait()
    except Exception as e:
        assert "test was a success" in str(e)


def test_pipeline_exception_context(capability):
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    with pytest.raises(Exception):
        pipelinePromise.wait()

    with pytest.raises(Exception):
        remote.wait()


def test_casting_context(capability):
    client = capability.TestExtends._new_client(Server())
    client2 = client.upcast(capability.TestInterface)
    _ = client2.cast_as(capability.TestInterface)

    with pytest.raises(Exception):
        client.upcast(capability.TestPipeline)


class TailCallOrder:
    def __init__(self):
        self.count = -1

    def getCallSequence_context(self, context):
        self.count += 1
        context.results.n = self.count


class TailCaller:
    def __init__(self):
        self.count = 0

    def foo_context(self, context):
        self.count += 1

        tail = context.params.callee.foo_request(
            i=context.params.i, t="from TailCaller"
        )
        return context.tail_call(tail)


class TailCallee:
    def __init__(self):
        self.count = 0

    def foo_context(self, context):
        self.count += 1

        results = context.results
        results.i = context.params.i
        results.t = context.params.t
        results.c = capability().TestCallOrder._new_server(TailCallOrder())


@pytest.mark.xfail
def test_tail_call(capability):
    """
    E   capnp.lib.capnp.KjException: capnp/lib/capnp.pyx:75: failed: <class 'Failed'>:Fixture "capability" called directly. Fixtures are not meant to be called directly,
    E   but are created automatically when test functions request them as parameters.
    E   See https://docs.pytest.org/en/latest/fixture.html for more information about fixtures, and
    E   https://docs.pytest.org/en/latest/deprecations.html#calling-fixtures-directly about how to update your code.
    E   stack: 7f87c17c5540 7f87c17c51b0 7f87c17c5540 7f87c17d7bf0 7f87c1acb768 7f87c1aaf185 7f87c1aaf2dc 7f87c1a6da1d 7f87c3895459 7f87c3895713 7f87c38c72eb 7f87c3901409 7f87c38b5767 7f87c38b6e7e 7f87c38fe48d 7f87c38b5767 7f87c38b6e7e 7f87c38fe48d 7f87c38b5767 7f87c38b67d2 7f87c38c71cf 7f87c38fdb77 7f87c38b5767 7f87c38b67d2 7f87c38c71cf 7f87c3901409 7f87c38b6632 7f87c38c71cf 7f87c3901409 7f87c38b5767 7f87c38b6e7e 7f87c388ace7
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
