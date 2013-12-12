import capnp
import os
import socket
import gc

import sys  # add examples dir to sys.path
sys.path.append(os.path.join(os.path.dirname(__file__), '..', 'examples'))
import calculator_client
import calculator_server


def test_calculator():
    read, write = socket.socketpair(socket.AF_UNIX)

    server = capnp.TwoPartyServer(write, calculator_server.restore)
    calculator_client.main(read)


def test_calculator_gc():
    def new_evaluate_impl(old_evaluate_impl):
        def call(*args, **kwargs):
            gc.collect()
            return old_evaluate_impl(*args, **kwargs)
        return call

    read, write = socket.socketpair(socket.AF_UNIX)

    # inject a gc.collect to the beginning of every evaluate_impl call
    evaluate_impl_orig = calculator_server.evaluate_impl
    calculator_server.evaluate_impl = new_evaluate_impl(evaluate_impl_orig)

    server = capnp.TwoPartyServer(write, calculator_server.restore)
    calculator_client.main(read)

    calculator_server.evaluate_impl = evaluate_impl_orig
