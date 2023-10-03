#!/usr/bin/env python3

import asyncio
import argparse
import capnp

import addressbook_capnp


def parse_args():
    parser = argparse.ArgumentParser(
        usage="Connects to the Example thread server at the given address and does some RPCs"
    )
    parser.add_argument("host", help="HOST:PORT")

    return parser.parse_args()


async def writeAddressBook(stream, bob_id):
    addresses = addressbook_capnp.AddressBook.new_message()
    people = addresses.init("people", 1)

    bob = people[0]
    bob.id = bob_id
    bob.name = "Bob"
    bob.email = "bob@example.com"
    bobPhones = bob.init("phones", 2)
    bobPhones[0].number = "555-4567"
    bobPhones[0].type = "home"
    bobPhones[1].number = "555-7654"
    bobPhones[1].type = "work"
    bob.employment.unemployed = None

    await addresses.write_async(stream)


async def main(host):
    host, port = host.split(":")
    stream = await capnp.AsyncIoStream.create_connection(host=host, port=port)

    await writeAddressBook(stream, 0)

    message = await addressbook_capnp.AddressBook.read_async(stream)
    print(message)
    assert message.people[0].name == "Alice"
    assert message.people[0].id == 0

    await writeAddressBook(stream, 1)


if __name__ == "__main__":
    args = parse_args()
    asyncio.run(capnp.run(main(args.host)))
