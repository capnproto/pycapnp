import pytest
import capnp
import os
import tempfile
import sys

from capnp.lib.capnp import KjException

this_dir = os.path.dirname(__file__)


@pytest.fixture
def addressbook():
    return capnp.load(os.path.join(this_dir, "addressbook.capnp"))


@pytest.fixture
def all_types():
    return capnp.load(os.path.join(this_dir, "all_types.capnp"))


def test_which_builder(addressbook):
    addresses = addressbook.AddressBook.new_message()
    people = addresses.init("people", 2)

    alice = people[0]
    alice.employment.school = "MIT"

    assert alice.employment.which == addressbook.Person.Employment.school
    assert alice.employment.which == "school"

    bob = people[1]

    assert bob.employment.which == addressbook.Person.Employment.unemployed
    assert bob.employment.which == "unemployed"

    bob.employment.unemployed = None

    assert bob.employment.which == addressbook.Person.Employment.unemployed
    assert bob.employment.which == "unemployed"

    with pytest.raises(KjException):
        addresses._which()

    with pytest.raises(KjException):
        addresses._which_str()

    with pytest.raises(KjException):
        addresses.which


def test_which_reader(addressbook):
    def writeAddressBook(fd):
        message = capnp._MallocMessageBuilder()
        addressBook = message.init_root(addressbook.AddressBook)
        people = addressBook.init("people", 2)

        alice = people[0]
        alice.employment.school = "MIT"

        bob = people[1]
        bob.employment.unemployed = None

        capnp._write_packed_message_to_fd(fd, message)

    f = tempfile.TemporaryFile()
    writeAddressBook(f.fileno())
    f.seek(0)

    addresses = addressbook.AddressBook.read_packed(f)

    people = addresses.people

    alice = people[0]
    assert alice.employment.which == "school"

    bob = people[1]
    assert bob.employment.which == "unemployed"

    with pytest.raises(KjException):
        addresses._which_str()

    with pytest.raises(KjException):
        addresses._which()

    with pytest.raises(KjException):
        addresses.which


@pytest.mark.skipif(
    capnp.version.LIBCAPNP_VERSION < 5000,
    reason="Using ints as enums requires v0.5.0+ of the C++ capnp library",
)
def test_enum(addressbook):
    addresses = addressbook.AddressBook.new_message()
    people = addresses.init("people", 2)

    alice = people[0]
    phones = alice.init("phones", 2)

    assert phones[0].type == phones[1].type

    phones[0].type = addressbook.Person.PhoneNumber.Type.home

    assert phones[0].type != phones[1].type

    phones[1].type = "home"

    assert phones[0].type == phones[1].type


def test_builder_set(addressbook):
    person = addressbook.Person.new_message()

    person.name = "test"

    assert person.name == "test"

    with pytest.raises(AttributeError):
        person.foo = "test"


def test_builder_set_from_list(all_types):
    msg = all_types.TestAllTypes.new_message()

    msg.int32List = [0, 1, 2]

    assert list(msg.int32List) == [0, 1, 2]


def test_builder_set_from_tuple(all_types):
    msg = all_types.TestAllTypes.new_message()

    msg.int32List = (0, 1, 2)

    assert list(msg.int32List) == [0, 1, 2]


def test_null_str(all_types):
    msg = all_types.TestAllTypes.new_message()

    msg.textField = "f\x00oo"
    msg.dataField = b"b\x00ar"

    assert msg.textField == "f\x00oo"
    assert msg.dataField == b"b\x00ar"


def test_unicode_str(all_types):
    msg = all_types.TestAllTypes.new_message()

    if sys.version_info[0] == 2:
        msg.textField = "f\u00e6oo".encode("utf-8")

        assert msg.textField.decode("utf-8") == "f\u00e6oo"
    else:
        msg.textField = "f\u00e6oo"

        assert msg.textField == "f\u00e6oo"


def test_new_message(all_types):
    msg = all_types.TestAllTypes.new_message(int32Field=100)

    assert msg.int32Field == 100

    msg = all_types.TestAllTypes.new_message(structField={"int32Field": 100})

    assert msg.structField.int32Field == 100

    msg = all_types.TestAllTypes.new_message(
        structList=[{"int32Field": 100}, {"int32Field": 101}]
    )

    assert msg.structList[0].int32Field == 100
    assert msg.structList[1].int32Field == 101

    msg = all_types.TestAllTypes.new_message(int32Field=100)

    assert msg.int32Field == 100

    msg = all_types.TestAllTypes.new_message(**{"int32Field": 100, "int64Field": 101})

    assert msg.int32Field == 100
    assert msg.int64Field == 101


