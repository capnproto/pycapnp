#capnpc-python-cpp

## Requirements

First you need a system-wide installation of the Capnproto C++ library >= 0.3. Unfortunately, as of now, that means you have to build from the HEAD of Cap'n Proto. Follow these instructions to do so:

    wget https://github.com/kentonv/capnproto/archive/master.zip
    unzip master.zip
    cd capnproto-master/c++
    ./setup-autotools.sh
    autoreconf -i
    ./configure
    make -j6 check
    sudo make install
    sudo ldconfig

## Building and installation

Install with `pip install capnp`

Or you can clone the repo like so:

    git clone https://github.com/jparyani/capnpc-python-cpp.git

`cd` into the repo directory and run `pip install .`

## Documentation/Example
There is some basic documentation [here](http://jparyani.github.io/capnpc-python-cpp/).

The examples directory has one example that shows off the capabilities quite nicely. Here it is, reproduced:

```python
import capnp
addressbook = capnp.load('addressbook.capnp')

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
    bobPhones[1].type = 'work'
    bob.employment.unemployed = None

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

        if which == 'unemployed':
            print('unemployed')
        elif which == 'employer':
            print('employer:', person.employment.employer)
        elif which == 'school':
            print('student at:', person.employment.school)
        elif which == 'selfEmployed':
            print('self employed')
        print

f = open('example', 'r')
printAddressBook(f.fileno())
```

[![Build Status](https://travis-ci.org/jparyani/capnpc-python-cpp.png?branch=master)](https://travis-ci.org/jparyani/capnpc-python-cpp)

