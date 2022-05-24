#!/usr/bin/env python
import os
import sys

import capnp

capnp.add_import_hook(
    [os.getcwd(), "/usr/local/include/"]
)  # change this to be auto-detected?

import test_capnp  # noqa: E402


def decode(name):
    class_name = name[0].upper() + name[1:]
    with getattr(test_capnp, class_name).from_bytes(sys.stdin.read()) as msg:
        print(msg._short_str())


def encode(name):
    val = getattr(test_capnp, name)
    class_name = name[0].upper() + name[1:]
    message = getattr(test_capnp, class_name).from_dict(val.to_dict())
    print(message.to_bytes())


if sys.argv[1] == "decode":
    decode(sys.argv[2])
else:
    encode(sys.argv[2])
