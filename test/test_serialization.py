import pytest
import capnp
import os
import platform
import test_regression
import tempfile
import pickle

this_dir = os.path.dirname(__file__)

@pytest.fixture
def all_types():
    return capnp.load(os.path.join(this_dir, 'all_types.capnp'))

def test_roundtrip_file(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write(f)

    f.seek(0)
    msg = all_types.TestAllTypes.read(f)
    test_regression.check_all_types(msg)

def test_roundtrip_file_packed(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write_packed(f)

    f.seek(0)
    msg = all_types.TestAllTypes.read_packed(f)
    test_regression.check_all_types(msg)

def test_roundtrip_bytes(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    message_bytes = msg.to_bytes()

    msg = all_types.TestAllTypes.from_bytes(message_bytes)
    test_regression.check_all_types(msg)

def test_roundtrip_bytes_packed(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    message_bytes = msg.to_bytes_packed()

    msg = all_types.TestAllTypes.from_bytes_packed(message_bytes)
    test_regression.check_all_types(msg)

def test_roundtrip_file_multiple(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write(f)
    msg.write(f)
    msg.write(f)

    f.seek(0)
    i = 0
    for msg in all_types.TestAllTypes.read_multiple(f):
        test_regression.check_all_types(msg)
        i += 1
    assert i == 3

def test_roundtrip_bytes_multiple(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)

    msgs = msg.to_bytes()
    msgs += msg.to_bytes()
    msgs += msg.to_bytes()

    i = 0
    for msg in all_types.TestAllTypes.read_multiple_bytes(msgs):
        test_regression.check_all_types(msg)
        i += 1
    assert i == 3

def test_roundtrip_file_multiple_packed(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write_packed(f)
    msg.write_packed(f)
    msg.write_packed(f)

    f.seek(0)
    i = 0
    for msg in all_types.TestAllTypes.read_multiple_packed(f):
        test_regression.check_all_types(msg)
        i += 1
    assert i == 3

def test_roundtrip_bytes_multiple_packed(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)

    msgs = msg.to_bytes_packed()
    msgs += msg.to_bytes_packed()
    msgs += msg.to_bytes_packed()

    i = 0
    for msg in all_types.TestAllTypes.read_multiple_bytes_packed(msgs):
        test_regression.check_all_types(msg)
        i += 1
    assert i == 3

@pytest.mark.skipif(platform.python_implementation() == 'PyPy', reason="This works on my local PyPy v2.5.0, but is for some reason broken on TravisCI. Skip for now.")
def test_roundtrip_dict(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    d = msg.to_dict()

    msg = all_types.TestAllTypes.from_dict(d)
    test_regression.check_all_types(msg)

def test_file_and_bytes(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write(f)

    f.seek(0)

    assert f.read() == msg.to_bytes()

def test_file_and_bytes_packed(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write_packed(f)

    f.seek(0)

    assert f.read() == msg.to_bytes_packed()

def test_pickle(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    data = pickle.dumps(msg)
    msg2 = pickle.loads(data)

    test_regression.check_all_types(msg2)