def test_set_dict(all_types):
    msg = all_types.TestAllTypes.new_message()

    msg.structField = {"int32Field": 100}

    assert msg.structField.int32Field == 100

    msg.init("structList", 2)
    msg.structList[0] = {"int32Field": 102}

    assert msg.structList[0].int32Field == 102


def test_set_dict_union(addressbook):
    person = addressbook.Person.new_message(
        **{"employment": {"employer": {"name": "foo"}}}
    )

    assert person.employment.which == addressbook.Person.Employment.employer

    assert person.employment.employer.name == "foo"


def test_union_enum(all_types):
    assert all_types.UnionAllTypes.Union.UnionStructField1 == 0
    assert all_types.UnionAllTypes.Union.UnionStructField2 == 1

    msg = all_types.UnionAllTypes.new_message(
        **{"unionStructField1": {"textField": "foo"}}
    )
    assert msg.which == all_types.UnionAllTypes.Union.UnionStructField1
    assert msg.which == "unionStructField1"
    assert msg.which == 0

    msg = all_types.UnionAllTypes.new_message(
        **{"unionStructField2": {"textField": "foo"}}
    )
    assert msg.which == all_types.UnionAllTypes.Union.UnionStructField2
    assert msg.which == "unionStructField2"
    assert msg.which == 1

    assert all_types.GroupedUnionAllTypes.Union.G1 == 0
    assert all_types.GroupedUnionAllTypes.Union.G2 == 1

    msg = all_types.GroupedUnionAllTypes.new_message(
        **{"g1": {"unionStructField1": {"textField": "foo"}}}
    )
    assert msg.which == all_types.GroupedUnionAllTypes.Union.G1

    msg = all_types.GroupedUnionAllTypes.new_message(
        **{"g2": {"unionStructField2": {"textField": "foo"}}}
    )
    assert msg.which == all_types.GroupedUnionAllTypes.Union.G2

    msg = all_types.UnionAllTypes.new_message()
    msg.unionStructField2 = msg.init(all_types.UnionAllTypes.Union.UnionStructField2)


def isstr(s):
    return isinstance(s, str)


def test_to_dict_enum(addressbook):
    person = addressbook.Person.new_message(
        **{"phones": [{"number": "999-9999", "type": "mobile"}]}
    )

    field = person.to_dict()["phones"][0]["type"]
    assert isstr(field)
    assert field == "mobile"


def test_explicit_field(addressbook):
    person = addressbook.Person.new_message(**{"name": "Test"})

    name_field = addressbook.Person.schema.fields["name"]

    assert person.name == person._get_by_field(name_field)
    assert person.name == person.as_reader()._get_by_field(name_field)


def test_to_dict_verbose(addressbook):
    person = addressbook.Person.new_message(**{"name": "Test"})

    assert person.to_dict(verbose=True)["phones"] == []

    if sys.version_info >= (2, 7):
        assert person.to_dict(verbose=True, ordered=True)["phones"] == []

    with pytest.raises(KeyError):
        assert person.to_dict()["phones"] == []


def test_to_dict_ordered(addressbook):
    person = addressbook.Person.new_message(
        **{
            "name": "Alice",
            "phones": [{"type": "mobile", "number": "555-1212"}],
            "id": 123,
            "employment": {"school": "MIT"},
            "email": "alice@example.com",
        }
    )

    if sys.version_info >= (2, 7):
        assert list(person.to_dict(ordered=True).keys()) == [
            "id",
            "name",
            "email",
            "phones",
            "employment",
        ]
    else:
        with pytest.raises(Exception):
            person.to_dict(ordered=True)


def test_nested_list(addressbook):
    struct = addressbook.NestedList.new_message()
    struct.init("list", 2)

    struct.list.init(0, 1)
    struct.list.init(1, 2)

    struct.list[0][0] = 1
    struct.list[1][0] = 2
    struct.list[1][1] = 3

    assert struct.to_dict()["list"] == [[1], [2, 3]]
