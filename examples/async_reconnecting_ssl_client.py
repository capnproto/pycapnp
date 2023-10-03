#!/usr/bin/env python3

import asyncio
import argparse
import os
import time
import ssl
import socket

import capnp

import thread_capnp

this_dir = os.path.dirname(os.path.abspath(__file__))


def parse_args():
    parser = argparse.ArgumentParser(
        usage="Connects to the Example thread server at the given address and does some RPCs"
    )
    parser.add_argument("host", help="HOST:PORT")

    return parser.parse_args()


class StatusSubscriber(thread_capnp.Example.StatusSubscriber.Server):
    """An implementation of the StatusSubscriber interface"""

    def status(self, value, **kwargs):
        print("status: {}".format(time.time()))


async def watch_connection(cap):
    while True:
        try:
            await asyncio.wait_for(cap.alive(), timeout=5)
            await asyncio.sleep(1)
        except asyncio.TimeoutError:
            print("Watch timeout!")
            asyncio.get_running_loop().stop()
            return False


async def main(host):
    addr, port = host.split(":")

    # Setup SSL context
    ctx = ssl.create_default_context(
        ssl.Purpose.SERVER_AUTH, cafile=os.path.join(this_dir, "selfsigned.cert")
    )

    # Handle both IPv4 and IPv6 cases
    try:
        print("Try IPv4")
        stream = await capnp.AsyncIoStream.create_connection(
            addr, port, ssl=ctx, family=socket.AF_INET
        )
    except Exception:
        print("Try IPv6")
        stream = await capnp.AsyncIoStream.create_connection(
            addr, port, ssl=ctx, family=socket.AF_INET6
        )

    client = capnp.TwoPartyClient(stream)
    cap = client.bootstrap().cast_as(thread_capnp.Example)

    # Start watcher to restart socket connection if it is lost and subscriber background task
    background_tasks = asyncio.gather(
        cap.subscribeStatus(StatusSubscriber()),
        watch_connection(cap),
        return_exceptions=True,
    )

    # Run blocking tasks
    print("main: {}".format(time.time()))
    await cap.longRunning()
    print("main: {}".format(time.time()))
    await cap.longRunning()
    print("main: {}".format(time.time()))
    await cap.longRunning()
    print("main: {}".format(time.time()))

    background_tasks.cancel()

    return True


if __name__ == "__main__":
    # Using asyncio.run hits an asyncio ssl bug
    # https://bugs.python.org/issue36709
    # asyncio.run(main(parse_args().host), loop=loop, debug=True)
    retry = True
    while retry:
        loop = asyncio.new_event_loop()
        try:
            retry = not loop.run_until_complete(capnp.run(main(parse_args().host)))
        except RuntimeError:
            # If an IO is hung, the event loop will be stopped
            # and will throw RuntimeError exception
            continue
        if retry:
            time.sleep(1)
            print("Retrying...")

# How this works
# - There are two retry mechanisms
#   1. Connection retry
#   2. alive RPC verification
# - The connection retry just loops the connection (IPv4+IPv6 until there is a connection or Ctrl+C)
# - The alive RPC verification attempts a very basic rpc call with a timeout
#   * If there is a timeout, stop the current event loop
#   * Use the RuntimeError exception to force a reconnect
#   * myreader and mywriter must also be wrapped in wait_for in order for the events to get triggered correctly
