'''
thread test
'''

import platform
import socket
import threading

import pytest

import capnp
import test_capability_capnp

@pytest.mark.skipif(
    platform.python_implementation() == 'PyPy',
    reason="pycapnp's GIL handling isn't working properly at the moment for PyPy"
)
def test_making_event_loop():
    '''
    Event loop test
    '''
    capnp.remove_event_loop(True)
    capnp.create_event_loop()

    capnp.remove_event_loop()
    capnp.create_event_loop()

@pytest.mark.skipif(
    platform.python_implementation() == 'PyPy',
    reason="pycapnp's GIL handling isn't working properly at the moment for PyPy"
)
def test_making_threaded_event_loop():
    '''
    Threaded event loop test
    '''
    capnp.remove_event_loop(True)
    capnp.create_event_loop(True)

    capnp.remove_event_loop()
    capnp.create_event_loop(True)


class Server(test_capability_capnp.TestInterface.Server):
    '''
    Server
    '''
    def __init__(self, val=1):
        self.val = val

    def foo(self, i, j, **kwargs):
        '''
        foo
        '''
        return str(i * 5 + self.val)


class SimpleRestorer(test_capability_capnp.TestSturdyRefObjectId.Restorer):
    '''
    SimpleRestorer
    '''

    def restore(self, ref_id):
        '''
        Restore
        '''
        assert ref_id.tag == 'testInterface'
        return Server(100)


@pytest.mark.skipif(
    platform.python_implementation() == 'PyPy',
    reason="pycapnp's GIL handling isn't working properly at the moment for PyPy"
)
def test_using_threads():
    '''
    Thread test
    '''
    capnp.remove_event_loop(True)
    capnp.create_event_loop(True)

    read, write = socket.socketpair(socket.AF_UNIX)

    def run_server():
        restorer = SimpleRestorer()
        _ = capnp.TwoPartyServer(write, restorer)
        capnp.wait_forever()

    server_thread = threading.Thread(target=run_server)
    server_thread.daemon = True
    server_thread.start()

    client = capnp.TwoPartyClient(read)

    ref = test_capability_capnp.TestSturdyRefObjectId.new_message(tag='testInterface')
    cap = client.restore(ref)
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'
