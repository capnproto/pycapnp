from __future__ import print_function
import os
import capnp

this_dir = os.path.dirname(__file__)
addressbook = capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

print = lambda *x: x


def writeAddressBook(fd):
    message = capnp.MallocMessageBuilder()
    addressBook = message.initRoot(addressbook.AddressBook)
    people = addressBook.initResizableList('people')

    alice = people.add()
    alice.id = 123
    alice.name = 'Alice'
    alice.email = 'alice@example.com'
    alicePhones = alice.init('phones', 1)
    alicePhones[0].number = "555-1212"
    alicePhones[0].type = 'mobile'

    bob = people.add()
    bob.id = 456
    bob.name = 'Bob'
    bob.email = 'bob@example.com'
    bobPhones = bob.init('phones', 2)
    bobPhones[0].number = "555-4567"
    bobPhones[0].type = 'home'
    bobPhones[1].number = "555-7654"
    bobPhones[1].type = 'work'

    people.finish()

    capnp.writePackedMessageToFd(fd, message)


def printAddressBook(fd):
    message = capnp.PackedFdMessageReader(f.fileno())
    addressBook = message.getRoot(addressbook.AddressBook)

    for person in addressBook.people:
        print(person.name, ':', person.email)
        for phone in person.phones:
            print(phone.type, ':', phone.number)
        print()


if __name__ == '__main__':
    for i in range(10000):
        f = open('example', 'w')
        writeAddressBook(f.fileno())

        f = open('example', 'r')
        printAddressBook(f.fileno())

os.remove('example')
