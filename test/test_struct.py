import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)

@pytest.fixture
def addressbook():
     return capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

def test_which_builder(addressbook):
    addresses = addressbook.AddressBook.new_message()
    people = addresses.init('people', 2)

    alice = people[0]
    alice.employment.school = "MIT"

    assert alice.employment.which() == "school"

    bob = people[1]

    assert bob.employment.which() == "unemployed"
    
    bob.employment.unemployed = None

    assert bob.employment.which() == "unemployed"

    with pytest.raises(ValueError):
        addresses.which()
    with pytest.raises(ValueError):
        addresses.which()

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

    f = open('example', 'w')
    writeAddressBook(f.fileno())
    f = open('example', 'r')

    addresses = addressbook.AddressBook.read_packed(f)

    people = addresses.people

    alice = people[0]
    assert alice.employment.which() == "school"

    bob = people[1]
    assert bob.employment.which() == "unemployed"

    with pytest.raises(ValueError):
        addresses.which()
    with pytest.raises(ValueError):
        addresses.which()

def test_builder_set(addressbook):
    person = addressbook.Person.new_message()

    person.name = 'test'

    assert person.name == 'test'

    with pytest.raises(ValueError):
        person.foo = 'test'
