#!/usr/bin/env python3

import argparse
import threading
import time
import capnp

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


def start_status_thread(host):
    client = capnp.TwoPartyClient(host)
    cap = client.bootstrap().cast_as(thread_capnp.Example)

    subscriber = StatusSubscriber()
    promise = cap.subscribeStatus(subscriber)
    promise.wait()


def main(host):
    client = capnp.TwoPartyClient(host)
    cap = client.bootstrap().cast_as(thread_capnp.Example)

    status_thread = threading.Thread(target=start_status_thread, args=(host,))
    status_thread.daemon = True
    status_thread.start()

    print("main: {}".format(time.time()))
    cap.longRunning().wait()
    print("main: {}".format(time.time()))
    cap.longRunning().wait()
    print("main: {}".format(time.time()))
    cap.longRunning().wait()
    print("main: {}".format(time.time()))


if __name__ == "__main__":
    main(parse_args().host)
