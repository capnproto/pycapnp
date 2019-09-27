import gc
import os
import socket
import subprocess
import sys  # add examples dir to sys.path
import time

examples_dir = os.path.join(os.path.dirname(__file__), '..', 'examples')


def run_subprocesses(address, server, client):
    server = subprocess.Popen([os.path.join(examples_dir, server), address])
    time.sleep(1)  # Give the server some small amount of time to start listening
    client = subprocess.Popen([os.path.join(examples_dir, client), address])

    ret = client.wait()
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
    proc = subprocess.Popen([os.path.join(examples_dir, 'addressbook.py')])
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
