"""
rpc test
"""

import pytest
import capnp
import socket

import test_capability_capnp


@pytest.fixture(autouse=True)
async def kj_loop():
    async with capnp.kj_loop():
        yield


class Server(test_capability_capnp.TestInterface.Server):
    def __init__(self, val=100):
        self.val = val

    async def foo(self, i, j, **kwargs):
        return str(i * 5 + self.val)


async def test_simple_rpc_with_options():
    read, write = socket.socketpair()
    read = await capnp.AsyncIoStream.create_connection(sock=read)
    write = await capnp.AsyncIoStream.create_connection(sock=write)

    _ = capnp.TwoPartyServer(write, bootstrap=Server())
    # This traversal limit is too low to receive the response in, so we expect
    # an exception during the call.
    client = capnp.TwoPartyClient(read, traversal_limit_in_words=1)

    with pytest.raises(capnp.KjException):
        cap = client.bootstrap().cast_as(test_capability_capnp.TestInterface)

        remote = cap.foo(i=5)
        _ = remote.wait()


async def test_simple_rpc_bootstrap():
    read, write = socket.socketpair()
    read = await capnp.AsyncIoStream.create_connection(sock=read)
    write = await capnp.AsyncIoStream.create_connection(sock=write)

    _ = capnp.TwoPartyServer(write, bootstrap=Server(100))
    client = capnp.TwoPartyClient(read)

    cap = client.bootstrap()
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = await remote

    assert response.x == "125"
