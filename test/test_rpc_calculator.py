import gc
import os
import socket
import sys  # add examples dir to sys.path

import capnp

examples_dir = os.path.join(os.path.dirname(__file__), "..", "examples")
sys.path.append(examples_dir)

import async_calculator_client  # noqa: E402
import async_calculator_server  # noqa: E402


async def test_calculator():
    read, write = socket.socketpair()
    read = await capnp.AsyncIoStream.create_connection(sock=read)
    write = await capnp.AsyncIoStream.create_connection(sock=write)

    _ = capnp.TwoPartyServer(write, bootstrap=async_calculator_server.CalculatorImpl())
    await async_calculator_client.main(read)


async def test_calculator_gc():
    def new_evaluate_impl(old_evaluate_impl):
        def call(*args, **kwargs):
            gc.collect()
            return old_evaluate_impl(*args, **kwargs)

        return call

    read, write = socket.socketpair()
    read = await capnp.AsyncIoStream.create_connection(sock=read)
    write = await capnp.AsyncIoStream.create_connection(sock=write)

    # inject a gc.collect to the beginning of every evaluate_impl call
    evaluate_impl_orig = async_calculator_server.evaluate_impl
    async_calculator_server.evaluate_impl = new_evaluate_impl(evaluate_impl_orig)

    _ = capnp.TwoPartyServer(write, bootstrap=async_calculator_server.CalculatorImpl())
    await async_calculator_client.main(read)

    async_calculator_server.evaluate_impl = evaluate_impl_orig
