import os
import socket
import subprocess
import sys
import time

examples_dir = os.path.join(os.path.dirname(__file__), '..', 'examples')


def run_subprocesses(address, server, client):
    cmd = [sys.executable, os.path.join(examples_dir, server), address]
    server = subprocess.Popen(cmd)
    retries = 30
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
    cmd = [sys.executable, os.path.join(examples_dir, client), address]
    client = subprocess.Popen(cmd)

    ret = client.wait(timeout=30)
    server.kill()
    assert ret == 0


def test_async_calculator_example():
    address = 'localhost:36432'
    server = 'async_calculator_server.py'
    client = 'async_calculator_client.py'
    run_subprocesses(address, server, client)


def test_thread_example():
    address = 'localhost:36433'
    server = 'thread_server.py'
    client = 'thread_client.py'
    run_subprocesses(address, server, client)


def test_addressbook_example():
    proc = subprocess.Popen([sys.executable, os.path.join(examples_dir, 'addressbook.py')])
    ret = proc.wait()
    assert ret == 0


def test_async_example():
    address = 'localhost:36434'
    server = 'async_server.py'
    client = 'async_client.py'
    run_subprocesses(address, server, client)


def test_ssl_async_example():
    address = 'localhost:36435'
    server = 'async_ssl_server.py'
    client = 'async_ssl_client.py'
    run_subprocesses(address, server, client)


def test_ssl_reconnecting_async_example():
    address = 'localhost:36436'
    server = 'async_ssl_server.py'
    client = 'async_reconnecting_ssl_client.py'
    run_subprocesses(address, server, client)
