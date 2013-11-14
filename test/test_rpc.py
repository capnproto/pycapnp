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

    def foo(self, context):
        context.results.x = str(context.params.i * 5 + self.val)

def test_simple_rpc(capability):
    def _restore(ref_id):
        return capability.TestInterface.new_server(Server(100))

    loop = capnp.EventLoop()

    read, write = socket.socketpair(socket.AF_UNIX)
    read_stream = capnp.FdAsyncIoStream(read.fileno())
    write_stream = capnp.FdAsyncIoStream(write.fileno())

    restorer = capnp.Restorer(capability.TestSturdyRefObjectId, _restore)
    server = capnp.RpcServer(loop, write_stream, restorer)
    client = capnp.RpcClient(loop, read_stream)

    ref = capability.TestSturdyRefObjectId.new_message()
    cap = client.restore(ref)
    cap = cap.cast_as(capability.TestInterface)

    remote = cap.foo(i=5)
    response = loop.wait(remote)

    assert response.x == '125'
