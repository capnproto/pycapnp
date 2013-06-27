# schema.capnp.cpp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnp
from schema_cpp cimport Node

cdef extern from "capnp/dynamic.h" namespace "::capnp":
    cdef cppclass DynamicValue:
        cppclass Reader:
            pass
    cdef cppclass DynamicStruct:
        cppclass Reader:
            DynamicValue.Reader get(char *) except +ValueError
            bint has(char *)

cdef extern from "capnp/schema.h" namespace "::capnp":
    cdef cppclass Schema:
        Node.Reader getProto()
        StructSchema asStruct()
    cdef cppclass StructSchema(Schema):
        pass

cdef extern from "capnp/schema-loader.h" namespace "::capnp":
    cdef cppclass SchemaLoader:
        SchemaLoader()
        Schema load(Node.Reader &) except +