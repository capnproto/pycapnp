import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)


@pytest.fixture
def addressbook():
    return capnp.load(os.path.join(this_dir, "addressbook.capnp"))


def test_object_basic(addressbook):
    obj = capnp._MallocMessageBuilder().get_root_as_any()
    person = obj.as_struct(addressbook.Person)
    person.name = "test"
    person.id = 1000

    same_person = obj.as_struct(addressbook.Person)
    assert same_person.name == "test"
    assert same_person.id == 1000

    obj_r = obj.as_reader()
    same_person = obj_r.as_struct(addressbook.Person)
    assert same_person.name == "test"
    assert same_person.id == 1000


def test_object_list(addressbook):
    obj = capnp._MallocMessageBuilder().get_root_as_any()
    listSchema = capnp._ListSchema(addressbook.Person)
    people = obj.init_as_list(listSchema, 2)
    person = people[0]
    person.name = "test"
    person.id = 1000
    person = people[1]
    person.name = "test2"
    person.id = 1001

    same_person = obj.as_list(listSchema)
    assert same_person[0].name == "test"
    assert same_person[0].id == 1000
    assert same_person[1].name == "test2"
    assert same_person[1].id == 1001

    obj_r = obj.as_reader()
    same_person = obj_r.as_list(listSchema)
    assert same_person[0].name == "test"
    assert same_person[0].id == 1000
    assert same_person[1].name == "test2"
    assert same_person[1].id == 1001
