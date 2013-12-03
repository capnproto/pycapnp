import pytest
import capnp
import os
import socket

this_dir = os.path.dirname(__file__)

@pytest.fixture
def capability():
     return capnp.load(os.path.join(this_dir, 'test_capability.capnp'))

class Server:
    def __init__(self, val=1):
        self.val = val

    def foo(self, i, j, **kwargs):
        return str(i * 5 + self.val)

def test_simple_rpc(capability):
    def _restore(ref_id):
        return capability.TestInterface.new_server(Server(100))

    read, write = socket.socketpair(socket.AF_UNIX)

    restorer = capnp.Restorer(capability.TestSturdyRefObjectId, _restore)
    server = capnp.RpcServer(write, restorer)
    client = capnp.RpcClient(read)

    ref = capability.TestSturdyRefObjectId.new_message()
    cap = client.restore(ref)
    cap = cap.cast_as(capability.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'

def test_custom_event_loop(capability):
    capnp.remove_event_loop()
    capnp.DEFAULT_EVENT_LOOP = capnp._EventLoop()

    test_simple_rpc(capability)