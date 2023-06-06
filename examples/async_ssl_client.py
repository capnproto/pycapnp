#!/usr/bin/env python3

import argparse
import asyncio
import os
import ssl
import time
import socket

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


async def background(cap):
    subscriber = StatusSubscriber()
    await cap.subscribeStatus(subscriber)


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

    # Start background task for subscriber
    asyncio.create_task(background(cap))

    # Run blocking tasks
    print("main: {}".format(time.time()))
    await cap.longRunning()
    print("main: {}".format(time.time()))
    await cap.longRunning()
    print("main: {}".format(time.time()))
    await cap.longRunning()
    print("main: {}".format(time.time()))


if __name__ == "__main__":
    # Using asyncio.run hits an asyncio ssl bug
    # https://bugs.python.org/issue36709
    # asyncio.run(main(parse_args().host), loop=loop, debug=True)
    loop = asyncio.get_event_loop()
    loop.run_until_complete(main(parse_args().host))
