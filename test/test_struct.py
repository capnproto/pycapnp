import pytest
import capnp
import os
import tempfile
import sys

this_dir = os.path.dirname(__file__)


@pytest.fixture
def addressbook():
    return capnp.load(os.path.join(this_dir, 'addressbook.capnp'))


@pytest.fixture
def all_types():
    return capnp.load(os.path.join(this_dir, 'all_types.capnp'))


def test_which_builder(addressbook):
    addresses = addressbook.AddressBook.new_message()
    people = addresses.init('people', 2)

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

    with pytest.raises(ValueError):
        addresses.which
    with pytest.raises(ValueError):
        addresses.which


def test_which_reader(addressbook):
    def writeAddressBook(fd):
        message = capnp._MallocMessageBuilder()
        addressBook = message.init_root(addressbook.AddressBook)
        people = addressBook.init('people', 2)

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

    with pytest.raises(ValueError):
        addresses.which
    with pytest.raises(ValueError):
        addresses.which


@pytest.mark.skipif(capnp.version.LIBCAPNP_VERSION < 5000, reason="Using ints as enums requires v0.5.0+ of the C++ capnp library")
def test_enum(addressbook):
    addresses = addressbook.AddressBook.new_message()
    people = addresses.init('people', 2)

    alice = people[0]
    phones = alice.init('phones', 2)

    assert phones[0].type == phones[1].type

    phones[0].type = addressbook.Person.PhoneNumber.Type.home

    assert phones[0].type != phones[1].type

    phones[1].type = 'home'

    assert phones[0].type == phones[1].type


def test_builder_set(addressbook):
    person = addressbook.Person.new_message()

    person.name = 'test'

    assert person.name == 'test'

    with pytest.raises(AttributeError):
        person.foo = 'test'


def test_null_str(all_types):
    msg = all_types.TestAllTypes.new_message()

    msg.textField = "f\x00oo"
    msg.dataField = b"b\x00ar"

    assert msg.textField == "f\x00oo"
    assert msg.dataField == b"b\x00ar"


def test_unicode_str(all_types):
    msg = all_types.TestAllTypes.new_message()

    if sys.version_info[0] == 2:
        msg.textField = u"f\u00e6oo".encode('utf-8')

        assert msg.textField.decode('utf-8') == u"f\u00e6oo"
    else:
        msg.textField = "f\u00e6oo"

        assert msg.textField == "f\u00e6oo"


def test_new_message(all_types):
    msg = all_types.TestAllTypes.new_message(int32Field=100)

    assert msg.int32Field == 100

    msg = all_types.TestAllTypes.new_message(structField={'int32Field': 100})

    assert msg.structField.int32Field == 100

    msg = all_types.TestAllTypes.new_message(structList=[{'int32Field': 100}, {'int32Field': 101}])

    assert msg.structList[0].int32Field == 100
    assert msg.structList[1].int32Field == 101

    msg = all_types.TestAllTypes.new_message(int32Field=100)

    assert msg.int32Field == 100

    msg = all_types.TestAllTypes.new_message(**{'int32Field': 100, 'int64Field': 101})

    assert msg.int32Field == 100
    assert msg.int64Field == 101


def test_set_dict(all_types):
    msg = all_types.TestAllTypes.new_message()

    msg.structField = {'int32Field': 100}

    assert msg.structField.int32Field == 100

    msg.init('structList', 2)
    msg.structList[0] = {'int32Field': 102}

    assert msg.structList[0].int32Field == 102


def test_set_dict_union(addressbook):
    person = addressbook.Person.new_message(**{'employment': {'employer': {'name': 'foo'}}})

    assert person.employment.employer.name == 'foo'
