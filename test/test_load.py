import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)

@pytest.fixture
def addressbook():
     return capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

def test_basic_load():
    capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

def test_constants(addressbook):
    assert addressbook.qux == 123

def test_classes(addressbook):
    assert addressbook.AddressBook
    assert addressbook.Person
