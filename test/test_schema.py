import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)


@pytest.fixture
def addressbook():
    return capnp.load(os.path.join(this_dir, 'addressbook.capnp'))


def test_basic_schema(addressbook):
    assert addressbook.Person.schema.fieldnames[0] == 'id'

def test_list_schema(addressbook):
    peopleField = addressbook.AddressBook.schema.fields['people']
    personType = peopleField.schema.elementType

    assert personType.node.id == addressbook.Person.schema.node.id

    personListSchema = capnp.ListSchema(addressbook.Person)

    assert personListSchema.elementType.node.id == addressbook.Person.schema.node.id
