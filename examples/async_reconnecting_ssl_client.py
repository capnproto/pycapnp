#!/usr/bin/env python3

import asyncio
import argparse
import os
import time
import socket
import ssl

import capnp

import thread_capnp

this_dir = os.path.dirname(os.path.abspath(__file__))
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
        try:
            # Must be a wait_for in order to give watch_connection a slot
            # to try again
            data = await asyncio.wait_for(reader.read(4096), timeout=1.0)
        except asyncio.TimeoutError:
            continue
        client.write(data)


async def mywriter(client, writer):
    while True:
        try:
            # Must be a wait_for in order to give watch_connection a slot
            # to try again
            data = await asyncio.wait_for(client.read(4096), timeout=1.0)
            writer.write(data.tobytes())
        except asyncio.TimeoutError:
            continue


async def watch_connection(cap):
    while True:
        try:
            await asyncio.wait_for(cap.alive().a_wait(), timeout=5)
            await asyncio.sleep(1)
        except asyncio.TimeoutError:
            print("Watch timeout!")
            asyncio.get_running_loop().stop()
            return False


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
    except OSError:
        print("Try IPv6")
        try:
            reader, writer = await asyncio.open_connection(
                addr, port, ssl=ctx, family=socket.AF_INET6
            )
        except OSError:
            return False

    # Start TwoPartyClient using TwoWayPipe (takes no arguments in this mode)
    client = capnp.TwoPartyClient()
    cap = client.bootstrap().cast_as(thread_capnp.Example)

    # Start watcher to restart socket connection if it is lost
    overalltasks = []
    watcher = [watch_connection(cap)]
    overalltasks.append(asyncio.gather(*watcher, return_exceptions=True))

    # Assemble reader and writer tasks, run in the background
    coroutines = [myreader(client, reader), mywriter(client, writer)]
    overalltasks.append(asyncio.gather(*coroutines, return_exceptions=True))

    # Start background task for subscriber
    tasks = [background(cap)]
    overalltasks.append(asyncio.gather(*tasks, return_exceptions=True))

    # Run blocking tasks
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))
    await cap.longRunning().a_wait()
    print("main: {}".format(time.time()))

    for task in overalltasks:
        task.cancel()

    return True


if __name__ == "__main__":
    # Using asyncio.run hits an asyncio ssl bug
    # https://bugs.python.org/issue36709
    # asyncio.run(main(parse_args().host), loop=loop, debug=True)
    retry = True
    while retry:
        loop = asyncio.new_event_loop()
        try:
            retry = not loop.run_until_complete(main(parse_args().host))
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
