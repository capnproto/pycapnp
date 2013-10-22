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

    return parser.parse_args()

def encode(schema_file, struct_name):
    schema = capnp.load(schema_file)

    struct_schema = getattr(schema, struct_name)
    
    struct_dict = json.load(sys.stdin)
    struct = struct_schema.from_dict(struct_dict)

    struct.write(sys.stdout)

def decode(schema_file, struct_name):
    schema = capnp.load(schema_file)

    struct_schema = getattr(schema, struct_name)
    struct = struct_schema.read(sys.stdin)
    
    json.dump(struct.to_dict(), sys.stdout)

def main():
    args = parse_args()

    command = args.command
    kwargs = vars(args)
    del kwargs['command']

    globals()[command](**kwargs) # hacky way to get defined functions, and call function with name=command

main()