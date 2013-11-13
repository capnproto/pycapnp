from __future__ import print_function

import capnp
import test_capnp
import socket

def example_client():
    loop = capnp.EventLoop()
    
    c = socket.create_connection(('localhost', 49999))
    read_stream = capnp.FdAsyncIoStream(c.fileno())

    client = capnp.RpcClient(loop, read_stream)

    ref = test_capnp.TestSturdyRefObjectId.new_message()
    ref.tag = 'testInterface'
    cap = client.restore(ref)
    cap = cap.cast_as(test_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = loop.wait_remote(remote)

    assert response.x == 'foo'

example_client()