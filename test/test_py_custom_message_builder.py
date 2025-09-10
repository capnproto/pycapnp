#!/usr/bin/env python3

import pytest
import capnp  # noqa: F401
import os

this_dir = os.path.dirname(__file__)


@pytest.fixture
def all_types():
    return capnp.load(os.path.join(this_dir, "all_types.capnp"))


def test_addressbook(all_types):
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

    allocator = Allocator()
    assert allocator.cur_size == 0
    assert allocator.last_size == 0
    msg_builder = capnp._PyCustomMessageBuilder(allocator, 1024)
    struct_builder = msg_builder.init_root(all_types.TestAllTypes)
    assert allocator.cur_size == 1024
    assert allocator.last_size == 1024

    struct_builder.init("dataField", 5)
    assert struct_builder._get("dataField") == b"\x00\x00\x00\x00\x00"

    struct_builder._get("dataField")[1] = 0xFF
    assert struct_builder._get("dataField") == b"\x00\xff\x00\x00\x00"

    struct_builder.dataField = b"hello"
    assert struct_builder._get("dataField") == b"hello"

    struct_builder = struct_builder.as_reader()
    assert struct_builder._get("dataField") == b"hello"
