#!/usr/bin/env python3

import argparse
import capnp
import time

import thread_capnp


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


def parse_args():
    parser = argparse.ArgumentParser(
        usage="""Runs the server bound to the\
given address/port ADDRESS may be '*' to bind to all local addresses.\
:PORT may be omitted to choose a port automatically. """
    )

    parser.add_argument("address", help="ADDRESS[:PORT]")

    return parser.parse_args()


def main():
    address = parse_args().address

    server = capnp.TwoPartyServer(address, bootstrap=ExampleImpl())
    while True:
        server.poll_once()
        time.sleep(0.001)


if __name__ == "__main__":
    main()
