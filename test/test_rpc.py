"""
rpc test
"""

import pytest
import capnp
import socket

import test_capability_capnp


class Server(test_capability_capnp.TestInterface.Server):
    def __init__(self, val=100):
        self.val = val

    def foo(self, i, j, **kwargs):
        return str(i * 5 + self.val)


def test_simple_rpc_with_options():
    read, write = socket.socketpair()

    _ = capnp.TwoPartyServer(write, bootstrap=Server())
    # This traversal limit is too low to receive the response in, so we expect
    # an exception during the call.
    client = capnp.TwoPartyClient(read, traversal_limit_in_words=1)

    with pytest.raises(capnp.KjException):
        cap = client.bootstrap().cast_as(test_capability_capnp.TestInterface)

        remote = cap.foo(i=5)
        _ = remote.wait()


def test_simple_rpc_bootstrap():
    read, write = socket.socketpair()

    _ = capnp.TwoPartyServer(write, bootstrap=Server(100))
    client = capnp.TwoPartyClient(read)

    cap = client.bootstrap()
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == "125"
