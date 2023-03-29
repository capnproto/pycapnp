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
        return capnp.getTimer().after_delay(11 * 10**8)


def parse_args():
    parser = argparse.ArgumentParser(
        usage="""Runs the server bound to the\
given address/port ADDRESS. """
    )

    parser.add_argument("address", help="ADDRESS:PORT")

    return parser.parse_args()

async def main():
    address = parse_args().address
    server = capnp.TwoPartyServer(address, bootstrap=ExampleImpl())
    await asyncio._get_running_loop().create_future()

if __name__ == "__main__":
    asyncio.run(main())
