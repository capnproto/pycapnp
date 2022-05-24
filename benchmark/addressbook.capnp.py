import os
import capnp

try:
    profile
except:
    profile = lambda func: func
this_dir = os.path.dirname(__file__)
addressbook = capnp.load(os.path.join(this_dir, "addressbook.capnp"))

print = lambda *x: x


@profile
def writeAddressBook():
    addressBook = addressbook.AddressBook.new_message()
    people = addressBook.init("people", 2)

    alice = people[0]
    alice.id = 123
    alice.name = "Alice"
    alice.email = "alice@example.com"
    alicePhones = alice.init("phones", 1)
    alicePhones[0].number = "555-1212"
    alicePhones[0].type = "mobile"

    bob = people[1]
    bob.id = 456
    bob.name = "Bob"
    bob.email = "bob@example.com"
    bobPhones = bob.init("phones", 2)
    bobPhones[0].number = "555-4567"
    bobPhones[0].type = "home"
    bobPhones[1].number = "555-7654"
    bobPhones[1].type = "work"

    msg_bytes = addressBook.to_bytes()
    return msg_bytes


@profile
def printAddressBook(msg_bytes):
    with addressbook.AddressBook.from_bytes(msg_bytes) as addressBook:
        for person in addressBook.people:
            person.name, person.email
            for phone in person.phones:
                phone.type, phone.number


@profile
def writeAddressBookDict():
    addressBook = addressbook.AddressBook.new_message()
    people = addressBook.init("people", 2)

    alice = people[0]
    alice.id = 123
    alice.name = "Alice"
    alice.email = "alice@example.com"
    alicePhones = alice.init("phones", 1)
    alicePhones[0].number = "555-1212"
    alicePhones[0].type = "mobile"

    bob = people[1]
    bob.id = 456
    bob.name = "Bob"
    bob.email = "bob@example.com"
    bobPhones = bob.init("phones", 2)
    bobPhones[0].number = "555-4567"
    bobPhones[0].type = "home"
    bobPhones[1].number = "555-7654"
    bobPhones[1].type = "work"

    msg = addressBook.to_dict()
    return msg


@profile
def printAddressBookDict(msg):
    addressBook = addressbook.AddressBook.new_message(**msg)

    for person in addressBook.people:
        person.name, person.email
        for phone in person.phones:
            phone.type, phone.number


if __name__ == "__main__":
    # for i in range(10000):
    #     msg_bytes = writeAddressBook()

    #     printAddressBook(msg_bytes)
    for i in range(10000):
        msg = writeAddressBookDict()

        printAddressBookDict(msg)
