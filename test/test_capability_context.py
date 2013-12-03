import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)

@pytest.fixture
def capability():
     return capnp.load(os.path.join(this_dir, 'test_capability.capnp'))

class Server:
    def __init__(self, val=1):
        self.val = val

    def foo_context(self, context):
        extra = 0
        if context.params.j:
            extra = 1
        context.results.x = str(context.params.i * 5 + extra + self.val)

    def buz_context(self, context):
        context.results.x = context.params.i.host + '_test'

class PipelineServer:
    def getCap_context(self, context):
        def _then(response):
            context.results.s = response.x + '_foo'
            context.results.outBox.cap = capability().TestInterface.new_server(Server(100))

        return context.params.inCap.foo(i=context.params.n).then(_then)

def test_client(capability):
    client = capability.TestInterface._new_client(Server())
    
    req = client._request('foo')
    req.i = 5

    remote = req.send()
    response = remote.wait()

    assert response.x == '26'
    
    req = client.foo_request()
    req.i = 5

    remote = req.send()
    response = remote.wait()

    assert response.x == '26'

    with pytest.raises(ValueError):
        client.foo2_request()

    req = client.foo_request()

    with pytest.raises(ValueError):
        req.i = 'foo'

    req = client.foo_request()

    with pytest.raises(ValueError):
        req.baz = 1

def test_simple_client(capability):
    client = capability.TestInterface._new_client(Server())
    
    remote = client._send('foo', i=5)
    response = remote.wait()

    assert response.x == '26'

    
    remote = client.foo(i=5)
    response = remote.wait()

    assert response.x == '26'
    
    remote = client.foo(i=5, j=True)
    response = remote.wait()

    assert response.x == '27'

    remote = client.foo(5)
    response = remote.wait()

    assert response.x == '26'

    remote = client.foo(5, True)
    response = remote.wait()

    assert response.x == '27'

    remote = client.foo(5, j=True)
    response = remote.wait()

    assert response.x == '27'

    remote = client.buz(capability.TestSturdyRefHostId.new_message(host='localhost'))
    response = remote.wait()

    assert response.x == 'localhost_test'

    with pytest.raises(ValueError):
        remote = client.foo(5, 10)

    with pytest.raises(ValueError):
        remote = client.foo(5, True, 100)

    with pytest.raises(ValueError):
        remote = client.foo(i='foo')

    with pytest.raises(ValueError):
        remote = client.foo2(i=5)

    with pytest.raises(ValueError):
        remote = client.foo(baz=5)

def test_pipeline(capability):
    client = capability.TestPipeline._new_client(PipelineServer())
    foo_client = capability.TestInterface._new_client(Server())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    response = pipelinePromise.wait()
    assert response.x == '150'

    response = remote.wait()
    assert response.s == '26_foo'

class BadServer:
    def __init__(self, val=1):
        self.val = val

    def foo_context(self, context):
        context.results.x = str(context.params.i * 5 + self.val)
        context.results.x2 = 5 # raises exception

def test_exception_client(capability):
    client = capability.TestInterface._new_client(BadServer())
    
    remote = client._send('foo', i=5)
    with pytest.raises(capnp.KjException):
        remote.wait()

class BadPipelineServer:
    def getCap_context(self, context):
        def _then(response):
            context.results.s = response.x + '_foo'
            context.results.outBox.cap = capability().TestInterface.new_server(Server(100))
        def _error(error):
            raise Exception('test was a success')

        return context.params.inCap.foo(i=context.params.n).then(_then, _error)

def test_exception_chain(capability):
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    try:
        remote.wait()
    except Exception as e:
        assert 'test was a success' in str(e)

def test_pipeline_exception(capability):
    client = capability.TestPipeline._new_client(BadPipelineServer())
    foo_client = capability.TestInterface._new_client(BadServer())

    remote = client.getCap(n=5, inCap=foo_client)

    outCap = remote.outBox.cap
    pipelinePromise = outCap.foo(i=10)

    with pytest.raises(Exception):
        loop.wait(pipelinePromise)

    with pytest.raises(Exception):
        remote.wait()

def test_casting(capability):
    client = capability.TestExtends._new_client(Server())
    client2 = client.upcast(capability.TestInterface)
    client3 = client2.cast_as(capability.TestInterface)

    with pytest.raises(Exception):
        client.upcast(capability.TestPipeline)
