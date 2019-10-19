import gc
import os
import pytest
import socket
import subprocess
import sys  # add examples dir to sys.path
import time

import capnp

examples_dir = os.path.join(os.path.dirname(__file__), '..', 'examples')
sys.path.append(examples_dir)

import calculator_client # noqa: E402
import calculator_server # noqa: E402


def test_calculator():
    read, write = socket.socketpair()

    _ = capnp.TwoPartyServer(write, bootstrap=calculator_server.CalculatorImpl())
    calculator_client.main(read)


def run_subprocesses(address):
    cmd = [sys.executable, os.path.join(examples_dir, 'calculator_server.py'), address]
    server = subprocess.Popen(cmd)
    retries = 30
    if 'unix' in address:
        addr = address.split(':')[1]
        while True:
            sock = socket.socket(socket.AF_UNIX, socket.SOCK_STREAM)
            result = sock.connect_ex(addr)
            if result == 0:
                break
            # Give the server some small amount of time to start listening
            time.sleep(0.1)
            retries -= 1
            if retries == 0:
                assert False, "Timed out waiting for server to start"
    else:
        addr, port = address.split(':')
        while True:
            sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
            result = sock.connect_ex((addr, int(port)))
            if result == 0:
                break
            sock = socket.socket(socket.AF_INET6, socket.SOCK_STREAM)
            result = sock.connect_ex((addr, int(port)))
            if result == 0:
                break
            # Give the server some small amount of time to start listening
            time.sleep(0.1)
            retries -= 1
            if retries == 0:
                assert False, "Timed out waiting for server to start"
    cmd = [sys.executable, os.path.join(examples_dir, 'calculator_client.py'), address]
    client = subprocess.Popen(cmd)

    ret = client.wait()
    server.kill()
    assert ret == 0


def test_calculator_tcp():
    address = 'localhost:36431'
    run_subprocesses(address)


@pytest.mark.skipif(os.name == 'nt', reason="socket.AF_UNIX not supported on Windows")
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

    read, write = socket.socketpair()

    # inject a gc.collect to the beginning of every evaluate_impl call
    evaluate_impl_orig = calculator_server.evaluate_impl
    calculator_server.evaluate_impl = new_evaluate_impl(evaluate_impl_orig)

    _ = capnp.TwoPartyServer(write, bootstrap=calculator_server.CalculatorImpl())
    calculator_client.main(read)

    calculator_server.evaluate_impl = evaluate_impl_orig
