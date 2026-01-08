"""
Regression test for use-after-free bug in async write with large payloads.

This test reproduces a bug where pipelining multiple RPC calls with large data
payloads (>~4000 bytes) causes memory corruption. The root cause was that
_PyAsyncIoStreamProtocol.write_loop() passed a memoryview pointing to C++
memory to transport.write(), then called fulfill() which freed the C++ memory.
Since transport.write() is non-blocking and buffers data asynchronously,
the data could be corrupted before being sent.

The fix is to copy the data to Python bytes before passing to transport.write().

See: https://github.com/capnproto/pycapnp/pull/392
"""

import pytest
import socket

import capnp
import test_capability_capnp


@pytest.fixture(autouse=True)
async def kj_loop():
    async with capnp.kj_loop():
        yield


class LargeResponseServer(test_capability_capnp.TestInterface.Server):
    """
    Server that returns large text responses to trigger the use-after-free bug.

    The bug manifests when response messages are >~4000 bytes.
    """

    async def foo(self, i, j, **kwargs):
        # Generate a large response string based on input
        # The size is controlled by the input parameter 'i'
        size = i
        # Create a deterministic pattern that can be verified
        pattern = "".join(chr(65 + (k % 26)) for k in range(size))
        return pattern


async def test_large_response_sequential():
    """
    Test that large RPC responses are received correctly when sent sequentially.

    Tests various payload sizes including those >4000 bytes which trigger the bug.
    """
    read_sock, write_sock = socket.socketpair()
    read_stream = await capnp.AsyncIoStream.create_connection(sock=read_sock)
    write_stream = await capnp.AsyncIoStream.create_connection(sock=write_sock)

    _ = capnp.TwoPartyServer(write_stream, bootstrap=LargeResponseServer())
    client = capnp.TwoPartyClient(read_stream)
    cap = client.bootstrap().cast_as(test_capability_capnp.TestInterface)

    # Test various sizes, including sizes that trigger the bug (>~4000 bytes)
    test_sizes = [100, 1000, 4000, 5000, 8000]

    for size in test_sizes:
        response = await cap.foo(i=size, j=False)

        # Verify the response has the correct length
        assert (
            len(response.x) == size
        ), f"Size mismatch for {size}: expected {size}, got {len(response.x)}"

        # Verify the pattern is correct (not corrupted)
        expected = "".join(chr(65 + (k % 26)) for k in range(size))
        assert response.x == expected, (
            f"Data corruption detected for {size} bytes payload! "
            f"First 50 chars: expected '{expected[:50]}', got '{response.x[:50]}'"
        )


async def test_large_response_pipelined():
    """
    Test that pipelining multiple RPC calls with large responses works correctly.

    This is a more aggressive test that sends multiple requests without awaiting,
    then collects all results. This pattern is more likely to trigger the
    use-after-free bug because multiple messages are queued in the write buffer.
    """
    read_sock, write_sock = socket.socketpair()
    read_stream = await capnp.AsyncIoStream.create_connection(sock=read_sock)
    write_stream = await capnp.AsyncIoStream.create_connection(sock=write_sock)

    _ = capnp.TwoPartyServer(write_stream, bootstrap=LargeResponseServer())
    client = capnp.TwoPartyClient(read_stream)
    cap = client.bootstrap().cast_as(test_capability_capnp.TestInterface)

    # Test sizes that trigger the bug - send 3 pipelined requests
    test_sizes = [5000, 6000, 8000]

    # Send all requests without awaiting (pipelining)
    promises = []
    for size in test_sizes:
        promise = cap.foo(i=size, j=False)
        promises.append((size, promise))

    # Now await all responses and verify
    for size, promise in promises:
        response = await promise

        assert len(response.x) == size, f"Size mismatch for {size}"

        expected = "".join(chr(65 + (k % 26)) for k in range(size))
        assert (
            response.x == expected
        ), f"Data corruption detected for {size} bytes payload!"
