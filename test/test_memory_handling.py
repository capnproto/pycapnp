from types import coroutine
import pytest
import socket
import gc

import capnp
import test_capability
import test_capability_capnp as capability


@pytest.fixture(autouse=True)
async def kj_loop():
    async with capnp.kj_loop():
        yield


@coroutine
def wrap(p):
    return (yield from p)


async def test_kj_loop_await_attach():
    read, write = socket.socketpair()
    read = await capnp.AsyncIoStream.create_connection(sock=read)
    write = await capnp.AsyncIoStream.create_connection(sock=write)
    _ = capnp.TwoPartyServer(write, bootstrap=test_capability.Server())
    client = capnp.TwoPartyClient(read).bootstrap().cast_as(capability.TestInterface)
    t = wrap(client.foo(5, True).__await__())
    del client
    del read
    gc.collect()
    await t
