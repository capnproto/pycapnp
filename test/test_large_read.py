import pytest
import capnp
import os
import tempfile
import sys

this_dir = os.path.dirname(__file__)


@pytest.fixture
def test_capnp():
    return capnp.load(os.path.join(this_dir, 'test_large_read.capnp'))


def test_large_read(test_capnp):
    f = tempfile.TemporaryFile()

    array = test_capnp.MultiArray.new_message()

    row = array.init('rows', 1)[0]
    values = row.init('values', 10000)
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
