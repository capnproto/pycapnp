# pycapnp

More thorough docs are available at [http://jparyani.github.io/pycapnp/](http://jparyani.github.io/pycapnp/).

## Requirements

First you need a system-wide installation of the Cap'n Proto C++ library == 0.4.x. Follow the [official installation docs](http://kentonv.github.io/capnproto/install.html) or for the lazy:

```bash
curl -O http://capnproto.org/capnproto-c++-0.4.0.tar.gz
tar zxf capnproto-c++-0.4.0.tar.gz
cd capnproto-c++-0.4.0
./configure
make -j6 check
sudo make install
```

A recent version of cython and setuptools is also required. You can install these with:
    
```bash
pip install -U cython
pip install -U setuptools
```

## Building and installation

Install with `pip install pycapnp`. You can set the CC environment variable to control which compiler is used, ie `CC=gcc-4.8 pip install pycapnp`.

Or you can clone the repo like so:

    git clone https://github.com/jparyani/pycapnp.git
    pip install ./pycapnp

Note: for OSX, if using clang from Xcode 5, you will need to set `CFLAGS` like so:

    CFLAGS='-stdlib=libc++' pip install pycapnp

## Python Versions

Python 2.6/2.7 are supported as well as Python 3.2+. PyPy 2.1+ is also supported.

One oddity to note is that `Text` type fields will be treated as byte strings under Python 2, and unicode strings under Python 3. `Data` fields will always be treated as byte strings.

## Development

This project uses [git-flow](http://jeffkreeftmeijer.com/2010/why-arent-you-using-git-flow/). Essentially, just make sure you do your changes in the `develop` branch. You can run the tests by installing pytest with `pip install pytest`, and then run `py.test` from the `test` directory.

## Documentation/Example
There is some basic documentation [here](http://jparyani.github.io/pycapnp/).

The examples directory has one example that shows off the capabilities quite nicely. Here it is, reproduced:

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

## Common Problems

If you get an error on installation like:

    ...
    gcc-4.8: error: capnp/capnp.c: No such file or directory

    gcc-4.8: fatal error: no input files

Then you have too old a version of setuptools. Run `pip install -U setuptools` then try again.


An error like:

    ...
    capnp/capnp.cpp:312:10: fatal error: 'capnp/dynamic.h' file not found
    #include "capnp/dynamic.h"

Means you haven't installed the Cap'n Proto C++ library. Please follow the directions at the [official installation docs](http://kentonv.github.io/capnproto/install.html)


[![Build Status](https://travis-ci.org/jparyani/pycapnp.png?branch=develop)](https://travis-ci.org/jparyani/pycapnp)
