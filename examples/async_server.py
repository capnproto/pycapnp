#!/usr/bin/env python

from __future__ import print_function

import argparse
import capnp

import thread_capnp
import asyncio
import socket


class ExampleImpl(thread_capnp.Example.Server):

    "Implementation of the Example threading Cap'n Proto interface."

    def subscribeStatus(self, subscriber, **kwargs):
        return capnp.getTimer().after_delay(10**9) \
            .then(lambda: subscriber.status(True)) \
            .then(lambda _: self.subscribeStatus(subscriber))

    def longRunning(self, **kwargs):
        return capnp.getTimer().after_delay(3 * 10**9)


async def myreader(server, reader):
    while True:
        data = await reader.read(4096)
        # Close connection if 0 bytes read
        if len(data) == 0:
            server.close()
        await server.write(data)


async def mywriter(server, writer):
    while True:
        data = await server.read(4096)
        writer.write(data.tobytes())
        await writer.drain()


async def myserver(reader, writer):
    # Start TwoPartyServer using TwoWayPipe (only requires bootstrap)
    server = capnp.TwoPartyServer(bootstrap=ExampleImpl())

    # Assemble reader and writer tasks, run in the background
    coroutines = [myreader(server, reader), mywriter(server, writer)]
    asyncio.gather(*coroutines, return_exceptions=True)

    await server.poll_forever()


def parse_args():
    parser = argparse.ArgumentParser(usage='''Runs the server bound to the\
given address/port ADDRESS. ''')

    parser.add_argument("address", help="ADDRESS:PORT")

    return parser.parse_args()


async def main():
    address = parse_args().address
    host = address.split(':')
    addr = host[0]
    port = host[1]

    # Handle both IPv4 and IPv6 cases
    try:
        print("Try IPv4")
        server = await asyncio.start_server(
            myserver,
            addr, port,
        )
    except:
        print("Try IPv6")
        server = await asyncio.start_server(
            myserver,
            addr, port,
            family=socket.AF_INET6
        )

    async with server:
        await server.serve_forever()

if __name__ == '__main__':
    asyncio.run(main())
