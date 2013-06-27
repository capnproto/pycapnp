# capnp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnp

cimport capnp_cpp as capnp
cimport schema_cpp
from capnp_cpp cimport SchemaLoader as C_SchemaLoader, Schema as C_Schema, StructSchema as C_StructSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue
from schema_cpp cimport CodeGeneratorRequest as C_CodeGeneratorRequest, Node as C_Node
from cython.operator cimport dereference as deref

from libc.stdint cimport *
ctypedef unsigned int uint
ctypedef uint8_t UInt8
ctypedef uint16_t UInt16
ctypedef uint32_t UInt32
ctypedef uint64_t UInt64
ctypedef int8_t Int8
ctypedef int16_t Int16
ctypedef int32_t Int32
ctypedef int64_t Int64

ctypedef char * Object
ctypedef bint Bool
ctypedef float Float32
ctypedef double Float64

cdef extern from "capnp/list.h" namespace "::capnp":
    cdef cppclass List[T]:
        cppclass Reader:
            T operator[](uint) except +ValueError
            uint size()
        cppclass Builder:
            T operator[](uint) except +ValueError
            uint size()

cdef class _List_UInt64_Reader:
    cdef List[UInt64].Reader thisptr
    cdef init(self, List[UInt64].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return self.thisptr[index]

    def __len__(self):
        return self.thisptr.size()

cdef class _List_Node_Reader:
    cdef List[C_Node].Reader thisptr
    cdef init(self, List[C_Node].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _NodeReader().init(<C_Node.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()

cdef class _DynamicValueReader:
    cdef C_DynamicValue.Reader thisptr
    cdef init(self, C_DynamicValue.Reader other):
        self.thisptr = other
        return self
        

cdef class _DynamicStructReader:
    cdef C_DynamicStruct.Reader thisptr
    cdef init(self, C_DynamicStruct.Reader other):
        self.thisptr = other
        return self
        
    def get(self, field):
        return _DynamicValueReader().init(self.thisptr.get(field))

    def has(self, field):
        return self.thisptr.has(field)

cdef class _CodeGeneratorRequestReader:
    cdef C_CodeGeneratorRequest.Reader thisptr
    cdef init(self, C_CodeGeneratorRequest.Reader other):
        self.thisptr = other
        return self
        
    property nodes:
        def __get__(self):
            return _List_Node_Reader().init(self.thisptr.getNodes())
    property requestedFiles:
        def __get__(self):
            return _List_UInt64_Reader().init(self.thisptr.getRequestedFiles())

cdef class _NodeReader:
    cdef C_Node.Reader thisptr
    cdef init(self, C_Node.Reader other):
        self.thisptr = other
        return self
    property displayName:
        def __get__(self):
            return self.thisptr.getDisplayName().cStr()
    property scopeId:
        def __get__(self):
            return self.thisptr.getScopeId()
    property id:
        def __get__(self):
            return self.thisptr.getId()

cdef class Schema:
    cdef C_Schema thisptr
    cdef init(self, C_Schema other):
        self.thisptr = other
        return self

    cpdef asStruct(self):
        return StructSchema().init(self.thisptr.asStruct())

cdef class StructSchema:
    cdef C_StructSchema thisptr
    cdef init(self, C_StructSchema other):
        self.thisptr = other
        return self

cdef class SchemaLoader:
    cdef C_SchemaLoader * thisptr
    def __cinit__(self):
        self.thisptr = new C_SchemaLoader()

    def __dealloc__(self):
        del self.thisptr

    cpdef load(self, _NodeReader node):
        return Schema().init(self.thisptr.load(node.thisptr))

cdef class MessageBuilder:
    cdef schema_cpp.MessageBuilder * thisptr
    def __dealloc__(self):
        del self.thisptr

cdef class MallocMessageBuilder(MessageBuilder):
    def __cinit__(self):
        self.thisptr = new schema_cpp.MallocMessageBuilder()

cdef class MessageReader:
    cdef schema_cpp.MessageReader * thisptr
    def __dealloc__(self):
        del self.thisptr
    cpdef getRootNode(self):
        return _NodeReader().init(self.thisptr.getRootNode())
    cpdef getRootCodeGeneratorRequest(self):
        return _CodeGeneratorRequestReader().init(self.thisptr.getRootCodeGeneratorRequest())
    cpdef getRootDynamicStruct(self, StructSchema schema):
        return _DynamicStructReader().init(self.thisptr.getRootDynamicStruct(schema.thisptr))

cdef class StreamFdMessageReader(MessageReader):
    def __cinit__(self, int fd):
        self.thisptr = new schema_cpp.StreamFdMessageReader(fd)

cdef class PackedFdMessageReader(MessageReader):
    def __cinit__(self, int fd):
        self.thisptr = new schema_cpp.PackedFdMessageReader(fd)

def writeMessageToFd(int fd, MessageBuilder m):
    schema_cpp.writeMessageToFd(fd, deref(m.thisptr))
def writePackedMessageToFd(int fd, MessageBuilder m):
    schema_cpp.writePackedMessageToFd(fd, deref(m.thisptr))