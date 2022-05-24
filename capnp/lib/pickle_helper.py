import capnp


def _struct_reducer(schema_id, data):
    'Hack to deal with pypy not allowing reduce functions to be "built-in" methods (ie. compiled from a .pyx)'
    with capnp._global_schema_parser.modules_by_id[schema_id].from_bytes(data) as msg:
        return msg
