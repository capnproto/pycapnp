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


def test_simple_rpc():
    read, write = socket.socketpair(socket.AF_UNIX)

    restorer = SimpleRestorer()
    server = capnp.TwoPartyServer(write, restorer)
    client = capnp.TwoPartyClient(read)

    ref = test_capability_capnp.TestSturdyRefObjectId.new_message(tag='testInterface')
    cap = client.restore(ref)
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'


def test_simple_rpc_restore_func():
    read, write = socket.socketpair(socket.AF_UNIX)

    server = capnp.TwoPartyServer(write, restore_func)
    client = capnp.TwoPartyClient(read)

    ref = test_capability_capnp.TestSturdyRefObjectId.new_message(tag='testInterface')
    cap = client.restore(ref)
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'
