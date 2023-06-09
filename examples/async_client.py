#!/usr/bin/env python3

import asyncio
import argparse
import time
import capnp

import thread_capnp


def parse_args():
    parser = argparse.ArgumentParser(
        usage="Connects to the Example thread server at the given address and does some RPCs"
    )
    parser.add_argument("host", help="HOST:PORT")

    return parser.parse_args()


class StatusSubscriber(thread_capnp.Example.StatusSubscriber.Server):
    """An implementation of the StatusSubscriber interface"""

    async def status(self, value, **kwargs):
        print("status: {}".format(time.time()))


async def background(cap):
    subscriber = StatusSubscriber()
    await cap.subscribeStatus(subscriber)


async def main(host):
    host, port = host.split(":")
    connection = await capnp.AsyncIoStream.create_connection(host=host, port=port)
    client = capnp.TwoPartyClient(connection)
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
    args = parse_args()
    asyncio.run(main(args.host))

    # Test that we can run multiple asyncio loops in sequence. This is particularly tricky, because
    # main contains a background task that we never cancel. The entire loop gets cleaned up anyways,
    # and we can start a new loop.
    asyncio.run(main(args.host))
