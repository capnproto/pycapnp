import pytest
import capnp
import os
import socket

import test_capability_capnp

class Server(test_capability_capnp.TestInterface.Server):
    def __init__(self, val=1):
        self.val = val

    def foo(self, i, j, **kwargs):
        return str(i * 5 + self.val)

def test_simple_rpc():
    def _restore(ref_id):
        return Server(100)

    read, write = socket.socketpair(socket.AF_UNIX)

    restorer = capnp.Restorer(test_capability_capnp.TestSturdyRefObjectId, _restore)
    server = capnp.RpcServer(write, restorer)
    client = capnp.RpcClient(read)

    ref = test_capability_capnp.TestSturdyRefObjectId.new_message()
    cap = client.restore(ref)
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'
