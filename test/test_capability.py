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

    def foo(self, context):
        context.results.x = str(context.params.i * 5 + self.val)

class PipelineServer:
    def getCap(self, context):
        def _then(response):
            context.results.s = response.x + '_foo'
            context.results.outBox.outCap = Server(100)

        return context.params.inCap.foo(i=context.params.n).then(_then)

def test_client(capability):
    loop = capnp.EventLoop()

    client = capability.TestInterface.new_client(Server(), loop)
    
    req = client._request('foo')
    req.i = 5

    remote = req.send()
    response = loop.wait_remote(remote)

    assert response.x == '26'
    
    req = client.foo_request()
    req.i = 5

    remote = req.send()
    response = loop.wait_remote(remote)

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
    loop = capnp.EventLoop()

    client = capability.TestInterface.new_client(Server(), loop)
    
    remote = client._send('foo', i=5)
    response = loop.wait_remote(remote)

    assert response.x == '26'

    
    remote = client.foo(i=5)
    response = loop.wait_remote(remote)

    assert response.x == '26'

    with pytest.raises(ValueError):
        remote = client.foo(i='foo')

    with pytest.raises(ValueError):
        remote = client.foo2(i=5)

    with pytest.raises(ValueError):
        remote = client.foo(baz=5)

def test_pipeline(capability):
    loop = capnp.EventLoop()

    client = capability.TestPipeline.new_client(PipelineServer(), loop)
    foo_client = capability.TestInterface.new_client(Server(), loop)

    remote = client.getCap(n=5, inCap=foo_client)
    response = loop.wait_remote(remote)

    assert response.s == '26_foo'


