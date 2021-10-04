#!/usr/bin/env python

import argparse
import sys
import json
import capnp


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("command")
    parser.add_argument("schema_file")
    parser.add_argument("struct_name")
    parser.add_argument(
        "-d",
        "--defaults",
        help="include default values in json output",
        action="store_true",
    )

    return parser.parse_args()


def encode(schema_file, struct_name, **kwargs):
    schema = capnp.load(schema_file)

    struct_schema = getattr(schema, struct_name)

    struct_dict = json.load(sys.stdin)
    struct = struct_schema.from_dict(struct_dict)

    struct.write(sys.stdout)


def decode(schema_file, struct_name, defaults):
    schema = capnp.load(schema_file)

    struct_schema = getattr(schema, struct_name)
    struct = struct_schema.read(sys.stdin)

    json.dump(struct.to_dict(defaults), sys.stdout)


def main():
    args = parse_args()

    command = args.command
    kwargs = vars(args)
    del kwargs["command"]

    globals()[command](
        **kwargs
    )  # hacky way to get defined functions, and call function with name=command


main()
