import capnp
import pytest
import test_capability_capnp
import socket
import threading
import platform

@pytest.mark.skipif(platform.python_implementation() == 'PyPy', reason="pycapnp's GIL handling isn't working properly at the moment for PyPy")
def test_making_event_loop():
    capnp.remove_event_loop(True)
    capnp.create_event_loop()

    capnp.remove_event_loop()
    capnp.create_event_loop()

@pytest.mark.skipif(platform.python_implementation() == 'PyPy', reason="pycapnp's GIL handling isn't working properly at the moment for PyPy")
def test_making_threaded_event_loop():
    capnp.remove_event_loop(True)
    capnp.create_event_loop(True)

    capnp.remove_event_loop()
    capnp.create_event_loop(True)


class Server(test_capability_capnp.TestInterface.Server):

    def __init__(self, val=1):
        self.val = val

    def foo(self, i, j, **kwargs):
        return str(i * 5 + self.val)


class SimpleRestorer(test_capability_capnp.TestSturdyRefObjectId.Restorer):

    def restore(self, ref_id):
        assert ref_id.tag == 'testInterface'
        return Server(100)


@pytest.mark.skipif(platform.python_implementation() == 'PyPy', reason="pycapnp's GIL handling isn't working properly at the moment for PyPy")
def test_using_threads():
    capnp.remove_event_loop(True)
    capnp.create_event_loop(True)

    read, write = socket.socketpair(socket.AF_UNIX)

    def run_server():
        restorer = SimpleRestorer()
        server = capnp.TwoPartyServer(write, restorer)
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
