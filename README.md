# pycapnp

More thorough docs are available at [http://jparyani.github.io/pycapnp/](http://jparyani.github.io/pycapnp/).

## Requirements

pycapnp's distribution has no requirements beyond a C++11 compatible compiler. GCC 4.8+ or Clang 3.3+ should work fine.

pycapnp has additional development dependencies, including cython and py.test. See requirements.txt for them all.

## Building and installation

Install with `pip install pycapnp`. You can set the CC environment variable to control which compiler is used, ie `CC=gcc-4.8 pip install pycapnp`.

Or you can clone the repo like so:

    git clone https://github.com/jparyani/pycapnp.git
    pip install --install-option '--force-cython' ./pycapnp

Note: for OSX, if using clang from Xcode 5, you may need to set `CFLAGS` like so:

    CFLAGS='-stdlib=libc++' pip install pycapnp

## Python Versions

Python 2.6/2.7 are supported as well as Python 3.2+. PyPy 2.1+ is also supported.

One oddity to note is that `Text` type fields will be treated as byte strings under Python 2, and unicode strings under Python 3. `Data` fields will always be treated as byte strings.

## Development

This project uses [git-flow](http://jeffkreeftmeijer.com/2010/why-arent-you-using-git-flow/). Essentially, just make sure you do your changes in the `develop` branch. You can run the tests by installing pytest with `pip install pytest`, and then run `py.test` from the `test` directory.

### Binary Packages

In order to build binary packages from this source code, you must specify the `--disable-cython` option:

Building a dumb binary distribution:

    python setup.py bdist_dumb --disable-cython

Building a Python wheel distributiion:

    python setup.py bdist_wheel --disable-cython

If it fails with an error like `clang: error: no such file or directory: 'capnp/lib/capnp.cpp'`, then you need to cythonize fist. This can be done with:

    python setup.py build --force-cython

## Documentation/Example
There is some basic documentation [here](http://jparyani.github.io/pycapnp/).

The examples directory has one example that shows off pycapnp quite nicely. Here it is, reproduced:

```python
from __future__ import print_function
import os
import capnp

import addressbook_capnp

def writeAddressBook(file):
    addresses = addressbook_capnp.AddressBook.new_message()
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

    addresses.write(file)


def printAddressBook(file):
    addresses = addressbook_capnp.AddressBook.read(file)

    for person in addresses.people:
        print(person.name, ':', person.email)
        for phone in person.phones:
            print(phone.type, ':', phone.number)

        which = person.employment.which()
        print(which)

        if which == 'unemployed':
            print('unemployed')
        elif which == 'employer':
            print('employer:', person.employment.employer)
        elif which == 'school':
            print('student at:', person.employment.school)
        elif which == 'selfEmployed':
            print('self employed')
        print()


if __name__ == '__main__':
    f = open('example', 'w')
    writeAddressBook(f)

    f = open('example', 'r')
    printAddressBook(f)
```

Also, pycapnp has gained RPC features that include pipelining and a promise style API. Refer to the calculator example in the examples directory for a much better demonstration:

```python
import capnp
import socket

import test_capability_capnp


class Server(test_capability_capnp.TestInterface.Server):

    def __init__(self, val=1):
        self.val = val

    def foo(self, i, j, **kwargs):
        return str(i * 5 + self.val)


def server(write_end):
    server = capnp.TwoPartyServer(write_end, bootstrap=Server(100))


def client(read_end):
    client = capnp.TwoPartyClient(read_end)

    cap = client.bootstrap()
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = remote.wait()

    assert response.x == '125'


if __name__ == '__main__':
    read_end, write_end = socket.socketpair(socket.AF_UNIX)
    # This is a toy example using socketpair.
    # In real situations, you can use any socket.

    server(write_end)
    client(read_end)
```

## Common Problems

If you get an error on installation like:

    ...
    gcc-4.8: error: capnp/capnp.c: No such file or directory

    gcc-4.8: fatal error: no input files

Then you have too old a version of setuptools. Run `pip install -U setuptools` then try again.


[![Build Status](https://travis-ci.org/jparyani/pycapnp.png?branch=develop)](https://travis-ci.org/jparyani/pycapnp)
