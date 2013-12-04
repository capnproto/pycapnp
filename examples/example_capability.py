from __future__ import print_function

import capnp
import example_capability_capnp as capability
import socket

class Server:
    def __init__(self, val=1):
        self.val = val

    def foo(self, i, **kwargs):
        return str(i * 5 + self.val)

def example_simple_rpc():
    def _restore(ref_id):
        return capability.TestInterface.new_server(Server(100))

    # loop = capnp.EventLoop()
    
    read, write = socket.socketpair(socket.AF_UNIX)

    restorer = capnp.Restorer(capability.TestSturdyRefObjectId, _restore)
    server = capnp.RpcServer(write, restorer)
    client = capnp.RpcClient(read)

    ref = capability.TestSturdyRefObjectId.new_message()
    cap = client.restore(ref.as_reader())
    cap = cap.cast_as(capability.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'

# example_simple_rpc()
capnp.load('test.capnp')
for i in range(100):
    capnp.load('test.capnp')

capnp.load('test.capnp')