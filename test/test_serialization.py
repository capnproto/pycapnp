import pytest
import capnp
import os
import platform
import test_regression
import tempfile

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
    for msg in all_types.TestAllTypes.read_multiple(f):
        test_regression.check_all_types(msg)

def test_roundtrip_file_multiple_packed(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write_packed(f)
    msg.write_packed(f)
    msg.write_packed(f)

    f.seek(0)
    for msg in all_types.TestAllTypes.read_multiple_packed(f):
        test_regression.check_all_types(msg)

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
