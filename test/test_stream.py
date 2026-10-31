"""
Tests for methods declared `-> stream`, which are sent with
Request::sendStreaming() and so go through the connection's flow controller.
"""

import asyncio
import socket

import pytest

import capnp
import test_stream_capnp


@pytest.fixture(autouse=True)
async def kj_loop():
    async with capnp.kj_loop():
        yield


class Sink(test_stream_capnp.StreamSink.Server):
    def __init__(self):
        self.count = 0
        self.in_order = True
        self.release = asyncio.Event()
        self.release.set()

    async def write(self, seq, data, **kwargs):
        await self.release.wait()
        self.in_order = self.in_order and seq == self.count
        self.count += 1

    async def done(self, **kwargs):
        return self.count, self.in_order


async def connect(sink):
    """
    Connects a client to a server for `sink` over a socket pair. Returns the
    server and client objects, which must stay referenced for the connection to
    stay open, the client's socket, and the client's capability.
    """
    client_sock, server_sock = socket.socketpair()
    client_stream = await capnp.AsyncIoStream.create_connection(sock=client_sock)
    server_stream = await capnp.AsyncIoStream.create_connection(sock=server_sock)
    server = capnp.TwoPartyServer(server_stream, bootstrap=sink)
    client = capnp.TwoPartyClient(client_stream)
    cap = client.bootstrap().cast_as(test_stream_capnp.StreamSink)
    return (server, client), client_sock, cap


async def test_stream_writes_arrive_in_order():
    sink = Sink()
    _conn, _, cap = await connect(sink)
    writes = [cap.write(i, b"x" * 1000) for i in range(100)]
    for w in writes:
        await w
    result = await cap.done()
    assert result.count == 100
    assert result.inOrder


@pytest.mark.parametrize("use_request", [False, True])
async def test_stream_write_completes_before_server_returns(use_request):
    sink = Sink()
    sink.release.clear()
    _conn, _, cap = await connect(sink)
    # With flow control the write completes once the window has room, while
    # the server is still blocked in write().
    if use_request:
        req = cap.write_request()
        req.seq = 0
        req.data = b"x"
        write = req.send()
    else:
        write = cap.write(0, b"x")
    await asyncio.wait_for(write, timeout=5)
    assert sink.count == 0
    sink.release.set()
    result = await cap.done()
    assert result.count == 1


async def test_stream_window_limits_unacknowledged_data():
    sink = Sink()
    sink.release.clear()
    _conn, client_sock, cap = await connect(sink)
    chunk = 64 * 1024
    window = client_sock.getsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF)
    pending = []
    blocked = False
    for i in range(window // chunk + 4):
        w = asyncio.ensure_future(cap.write(i, b"x" * chunk))
        pending.append(w)
        done, _ = await asyncio.wait({w}, timeout=0.5)
        if not done:
            blocked = True
            break
    assert blocked, "a write completed although more than one window was unacknowledged"
    sink.release.set()
    for w in pending:
        await w
    result = await cap.done()
    assert result.count == len(pending)
    assert result.inOrder
