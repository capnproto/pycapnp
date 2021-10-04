import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)


@pytest.fixture
def addressbook():
    return capnp.load(os.path.join(this_dir, "addressbook.capnp"))


@pytest.fixture
def annotations():
    return capnp.load(os.path.join(this_dir, "annotations.capnp"))


def test_basic_schema(addressbook):
    assert addressbook.Person.schema.fieldnames[0] == "id"


def test_list_schema(addressbook):
    peopleField = addressbook.AddressBook.schema.fields["people"]
    personType = peopleField.schema.elementType

    assert personType.node.id == addressbook.Person.schema.node.id

    personListSchema = capnp._ListSchema(addressbook.Person)

    assert personListSchema.elementType.node.id == addressbook.Person.schema.node.id


def test_annotations(annotations):
    assert annotations.schema.node.annotations[0].value.text == "TestFile"

    annotation = annotations.TestAnnotationOne.schema.node.annotations[0]
    assert annotation.value.text == "Test"

    annotation = annotations.TestAnnotationTwo.schema.node.annotations[0]
    assert annotation.value.struct.as_struct(annotations.AnnotationStruct).test == 100

    annotation = annotations.TestAnnotationThree.schema.node.annotations[0]
    annotation_list = annotation.value.list.as_list(
        capnp._ListSchema(annotations.AnnotationStruct)
    )
    assert annotation_list[0].test == 100
    assert annotation_list[1].test == 101

    annotation = annotations.TestAnnotationFour.schema.node.annotations[0]
    annotation_list = annotation.value.list.as_list(
        capnp._ListSchema(capnp.types.UInt16)
    )
    assert annotation_list[0] == 200
    assert annotation_list[1] == 201
