#!/usr/bin/env python3

import capnp  # noqa: F401
import addressbook_capnp


class Allocator:
    def __init__(self):
        self.cur_size = 0
        self.last_size = 0

    def __call__(self, minimum_size: int) -> bytearray:
        actual_size = max(minimum_size, self.cur_size)
        print(
            f"minimum_size: {minimum_size}, last_size: {self.last_size}, "
            f"actual_size: {actual_size}, cur_size: {self.cur_size}"
        )
        self.last_size = actual_size
        self.cur_size += actual_size

        WORD_SIZE = 8
        byte_count = actual_size * WORD_SIZE
        return bytearray(byte_count)


person = addressbook_capnp.Person.new_message(allocate_seg_callable=Allocator())

person.init("extraData", 5)
print(person.extraData)
print(bytes(person.extraData))
print(type(person.extraData))
print()

person.extraData[1] = 0xFF
print(person.extraData)
print(bytes(person.extraData))
print()

person.extraData = b"hello"
print(person.extraData)
print(bytes(person.extraData))
print(type(person.extraData))
print()

person = person.as_reader()
print(person.extraData)
print(bytes(person.extraData))
print(type(person.extraData))
