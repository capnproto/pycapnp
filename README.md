#capnpc-python-cpp

## Downloading

For now, this code is only on github, although I plan to put it up on PyPi at somepoint.

You can clone the repo like so:

    git clone https://github.com/jparyani/capnpc-python-cpp.git

## Requirements

A system-wide installation of the Capnproto C++ library, compiled with the 
-fpic flag. All you need to do is follow the official [installation docs](http://kentonv.github.io/capnproto/install.html)].

You also need a working version of the latest [Cython](http://cython.org/) installed. This is easily done with:

    pip install 'cython >= 0.19.1'

## Building and installation

`cd` into the repo directory and run `python setup.py install` or `pip install .`

## Documentation/Example
At the moment, there is no documenation, but the library is almost a 1:1 clone of the [Capnproto C++ Library](http://kentonv.github.io/capnproto/cxx.html)

The examples has one example that shows off the capabilities quite nicely. Here it is, reproduced:

    import os
    import capnp
    this_dir = os.path.dirname(__file__)
    addressbook = capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

    def writeAddressBook(fd):
        message = capnp.MallocMessageBuilder()
        addressBook = message.initRoot(addressbook.AddressBook)
        people = addressBook.initPeople(2)

        alice = people[0]
        alice.id = 123
        alice.name = 'Alice'
        alice.email = 'alice@example.com'
        alicePhones = alice.initPhones(1)
        alicePhones[0].number = "555-1212"
        alicePhones[0].type = 'mobile'
        alice.employment.school = "MIT"

        bob = people[1]
        bob.id = 456
        bob.name = 'Bob'
        bob.email = 'bob@example.com'
        bobPhones = bob.initPhones(2)
        bobPhones[0].number = "555-4567"
        bobPhones[0].type = 'home'
        bobPhones[1].number = "555-7654" 
        bobPhones[1].type = addressbook.Person.PhoneNumber.Type.WORK
        bob.employment.unemployed = None # This is definitely bad, syntax will change at some point

        capnp.writePackedMessageToFd(fd, message)

    f = open('example', 'w')
    writeAddressBook(f.fileno())

    def printAddressBook(fd):
        message = capnp.PackedFdMessageReader(f.fileno())
        addressBook = message.getRoot(addressbook.AddressBook)

        for person in addressBook.people:
            print person.name, ':', person.email
            for phone in person.phones:
                print phone.type, ':', phone.number

            which = person.employment.which()
            print which

            if which == addressbook.Person.Employment.Which.UNEMPLOYED:
                print 'unemployed'
            elif which == addressbook.Person.Employment.Which.EMPLOYER:
                print 'employer:', person.employment.employer
            elif which == addressbook.Person.Employment.Which.SCHOOL:
                print 'student at:', person.employment.school
            elif which == addressbook.Person.Employment.Which.SELF_EMPLOYED:
                print 'unemployed'
            print

    f = open('example', 'r')
    printAddressBook(f.fileno())
