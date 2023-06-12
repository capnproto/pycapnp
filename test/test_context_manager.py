import pytest
import asyncio
import socket

import capnp
import test_capability
import test_capability_capnp as capability


async def test_two_kj_one_asyncio():
    async with capnp.kj_loop():
        pass
    async with capnp.kj_loop():
        pass


def test_two_kj_two_asyncio():
    async def do():
        async with capnp.kj_loop():
            pass

    asyncio.run(do())
    asyncio.run(do())


async def test_nested_kj():
    with pytest.raises(RuntimeError) as exninfo:
        async with capnp.kj_loop():
            async with capnp.kj_loop():
                pass
    assert "The KJ event-loop is already running" in str(exninfo)


async def test_kj_loop_leak_new_client():
    async with capnp.kj_loop():
        client = capability.TestInterface._new_client(test_capability.Server())
    with pytest.raises(RuntimeError) as exninfo:
        await client.foo(5, True)
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_kj_loop_leak_client():
    read, write = socket.socketpair()
    async with capnp.kj_loop():
        read = await capnp.AsyncIoStream.create_connection(sock=read)
        write = await capnp.AsyncIoStream.create_connection(sock=write)
        _ = capnp.TwoPartyServer(write, bootstrap=test_capability.Server())
        client = capnp.TwoPartyClient(read)
        cap = client.bootstrap().cast_as(capability.TestInterface)
    with pytest.raises(RuntimeError) as exninfo:
        await cap.foo(5, True)
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_kj_loop_leak_client2():
    read, write = socket.socketpair()
    async with capnp.kj_loop():
        read = await capnp.AsyncIoStream.create_connection(sock=read)
        write = await capnp.AsyncIoStream.create_connection(sock=write)
        _ = capnp.TwoPartyServer(write, bootstrap=test_capability.Server())
        client = capnp.TwoPartyClient(read)
    with pytest.raises(RuntimeError) as exninfo:
        client.bootstrap().cast_as(capability.TestInterface)
    assert "This client is closed" in str(exninfo)


async def test_kj_loop_leak_client3():
    read, write = socket.socketpair()
    async with capnp.kj_loop():
        read = await capnp.AsyncIoStream.create_connection(sock=read)
        write = await capnp.AsyncIoStream.create_connection(sock=write)
        _ = capnp.TwoPartyServer(write, bootstrap=test_capability.Server())
        client = capnp.TwoPartyClient(read).bootstrap()
    with pytest.raises(RuntimeError) as exninfo:
        cap = client.cast_as(capability.TestInterface)
        await cap.foo(5, True)
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_no_kj_loop():
    read, write = socket.socketpair()
    with pytest.raises(RuntimeError) as exninfo:
        await capnp.AsyncIoStream.create_connection(sock=read)
    assert "The KJ event-loop is not running" in str(exninfo)
    with pytest.raises(RuntimeError) as exninfo:
        await capnp.AsyncIoStream.create_connection(sock=write)
    assert "The KJ event-loop is not running" in str(exninfo)
    with pytest.raises(RuntimeError) as exninfo:
        capability.TestPipeline._new_client(test_capability.PipelineServer())
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_promise_leaking1():
    async with capnp.kj_loop():
        client = capability.TestInterface._new_client(test_capability.Server())
        remote = client.foo(5, True)
        task = asyncio.ensure_future(remote)
        await asyncio.sleep(0)
    with pytest.raises(capnp.KjException):
        await task


async def test_promise_leaking2():
    async with capnp.kj_loop():
        client = capability.TestInterface._new_client(test_capability.Server())
        remote = client.foo(5, True)
        task = asyncio.ensure_future(remote)
    with pytest.raises(RuntimeError) as exninfo:
        await task
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_promise_leaking3():
    async with capnp.kj_loop():
        client = capability.TestInterface._new_client(test_capability.Server())
        remote = client.foo(5, True)
    with pytest.raises(RuntimeError) as exninfo:
        await remote
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_promise_leaking4():
    read, _ = socket.socketpair()
    async with capnp.kj_loop():
        connection = await capnp.AsyncIoStream.create_connection(sock=read)
        client = capnp.TwoPartyClient(connection)
        cap = client.bootstrap().cast_as(capability.TestInterface)
        res = asyncio.ensure_future(cap.foo(5, True))
        await asyncio.sleep(0)
    with pytest.raises(capnp.KjException):
        await res


