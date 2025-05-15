#!/usr/bin/env python3

import pytest
import capnp  # noqa: F401
import os

this_dir = os.path.dirname(__file__)

@pytest.fixture
def all_types():
    return capnp.load(os.path.join(this_dir, "all_types.capnp"))

def test_addressbook(all_types):
    print()
    def allocate_segment(minimum_size: int, last_size: int, cur_size: int) -> bytearray:
        # note, the unit of size is WORD, and each WORD is 8 bytes
        if minimum_size <= 0:
            minimum_size = 1
        minimum_size = max(minimum_size, cur_size)
        WORD_SIZE = 8
        byte_count = minimum_size * WORD_SIZE
        return bytearray(byte_count)

    msg_builder = capnp._PyCustomMessageBuilder(allocate_segment, 1)
    struct_builder = msg_builder.init_root(all_types.TestAllTypes)
    struct_builder.init("dataField", 5)
    assert struct_builder._get('dataField') == b'\x00\x00\x00\x00\x00'

    struct_builder._get('dataField')[1] = 0xff
    assert struct_builder._get('dataField') == b'\x00\xff\x00\x00\x00'

    struct_builder.dataField = b'hello'
    assert struct_builder._get('dataField') == b'hello'

    struct_builder = struct_builder.as_reader()
    assert struct_builder._get('dataField') == b'hello'
