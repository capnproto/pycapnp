"""
thread test
"""

import platform
import socket
import threading

import pytest

import capnp

from capnp.lib.capnp import KjException

import test_capability_capnp


@pytest.mark.skipif(
    platform.python_implementation() == "PyPy",
    reason="pycapnp's GIL handling isn't working properly at the moment for PyPy",
)
def test_making_event_loop():
    """
    Event loop test
    """
    capnp.remove_event_loop(True)
    capnp.create_event_loop()

    capnp.remove_event_loop()
    capnp.create_event_loop()


@pytest.mark.skipif(
    platform.python_implementation() == "PyPy",
    reason="pycapnp's GIL handling isn't working properly at the moment for PyPy",
)
def test_making_threaded_event_loop():
    """
    Threaded event loop test
    """
    # The following raises a KjException, and if not caught causes an SIGABRT:
    # kj/async.c++:973: failed: expected head == nullptr; EventLoop destroyed with events still in the queue.
    # Memory leak?; head->trace() = kj::_::ForkHub<kj::_::Void>
    # kj::_::AdapterPromiseNode<kj::_::Void, kj::_::PromiseAndFulfillerAdapter<void> >
    # stack: ...
    # python(..) malloc: *** error for object 0x...: pointer being freed was not allocated
    # python(..) malloc: *** set a breakpoint in malloc_error_break to debug
    # Fatal Python error: Aborted
    capnp.remove_event_loop(KjException)
    capnp.create_event_loop(KjException)

    capnp.remove_event_loop()
    capnp.create_event_loop(KjException)


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
    capnp.remove_event_loop(True)
    capnp.create_event_loop(True)

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
