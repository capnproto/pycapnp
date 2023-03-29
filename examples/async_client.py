#!/usr/bin/env python3

import asyncio
import argparse
import time
import capnp

import thread_capnp

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
    promise = cap.subscribeStatus(subscriber)
    await promise.a_wait()


async def main(host):
    client = capnp.TwoPartyClient(host)
    cap = client.bootstrap().cast_as(thread_capnp.Example)

    # Start background task for subscriber
    asyncio.create_task(background(cap))

    # Run blocking tasks
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))
    # Shut down the client, so that the background task gets terminated
    client.shutdown()

if __name__ == "__main__":
    asyncio.run(main(parse_args().host))
