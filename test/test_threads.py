"""
thread test
"""

import platform
import socket
import threading

import pytest

import capnp

import test_capability_capnp


class Server(test_capability_capnp.TestInterface.Server):
    """
    Server
    """

    def __init__(self, val=100):
        self.val = val

    def foo(self, i, j, **kwargs):
        """
        foo
        """
        return str(i * 5 + self.val)


@pytest.mark.skipif(
    platform.python_implementation() == "PyPy",
    reason="pycapnp's GIL handling isn't working properly at the moment for PyPy",
)
def test_using_threads():
    """
    Thread test
    """
    read, write = socket.socketpair()

    def run_server():
        _ = capnp.TwoPartyServer(write, bootstrap=Server())
        capnp.wait_forever()

    server_thread = threading.Thread(target=run_server)
    server_thread.daemon = True
    server_thread.start()

    client = capnp.TwoPartyClient(read)
    cap = client.bootstrap().cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == "125"
