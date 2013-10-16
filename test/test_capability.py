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
    
    req = client.request('foo')
    req.i = 5

    remote = req.send()
    remote = client.send('foo', i=10)
    response = loop.wait_remote(remote)

    # assert response.x == '26'

    with pytest.raises(ValueError):
        client.request('foo2')
