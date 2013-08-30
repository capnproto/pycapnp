"""A python library wrapping the Cap'n Proto C++ library

Example Usage::
    
    import capnp

    addressbook = capnp.load('addressbook.capnp')

    # Building
    message = capnp.MallocMessageBuilder()
    addressBook = message.initRoot(addressbook.AddressBook)
    people = addressBook.init('people', 1)

    alice = people[0]
    alice.id = 123
    alice.name = 'Alice'
    alice.email = 'alice@example.com'
    alicePhone = alice.init('phones', 1)[0]
    alicePhone.type = 'mobile'

    f = open('example.bin', 'w')
    capnp.writePackedMessageToFd(f.fileno(), message)
    f.close()

    # Reading
    f = open('example.bin')
    message = capnp.PackedFdMessageReader(f.fileno())

    addressBook = message.getRoot(addressbook.AddressBook)

    for person in addressBook.people:
        print(person.name, ':', person.email)
        for phone in person.phones:
            print(phone.type, ':', phone.number)
"""
from .version import version as __version__
from .capnp import *
from .capnp import _DynamicStructReader, _DynamicStructBuilder, _DynamicResizableListBuilder, _DynamicListReader, _DynamicListBuilder, _DynamicOrphan, _DynamicResizableListBuilder
del capnp
