# pycapnp

[![Packaging Status](https://github.com/capnproto/pycapnp/workflows/Packaging%20Test/badge.svg)](https://github.com/capnproto/pycapnp/actions)
[![manylinux2014 Status](https://github.com/capnproto/pycapnp/workflows/manylinux2014/badge.svg)](https://github.com/capnproto/pycapnp/actions)
[![PyPI version](https://badge.fury.io/py/pycapnp.svg)](https://badge.fury.io/py/pycapnp)

[Cap'n'proto Mailing List](https://github.com/capnproto/capnproto/discussions) [Documentation](https://capnproto.github.io/pycapnp)


## Requirements

* C++14 supported compiler
  - gcc 6.1+ (5+ may work)
  - clang 6 (3.4+ may work)
  - Visual Studio 2017+
* cmake (needed for bundled capnproto)
  - ninja (macOS + Linux)
  - Visual Studio 2017+
* capnproto-1.0 (>=0.8.0 will also work if linking to system libraries)
  - Not necessary if using bundled capnproto
* Python development headers (i.e. Python.h)
  - Distributables from python.org include these, however they are usually in a separate package on Linux distributions

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

By default, the setup script will automatically use the locally installed Cap'n Proto.
If Cap'n Proto is not installed, it will bundle and build the matching Cap'n Proto library.

To enforce bundling, the Cap'n Proto library:

```bash
pip install . -C force-bundled-libcapnp=True
```

If you wish to install using the latest upstream C++ Cap'n Proto:

```bash
pip install . \
    -C force-bundled-libcapnp=True \
    -C libcapnp-url="https://github.com/capnproto/capnproto/archive/master.tar.gz"
```

To enforce using the installed Cap'n Proto from the system:

```bash
pip install . -C force-system-libcapnp=True
```

The bundling system isn't that smart so it might be necessary to clean up the bundled build when changing versions:

```bash
python setup.py clean
```


## Stub-file generation

While not directly supported by pycapnp, a tool has been created to help generate pycapnp stubfile to assist with development (this is very helpful if you're new to pypcapnp!). See [#289](https://github.com/capnproto/pycapnp/pull/289#event-9078216721) for more details.

[Python Capnp Stub Generator](https://gitlab.com/mic_public/tools/python-helpers/capnp-stub-generator)


## Python Versions

Python 3.8+ is supported.


## Development

Git flow has been abandoned, use master.

To test, use a pipenv (or install requirements.txt and run pytest manually).
```bash
pip install pipenv
pipenv install
pipenv run pytest
```


### Binary Packages

Building a Python wheel distributiion

```bash
pip wheel .
```

## Documentation/Example

There is some basic documentation [here](http://capnproto.github.io/pycapnp/).

Make sure to look at the [examples](examples). The examples are generally kept up to date with the recommended usage of the library.

The examples directory has one example that shows off pycapnp quite nicely. Here it is, reproduced:

```python
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
import asyncio
import capnp
import socket

import test_capability_capnp


class Server(test_capability_capnp.TestInterface.Server):

    def __init__(self, val=1):
        self.val = val

    async def foo(self, i, j, **kwargs):
        return str(i * 5 + self.val)


async def client(read_end):
    client = capnp.TwoPartyClient(read_end)

    cap = client.bootstrap()
    cap = cap.cast_as(test_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = await remote

    assert response.x == '125'

async def main():
    client_end, server_end = socket.socketpair(socket.AF_UNIX)
    # This is a toy example using socketpair.
    # In real situations, you can use any socket.

    client_end = await capnp.AsyncIoStream.create_connection(sock=client_end)
    server_end = await capnp.AsyncIoStream.create_connection(sock=server_end)

    _ = capnp.TwoPartyServer(server_end, bootstrap=Server(100))
    await client(client_end)


if __name__ == '__main__':
    asyncio.run(capnp.run(main()))
```
