#!/usr/bin/env python3

import argparse
import asyncio
import logging
import socket

import capnp
import thread_capnp


logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)


class ExampleImpl(thread_capnp.Example.Server):
    "Implementation of the Example threading Cap'n Proto interface."

    def subscribeStatus(self, subscriber, **kwargs):
        return (
            capnp.getTimer()
            .after_delay(10**9)
            .then(lambda: subscriber.status(True))
            .then(lambda _: self.subscribeStatus(subscriber))
        )

    def longRunning(self, **kwargs):
        return capnp.getTimer().after_delay(1 * 10**9)


class Server:
    async def myreader(self):
        while not self.reader.at_eof():
            data = await self.reader.read(4096)
            await self.server.write(data)
        logger.debug("myreader done.")
        return True

    async def mywriter(self):
        while not self.reader.at_eof():
            print(type(self.server))
            try:
                # Must be a wait_for so we don't block on read()
                data = await asyncio.wait_for(self.server.read(4096), timeout=0.1)
                self.writer.write(data.tobytes())
            except asyncio.TimeoutError:
                logger.debug("mywriter timeout.")
                continue
            except Exception as err:
                logger.error("Unknown mywriter err: %s", err)
                return False
        logger.debug("mywriter done.")
        return True

    async def myserver(self, reader, writer):
        # Start TwoPartyServer using TwoWayPipe (only requires bootstrap)
        self.server = capnp.TwoPartyServer(bootstrap=ExampleImpl())
        self.reader = reader
        self.writer = writer

        # Assemble reader and writer tasks, run in the background
        coroutines = [self.myreader(), self.mywriter()]
        tasks = asyncio.gather(*coroutines, return_exceptions=True)

        # Make wait for reader/writer to finish (prevent possible resource leaks)
        await tasks


def parse_args():
    parser = argparse.ArgumentParser(
        usage="""Runs the server bound to the\
given address/port ADDRESS. """
    )

    parser.add_argument("address", help="ADDRESS:PORT")

    return parser.parse_args()


async def new_connection(reader, writer):
    server = Server()
    await server.myserver(reader, writer)


async def main():
    address = parse_args().address
    host = address.split(":")
    addr = host[0]
    port = host[1]

    # Handle both IPv4 and IPv6 cases
    try:
        print("Try IPv4")
        server = await asyncio.start_server(
            new_connection, addr, port, family=socket.AF_INET
        )
    except Exception:
        print("Try IPv6")
        server = await asyncio.start_server(
            new_connection, addr, port, family=socket.AF_INET6
        )

    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
