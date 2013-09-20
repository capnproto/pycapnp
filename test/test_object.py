import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)

@pytest.fixture
def object():
     return capnp.load(os.path.join(this_dir, 'object.capnp'))

def test_object_basic(object):
    obj = object.TestObject.new_message()
    person = obj.object.as_struct(object.Person)
    person.name = 'test'
    person.id = 1000

    same_person = obj.object.as_struct(object.Person)
    assert same_person.name == 'test'
    assert same_person.id == 1000

    obj_r = obj.as_reader()
    same_person = obj_r.object.as_struct(object.Person)
    assert same_person.name == 'test'
    assert same_person.id == 1000
