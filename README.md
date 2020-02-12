# pycapnp

[![Packaging Status](https://github.com/capnproto/pycapnp/workflows/Packaging%20Test/badge.svg)](https://github.com/capnproto/pycapnp/actions)
[![manylinux2010 Status](https://github.com/capnproto/pycapnp/workflows/manylinux2010/badge.svg)](https://github.com/capnproto/pycapnp/actions)
[![PyPI version](https://badge.fury.io/py/pycapnp.svg)](https://badge.fury.io/py/pycapnp)
[![Total alerts](https://img.shields.io/lgtm/alerts/g/capnproto/pycapnp.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/capnproto/pycapnp/alerts/)
[![Language grade: Python](https://img.shields.io/lgtm/grade/python/g/capnproto/pycapnp.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/capnproto/pycapnp/context:python)
[![Language grade: C/C++](https://img.shields.io/lgtm/grade/cpp/g/capnproto/pycapnp.svg?logo=lgtm&logoWidth=18)](https://lgtm.com/projects/g/capnproto/pycapnp/context:cpp)

[Cap'n'proto Mailing List](https://groups.google.com/forum/#!forum/capnproto)


## Requirements

* C++14 supported compiler
  - gcc 6.1+ (5+ may work)
  - clang 6 (3.4+ may work)
  - Visual Studio 2017+
* cmake (needed for bundled capnproto)
  - ninja (macOS + Linux)
  - Visual Studio 2017+

* capnproto-0.7.0
  - Not necessary if using bundled capnproto

32-bit Linux requires that capnproto be compiled with `-fPIC`. This is usually set correctly unless you are compiling canproto yourself. This is also called `-DCMAKE_POSITION_INDEPENDENT_CODE=1` for cmake.

pycapnp has additional development dependencies, including cython and pytest. See requirements.txt for them all.


## Building and installation

Install with `pip install pycapnp`. You can set the CC environment variable to control which compiler is used, ie `CC=gcc-8.2 pip install pycapnp`.

Or you can clone the repo like so:

```bash
git clone https://github.com/capnproto/pycapnp.git
cd pycapnp
pip install .
```

If you wish to install using the latest upstream C++ Cap'n Proto:

```bash
pip install \
    --install-option "--libcapnp-url" \
    --install-option "https://github.com/sandstorm-io/capnproto/archive/master.tar.gz" \
    --install-option "--force-bundled-libcapnp" .
```

To force bundled python:

```bash
pip install --install-option "--force-bundled-libcapnp" .
```


## Python Versions

Python 3.7+ is supported.
Earlier versions of Python have asyncio bugs that might be possible to work around, but may require significant work (3.5 and 3.6).


## Development

Git flow has been abandoned, use master.

To test, use a pipenv (or install requirements.txt and run pytest manually).
```bash
pip install pipenv
pipenv install
pipenv run pytest
```


### Binary Packages

Building a dumb binary distribution:

```bash
python setup.py bdist_dumb
```

Building a Python wheel distributiion:

```bash
python setup.py bdist_wheel
```


## Documentation/Example

There is some basic documentation [here](http://jparyani.github.io/pycapnp/).

Make sure to look at the [examples](examples). The examples are generally kept up to date with the recommended usage of the library.

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
