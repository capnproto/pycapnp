#!/usr/bin/env python3

import argparse
import asyncio

import capnp
import addressbook_capnp


async def writeAddressBook(stream, alice_id):
    addresses = addressbook_capnp.AddressBook.new_message()
    people = addresses.init("people", 1)

    alice = people[0]
    alice.id = alice_id
    alice.name = "Alice"
    alice.email = "alice@example.com"
    alicePhones = alice.init("phones", 1)
    alicePhones[0].number = "555-1212"
    alicePhones[0].type = "mobile"
    alice.employment.school = "MIT"

    await addresses.write_async(stream)


async def new_connection(stream):
    message = await addressbook_capnp.AddressBook.read_async(stream)
    print(message)
    assert message.people[0].name == "Bob"
    assert message.people[0].id == 0

    await writeAddressBook(stream, 0)

    message = await addressbook_capnp.AddressBook.read_async(stream)
    print(message)
    assert message.people[0].name == "Bob"
    assert message.people[0].id == 1

    message = await addressbook_capnp.AddressBook.read_async(stream)
    print(message)
    assert message is None


def parse_args():
    parser = argparse.ArgumentParser(
        usage="""Runs the server bound to the given address/port ADDRESS. """
    )

    parser.add_argument("address", help="ADDRESS:PORT")

    return parser.parse_args()


async def main():
    host, port = parse_args().address.split(":")
    server = await capnp.AsyncIoStream.create_server(new_connection, host, port)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
