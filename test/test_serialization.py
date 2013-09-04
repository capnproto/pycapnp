import pytest
import capnp
import os
import platform

this_dir = os.path.dirname(__file__)

@pytest.fixture
def addressbook():
     return capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

def build_message(addressbook):
    addresses = addressbook.AddressBook.new_message()
    people = addresses.init('people', 2)

    alice = people[0]
    alice.id = 123
    alice.name = 'Alice'
    alice.email = 'alice@example.com'
    alicePhones = alice.init('phones', 1)
    alicePhones[0].number = "555-1212"
    alicePhones[0].type = 'mobile'
    alice.employment.school = "MIT"

    bob = people[1]
    bob.id = 456
    bob.name = 'Bob'
    bob.email = 'bob@example.com'
    bobPhones = bob.init('phones', 2)
    bobPhones[0].number = "555-4567"
    bobPhones[0].type = 'home'
    bobPhones[1].number = "555-7654"
    bobPhones[1].type = 'work'
    bob.employment.unemployed = None

    return addresses

def check_msg(addresses):
    people = addresses.people

    alice = people[0]
    assert alice.id == 123
    assert alice.name == 'Alice'
    assert alice.email == 'alice@example.com'
    alicePhones = alice.phones
    assert alicePhones[0].number == "555-1212"
    assert alicePhones[0].type == 'mobile'
    assert alice.employment.school == "MIT"

    bob = people[1]
    assert bob.id == 456
    assert bob.name == 'Bob'
    assert bob.email == 'bob@example.com'
    bobPhones = bob.phones
    assert bobPhones[0].number == "555-4567"
    assert bobPhones[0].type == 'home'
    assert bobPhones[1].number == "555-7654"
    assert bobPhones[1].type == 'work'
    assert bob.employment.unemployed == None


def test_roundtrip_file(addressbook):
    f = open('example', 'w')
    msg = build_message(addressbook)
    msg.write(f)

    f = open('example', 'r')
    msg = addressbook.AddressBook.read(f)
    check_msg(msg)

def test_roundtrip_file_packed(addressbook):
    f = open('example', 'w')
    msg = build_message(addressbook)
    msg.write_packed(f)

    f = open('example', 'r')
    msg = addressbook.AddressBook.read_packed(f)
    check_msg(msg)

def test_roundtrip_bytes(addressbook):
    msg = build_message(addressbook)
    message_bytes = msg.to_bytes()

    msg = addressbook.AddressBook.from_bytes(message_bytes)
    check_msg(msg)

@pytest.mark.skipif("platform.python_implementation() == 'PyPy'")
def test_roundtrip_dict(addressbook):
    msg = build_message(addressbook)
    d = msg.to_dict()

    msg = addressbook.AddressBook.from_dict(d)
    check_msg(msg)
