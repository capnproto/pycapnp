#!/usr/bin/env python3

import asyncio
import argparse
import time
import capnp
import socket

import thread_capnp

capnp.remove_event_loop()
capnp.create_event_loop(threaded=True)


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


async def background(cap):
    subscriber = StatusSubscriber()
    promise = cap.subscribeStatus(subscriber)
    await promise.a_wait()


async def main(host):
    host = host.split(":")
    addr = host[0]
    port = host[1]
    # Handle both IPv4 and IPv6 cases
    try:
        print("Try IPv4")
        reader, writer = await asyncio.open_connection(
            addr, port, family=socket.AF_INET
        )
    except Exception:
        print("Try IPv6")
        reader, writer = await asyncio.open_connection(
            addr, port, family=socket.AF_INET6
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
    asyncio.run(main(parse_args().host))
