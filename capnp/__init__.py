"""A python library wrapping the Cap'n Proto C++ library

Example Usage::

    import capnp

    addressbook = capnp.load('addressbook.capnp')

    # Building
    addresses = addressbook.AddressBook.newMessage()
    people = addresses.init('people', 1)

    alice = people[0]
    alice.id = 123
    alice.name = 'Alice'
    alice.email = 'alice@example.com'
    alicePhone = alice.init('phones', 1)[0]
    alicePhone.type = 'mobile'

    f = open('example.bin', 'w')
    addresses.write(f)
    f.close()

    # Reading
    f = open('example.bin')

    addresses = addressbook.AddressBook.read(f)

    for person in addresses.people:
        print(person.name, ':', person.email)
        for phone in person.phones:
            print(phone.type, ':', phone.number)
"""
# flake8: noqa F401 F403 F405
from .version import version as __version__
from .lib.capnp import *
from .lib.capnp import (
    _CapabilityClient,
    _DynamicCapabilityClient,
    _DynamicListBuilder,
    _DynamicListReader,
    _DynamicOrphan,
    _DynamicResizableListBuilder,
    _DynamicStructBuilder,
    _DynamicStructReader,
    _EventLoop,
    _InterfaceModule,
    _ListSchema,
    _MallocMessageBuilder,
    _PackedFdMessageReader,
    _StreamFdMessageReader,
    _StructModule,
    _write_message_to_fd,
    _write_packed_message_to_fd,
    _Promise as Promise,
    _init_capnp_api,
)

_init_capnp_api()
add_import_hook()  # enable import hook by default
