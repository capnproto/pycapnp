#!/usr/bin/env python3

import argparse
import capnp

import thread_capnp


class ExampleImpl(thread_capnp.Example.Server):
    "Implementation of the Example threading Cap'n Proto interface."

    def subscribeStatus(self, subscriber, **kwargs):
        return (
            subscriber.status(True)
            .then(lambda _: self.subscribeStatus(subscriber))
        )

    def longRunning(self, **kwargs):
        return


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
    server.run_forever()


if __name__ == "__main__":
    main()
