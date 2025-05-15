#!/usr/bin/env python3

import capnp  # noqa: F401

import addressbook_capnp

def test_addressbook(addressbook):
    def allocate_segment(minimum_size: int, last_size: int, cur_size: int) -> bytearray:
        # note, the unit of size is WORD, and each WORD is 8 bytes
        print(str(minimum_size) + " " + str(last_size) + " " + str(cur_size))
        if minimum_size <= 0:
            minimum_size = 1
        minimum_size = max(minimum_size, cur_size)
        WORD_SIZE = 8
        byte_count = minimum_size * WORD_SIZE
        return bytearray(byte_count)

    msg_builder = capnp._PyCustomMessageBuilder(allocate_segment, 1)
    struct_builder = msg_builder.init_root(addressbook_capnp.Person)
    print()

    struct_builder.init("extraData", 5)
    print(struct_builder._get('extraData'))
    print(bytes(struct_builder._get('extraData')))
    print()

    struct_builder._get('extraData')[1] = 0xff
    # msg._get('extraData')[100] = 0xff
    print(struct_builder._get('extraData'))
    print(bytes(struct_builder._get('extraData')))
    print(type(struct_builder._get('extraData')))
    print()

    struct_builder.extraData = b'hell'
    print(struct_builder._get('extraData'))
    print(bytes(struct_builder._get('extraData')))
    print(type(struct_builder._get('extraData')))
    print()

    struct_builder = struct_builder.as_reader()
    print(struct_builder.extraData)
    print(type(struct_builder.extraData))
