from __future__ import print_function

import capnp
import test_capnp
import socket

def example_client():
    c = socket.create_connection(('localhost', 49999))

    client = capnp.RpcClient(c)

    cap = client.restore(test_capnp.TestSturdyRefObjectId.new_message(tag='testInterface'))
    cap = cap.cast_as(test_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'
    c.close()

example_client()