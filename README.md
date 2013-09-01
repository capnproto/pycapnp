#pycapnp

More thorough docs are available at [http://jparyani.github.io/pycapnp/](http://jparyani.github.io/pycapnp/).

## Requirements

First you need a system-wide installation of the Cap'n Proto C++ library >= 0.3. Follow the [official installation docs](http://kentonv.github.io/capnproto/install.html) or for the lazy:

```bash
wget http://capnproto.org/capnproto-c++-0.3.0-rc5.tar.gz
tar xzf capnproto-c++-0.3.0-rc5.tar.gz
cd capnproto-c++-0.3.0-rc5
./configure
make -j8 check
sudo make install
```

A recent version of cython and setuptools is also required. You can install these with:
    
```bash
pip install -U cython
pip install -U setuptools
```

## Building and installation

Install with `pip install pycapnp`. You can set the CC environment variable to control the compiler version, ie `CC=gcc-4.8 pip install capnp`.

Or you can clone the repo like so:

    git clone https://github.com/jparyani/pycapnp.git

`cd` into the repo directory and run `pip install .`

## Development

This project uses [git-flow](http://jeffkreeftmeijer.com/2010/why-arent-you-using-git-flow/). Essentially, just make sure you do your changes in the `develop` branch. You can run the tests by installing pytest with `pip install pytest`, and then run `py.test`

## Documentation/Example
There is some basic documentation [here](http://jparyani.github.io/pycapnp/).

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

## Common Problems

If you get an error on installation like:

    ...
    gcc-4.8: error: capnp/capnp.c: No such file or directory

    gcc-4.8: fatal error: no input files

Then you have too old a version of setuptools. Run `pip install -U setuptools` then try again.

[![Build Status](https://travis-ci.org/jparyani/pycapnp.png?branch=master)](https://travis-ci.org/jparyani/pycapnp)

