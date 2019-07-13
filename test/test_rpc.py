import warnings
from contextlib import contextmanager

import pytest
import capnp
import os
import socket

import test_capability_capnp


class Server(test_capability_capnp.TestInterface.Server):

    def __init__(self, val=1):
        self.val = val

    def foo(self, i, j, **kwargs):
        return str(i * 5 + self.val)


def restore_func(ref_id):
    return Server(100)


class SimpleRestorer(test_capability_capnp.TestSturdyRefObjectId.Restorer):

    def restore(self, ref_id):
        assert ref_id.tag == 'testInterface'
        return Server(100)


@contextmanager
def _warnings(expected_count=1, expected_text='Restorers are deprecated.'):
    with warnings.catch_warnings(record=True) as w:
        yield

        assert len(w) == expected_count
        assert all(issubclass(x.category, UserWarning) for x in w), w
        assert all(expected_text in str(x.message) for x in w), w


def test_simple_rpc():
    read, write = socket.socketpair(socket.AF_UNIX)

    restorer = SimpleRestorer()

    with _warnings(1):
        server = capnp.TwoPartyServer(write, restorer)
    client = capnp.TwoPartyClient(read)

    ref = test_capability_capnp.TestSturdyRefObjectId.new_message(tag='testInterface')
    with _warnings(1):
        cap = client.restore(ref)
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'


def test_simple_rpc_with_options():
    read, write = socket.socketpair(socket.AF_UNIX)

    restorer = SimpleRestorer()
    with _warnings(1):
        server = capnp.TwoPartyServer(write, restorer)
    # This traversal limit is too low to receive the response in, so we expect
    # an exception during the call.
    client = capnp.TwoPartyClient(read, traversal_limit_in_words=1)

    ref = test_capability_capnp.TestSturdyRefObjectId.new_message(tag='testInterface')
    with _warnings(1):
        cap = client.restore(ref)
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    with pytest.raises(capnp.KjException):
        response = remote.wait()


def test_simple_rpc_restore_func():
    read, write = socket.socketpair(socket.AF_UNIX)

    with _warnings(1):
        server = capnp.TwoPartyServer(write, restore_func)
    client = capnp.TwoPartyClient(read)

    ref = test_capability_capnp.TestSturdyRefObjectId.new_message(tag='testInterface')
    with _warnings(1):
        cap = client.restore(ref)
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'


def text_restore_func(objectId):
    text = objectId.as_text()
    assert text == 'testInterface'
    return Server(100)


def test_ez_rpc():
    read, write = socket.socketpair(socket.AF_UNIX)

    with _warnings(1):
        server = capnp.TwoPartyServer(write, text_restore_func)
    client = capnp.TwoPartyClient(read)

    with _warnings(1):
        cap = client.ez_restore('testInterface')
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'

    with _warnings(1):
        cap = client.restore(test_capability_capnp.TestSturdyRefObjectId.new_message())
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)

    with pytest.raises(capnp.KjException):
        response = remote.wait()

def test_simple_rpc_bootstrap():
    read, write = socket.socketpair(socket.AF_UNIX)

    server = capnp.TwoPartyServer(write, bootstrap=Server(100))
    client = capnp.TwoPartyClient(read)

    cap = client.bootstrap()
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'
