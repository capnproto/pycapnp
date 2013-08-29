import pytest
import capnp
from capnp import _capnp
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

def test_schemas(addressbook):
    assert type(addressbook.AddressBook.schema) is _capnp._StructSchema
    assert type(addressbook.Person.schema) is _capnp._StructSchema
