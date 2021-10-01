#!/usr/bin/env python3

import argparse
import asyncio
import os
import socket
import ssl
import time

import capnp
import thread_capnp

this_dir = os.path.dirname(os.path.abspath(__file__))


def parse_args():
    parser = argparse.ArgumentParser(
        usage="Connects to the Example thread server \
at the given address and does some RPCs"
    )
    parser.add_argument("host", help="HOST:PORT")

    return parser.parse_args()


class StatusSubscriber(thread_capnp.Example.StatusSubscriber.Server):
    """An implementation of the StatusSubscriber interface"""

    def status(self, value, **kwargs):
        print("status: {}".format(time.time()))


async def myreader(client, reader):
    while True:
        data = await reader.read(4096)
        client.write(data)


async def mywriter(client, writer):
    while True:
        data = await client.read(4096)
        writer.write(data.tobytes())
        await writer.drain()


async def background(cap):
    subscriber = StatusSubscriber()
    promise = cap.subscribeStatus(subscriber)
    await promise.a_wait()


async def main(host):
    host = host.split(":")
    addr = host[0]
    port = host[1]

    # Setup SSL context
    ctx = ssl.create_default_context(
        ssl.Purpose.SERVER_AUTH, cafile=os.path.join(this_dir, "selfsigned.cert")
    )

    # Handle both IPv4 and IPv6 cases
    try:
        print("Try IPv4")
        reader, writer = await asyncio.open_connection(
            addr, port, ssl=ctx, family=socket.AF_INET
        )
    except Exception:
        print("Try IPv6")
        reader, writer = await asyncio.open_connection(
            addr, port, ssl=ctx, family=socket.AF_INET6
        )

    # Start TwoPartyClient using TwoWayPipe (takes no arguments in this mode)
    client = capnp.TwoPartyClient()
    cap = client.bootstrap().cast_as(thread_capnp.Example)

    # Assemble reader and writer tasks, run in the background
    coroutines = [myreader(client, reader), mywriter(client, writer)]
    asyncio.gather(*coroutines, return_exceptions=True)

    # Start background task for subscriber
    tasks = [background(cap)]
    asyncio.gather(*tasks, return_exceptions=True)

    # Run blocking tasks
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))


if __name__ == "__main__":
    # Using asyncio.run hits an asyncio ssl bug
    # https://bugs.python.org/issue36709
    # asyncio.run(main(parse_args().host), loop=loop, debug=True)
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main(parse_args().host))
