#!/usr/bin/env python3

import capnp  # noqa: F401

import addressbook_capnp

class Allocator:
    def __init__(self):
        self.cur_size = 0
        self.last_size = 0

    def __call__(self, minimum_size: int) -> bytearray:
        actual_size = max(minimum_size, self.cur_size)
        print(f"minimum_size: {minimum_size}, last_size: {self.last_size}, "
              f"actual_size: {actual_size}, cur_size: {self.cur_size}")
        self.last_size = actual_size
        self.cur_size += actual_size

        WORD_SIZE = 8
        byte_count = actual_size * WORD_SIZE
        return bytearray(byte_count)

msg_builder = capnp._PyCustomMessageBuilder(Allocator(), 3)
struct_builder = msg_builder.init_root(addressbook_capnp.Person)
print()

struct_builder.init("extraData", 5)
print(struct_builder.extraData)
print(bytes(struct_builder.extraData))
print(type(struct_builder.extraData))
print()

struct_builder.extraData[1] = 0xff
print(struct_builder.extraData)
print(bytes(struct_builder.extraData))
print()

struct_builder.extraData = b'hello'
print(struct_builder.extraData)
print(bytes(struct_builder.extraData))
print(type(struct_builder.extraData))
print()

struct_builder = struct_builder.as_reader()
print(struct_builder.extraData)
print(bytes(struct_builder.extraData))
print(type(struct_builder.extraData))