import pytest
import capnp
import os
import platform
import test_regression

this_dir = os.path.dirname(__file__)

@pytest.fixture
def all_types():
    return capnp.load(os.path.join(this_dir, 'all_types.capnp'))

def test_roundtrip_file(all_types):
    f = open('example', 'w')
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write(f)

    f = open('example', 'r')
    msg = all_types.TestAllTypes.read(f)
    test_regression.check_all_types(msg)

def test_roundtrip_file_packed(all_types):
    f = open('example', 'w')
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write_packed(f)

    f = open('example', 'r')
    msg = all_types.TestAllTypes.read_packed(f)
    test_regression.check_all_types(msg)

def test_roundtrip_bytes(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    message_bytes = msg.to_bytes()

    msg = all_types.TestAllTypes.from_bytes(message_bytes)
    test_regression.check_all_types(msg)

def test_roundtrip_dict(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    d = msg.to_dict()

    msg = all_types.TestAllTypes.from_dict(d)
    test_regression.check_all_types(msg)