async def test_promise_leaking5():
    read, _ = socket.socketpair()
    async with capnp.kj_loop():
        connection = await capnp.AsyncIoStream.create_connection(sock=read)
        client = capnp.TwoPartyClient(connection)
        cap = client.bootstrap().cast_as(capability.TestInterface)
        res = asyncio.ensure_future(cap.foo(5, True))
    with pytest.raises(RuntimeError) as exninfo:
        await res
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_promise_leaking6():
    read, _ = socket.socketpair()
    async with capnp.kj_loop():
        connection = await capnp.AsyncIoStream.create_connection(sock=read)
        client = capnp.TwoPartyClient(connection)
        cap = client.bootstrap().cast_as(capability.TestInterface)
        res = cap.foo(5, True)
    with pytest.raises(RuntimeError) as exninfo:
        await res
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_kj_loop_read_message_after_close():
    read, _ = socket.socketpair()
    async with capnp.kj_loop():
        read = await capnp.AsyncIoStream.create_connection(sock=read)
    with pytest.raises(RuntimeError) as exninfo:
        await capability.TestSturdyRefHostId.read_async(read)
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_kj_loop_partial_read_message_after_close():
    read, _ = socket.socketpair()
    async with capnp.kj_loop():
        read = await capnp.AsyncIoStream.create_connection(sock=read)
        message = capability.TestSturdyRefHostId.read_async(read)
    with pytest.raises(RuntimeError) as exninfo:
        await message
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_kj_loop_write_message_after_close():
    _, write = socket.socketpair()
    async with capnp.kj_loop():
        write = await capnp.AsyncIoStream.create_connection(sock=write)
    message = capability.TestSturdyRefHostId.new_message()
    with pytest.raises(RuntimeError) as exninfo:
        await message.write_async(write)
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_kj_loop_partial_write_message_after_close():
    _, write = socket.socketpair()
    async with capnp.kj_loop():
        write = await capnp.AsyncIoStream.create_connection(sock=write)
        message = capability.TestSturdyRefHostId.new_message()
        send = message.write_async(write)
    with pytest.raises(RuntimeError) as exninfo:
        await send
    assert "The KJ event-loop is not running" in str(exninfo)


async def test_client_on_disconnect_memory():
    read, _ = socket.socketpair()
    async with capnp.kj_loop():
        read = await capnp.AsyncIoStream.create_connection(sock=read)
        client = capnp.TwoPartyClient(read)
    with pytest.raises(RuntimeError) as exninfo:
        await client.on_disconnect()
    assert "This client is closed" in str(exninfo)


async def test_server_on_disconnect_memory():
    _, write = socket.socketpair()
    async with capnp.kj_loop():
        write = await capnp.AsyncIoStream.create_connection(sock=write)
        server = capnp.TwoPartyServer(write, bootstrap=test_capability.Server())
    with pytest.raises(RuntimeError) as exninfo:
        await server.on_disconnect()
    assert "This server is closed" in str(exninfo)


@pytest.mark.xfail(
    strict=True,
    reason="Fails because the promisefulfiller got destroyed. Possibly a bug in the C++ library.",
)
async def test_client_on_disconnect_memory2():
    """
    E       capnp.lib.capnp.KjException: kj/async.c++:2813: failed:
            PromiseFulfiller was destroyed without fulfilling the promise.
    """
    read, _ = socket.socketpair()
    async with capnp.kj_loop():
        read = await capnp.AsyncIoStream.create_connection(sock=read)
        client = capnp.TwoPartyClient(read)
        disc = client.on_disconnect()
    await disc


async def test_server_on_disconnect_memory2():
    _, write = socket.socketpair()
    async with capnp.kj_loop():
        write = await capnp.AsyncIoStream.create_connection(sock=write)
        server = capnp.TwoPartyServer(write, bootstrap=test_capability.Server())
        disc = server.on_disconnect()
    await disc
