import capnp
import os
import socket
import gc
import subprocess
import time

import sys  # add examples dir to sys.path
examples_dir = os.path.join(os.path.dirname(__file__), '..', 'examples')
sys.path.append(examples_dir)
import calculator_client
import calculator_server


def test_calculator():
    read, write = socket.socketpair(socket.AF_UNIX)

    server = capnp.TwoPartyServer(write, bootstrap=calculator_server.CalculatorImpl())
    calculator_client.main(read)


def run_subprocesses(address):
    server = subprocess.Popen([examples_dir + '/calculator_server.py', address])
    time.sleep(2)  # Give the server some small amount of time to start listening
    client = subprocess.Popen([examples_dir + '/calculator_client.py', address])

    ret = client.wait()
    server.kill()
    assert ret == 0


def test_calculator_tcp():
    address = '127.0.0.1:36431'
    run_subprocesses(address)


def test_calculator_unix():
    path = '/tmp/pycapnp-test'
    try:
        os.unlink(path)
    except OSError:
        pass

    address = 'unix:' + path
    run_subprocesses(address)

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

    server = capnp.TwoPartyServer(write, bootstrap=calculator_server.CalculatorImpl())
    calculator_client.main(read)

    calculator_server.evaluate_impl = evaluate_impl_orig
