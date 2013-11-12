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

def test_simple_rpc(capability):
    def _restore(ref_id):
        return capability.TestInterface.new_server(Server(100))

    loop = capnp.EventLoop()
    pipe = capnp.TwoWayPipe()
    
    restorer = capnp.Restorer(capability.TestSturdyRefObjectId, _restore)
    server = capnp.RpcServer(loop, restorer, pipe)
    client = capnp.RpcClient(loop, pipe)

    ref = capability.TestSturdyRefObjectId.new_message()
    cap = client.restore(ref.as_reader())
    cap = cap.cast_as(capability.TestInterface)

    remote = cap.foo(i=5)
    response = loop.wait_remote(remote)

    assert response.x == '125'
