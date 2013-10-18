import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)

@pytest.fixture
def capability():
     return capnp.load(os.path.join(this_dir, 'test_capability.capnp'))

class Server:
    def foo(self, context):
        context.results.x = str(context.params.i * 5 + 1)

def test_basic_client(capability):
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
