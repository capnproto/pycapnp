import os
import platform
import tempfile

import pytest

import capnp

this_dir = os.path.dirname(__file__)


@pytest.fixture
def test_capnp():
    return capnp.load(os.path.join(this_dir, "test_large_read.capnp"))


def test_large_read(test_capnp):
    f = tempfile.TemporaryFile()

    array = test_capnp.MultiArray.new_message()

    row = array.init("rows", 1)[0]
    values = row.init("values", 10000)
    for i in range(len(values)):
        values[i] = i

    array.write_packed(f)
    f.seek(0)

    array = test_capnp.MultiArray.read_packed(f)
    del f
    assert array.rows[0].values[9000] == 9000


def test_large_read_multiple(test_capnp):
    f = tempfile.TemporaryFile()
    msg1 = test_capnp.Msg.new_message()
    msg1.data = [0x41] * 8192
    msg1.write(f)
    msg2 = test_capnp.Msg.new_message()
    msg2.write(f)
    f.seek(0)

    for m in test_capnp.Msg.read_multiple(f):
        pass


def get_two_adjacent_messages(test_capnp):
    msg1 = test_capnp.Msg.new_message()
    msg1.data = [0x41] * 8192
    m1 = msg1.to_bytes()
    msg2 = test_capnp.Msg.new_message()
    m2 = msg2.to_bytes()

    return m1 + m2


def test_large_read_multiple_bytes(test_capnp):
    data = get_two_adjacent_messages(test_capnp)
    for m in test_capnp.Msg.read_multiple_bytes(data):
        pass

    with pytest.raises(capnp.KjException):
        data = get_two_adjacent_messages(test_capnp)[:-1]
        for m in test_capnp.Msg.read_multiple_bytes(data):
            pass

    with pytest.raises(capnp.KjException):
        data = get_two_adjacent_messages(test_capnp) + b" "
        for m in test_capnp.Msg.read_multiple_bytes(data):
            pass


@pytest.mark.skipif(
    platform.python_implementation() == "PyPy",
    reason="PyPy memoryview support is limited",
)
def test_large_read_mutltiple_bytes_memoryview(test_capnp):
    data = get_two_adjacent_messages(test_capnp)
    for m in test_capnp.Msg.read_multiple_bytes(memoryview(data)):
        pass

    with pytest.raises(capnp.KjException):
        data = get_two_adjacent_messages(test_capnp)[:-1]
        for m in test_capnp.Msg.read_multiple_bytes(memoryview(data)):
            pass

    with pytest.raises(capnp.KjException):
        data = get_two_adjacent_messages(test_capnp) + b" "
        for m in test_capnp.Msg.read_multiple_bytes(memoryview(data)):
            pass
