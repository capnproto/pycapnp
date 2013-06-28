# capnp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnp

cimport cython
cimport capnp_cpp as capnp
cimport schema_cpp
from capnp_cpp cimport SchemaLoader as C_SchemaLoader, Schema as C_Schema, StructSchema as C_StructSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue, Type as C_Type, DynamicList as C_DynamicList, DynamicUnion as C_DynamicUnion, fixMaybe
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

ctypedef fused valid_values:
    int
    long
    float
    double
    bint

def _make_enum(enum_name, *sequential, **named):
    enums = dict(zip(sequential, range(len(sequential))), **named)
    reverse = dict((value, key) for key, value in enums.iteritems())
    enums['reverse_mapping'] = reverse
    return type(enum_name, (), enums)

_Type = _make_enum('DynamicValue.Type', 
                    UNKNOWN = capnp.TYPE_UNKNOWN,
                    VOID = capnp.TYPE_VOID,
                    BOOL = capnp.TYPE_BOOL,
                    INT = capnp.TYPE_INT,
                    UINT = capnp.TYPE_UINT,
                    FLOAT = capnp.TYPE_FLOAT,
                    TEXT = capnp.TYPE_TEXT,
                    DATA = capnp.TYPE_DATA,
                    LIST = capnp.TYPE_LIST,
                    ENUM = capnp.TYPE_ENUM,
                    STRUCT = capnp.TYPE_STRUCT,
                    UNION = capnp.TYPE_UNION,
                    INTERFACE = capnp.TYPE_INTERFACE,
                    OBJECT = capnp.TYPE_OBJECT)

cdef extern from "capnp/list.h" namespace "::capnp":
    cdef cppclass List[T]:
        cppclass Reader:
            T operator[](uint) except +ValueError
            uint size()
        cppclass Builder:
            T operator[](uint) except +ValueError
            uint size()

cdef class _DynamicListReader:
    cdef C_DynamicList.Reader thisptr
    cdef init(self, C_DynamicList.Reader other):
        self.thisptr = other
        return self

    cpdef _get(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _DynamicValueReader().init(self.thisptr[index])

    def __getitem__(self, index):
        return self._get(index).toPython()

    def __len__(self):
        return self.thisptr.size()

cdef class _DynamicListBuilder:
    cdef C_DynamicList.Builder thisptr
    cdef init(self, C_DynamicList.Builder other):
        self.thisptr = other
        return self

    #def init(self, size):
    #    self.thisptr.init(size)
    #    return self

    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        temp = self.thisptr[index]
        return toPython(temp)

    def _setitem(self, index, valid_values value):
        cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(value)
        self.thisptr.set(index, temp)

    def __setitem__(self, index, value):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        self._setitem(index, value)

    def __len__(self):
        return self.thisptr.size()

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

    cpdef int getType(self):
        return self.thisptr.getType()

    cpdef toPython(self):
        cdef int type = self.getType()
        if type == capnp.TYPE_BOOL:
            return self.thisptr.asBool()
        elif type == capnp.TYPE_INT:
            return self.thisptr.asInt()
        elif type == capnp.TYPE_UINT:
            return self.thisptr.asUint()
        elif type == capnp.TYPE_FLOAT:
            return self.thisptr.asDouble()
        elif type == capnp.TYPE_TEXT:
            return self.thisptr.asText()[:]
        elif type == capnp.TYPE_DATA:
            temp = self.thisptr.asData()
            return (<char*>temp.begin())[:temp.size()]
        elif type == capnp.TYPE_LIST:
            return list(_DynamicListReader().init(self.thisptr.asList()))
        elif type == capnp.TYPE_STRUCT:
            return _DynamicStructReader().init(self.thisptr.asStruct())
        elif type == capnp.TYPE_UNION:
            return _DynamicUnionReader().init(self.thisptr.asUnion())
        elif type == capnp.TYPE_ENUM:
            return self.thisptr.asEnum().getRaw()
        elif type == capnp.TYPE_VOID:
            return None
        elif type == capnp.TYPE_UNKOWN:
            raise ValueError("Cannot convert type to Python. Type is unknown by capnproto library")
        else:
            raise ValueError("Cannot convert type to Python. Type is unhandled by capnproto library")


cdef int getType(C_DynamicValue.Builder & self):
    return self.getType()

cdef toPython(C_DynamicValue.Builder & self):
    cdef int type = getType(self)
    if type == capnp.TYPE_BOOL:
        return self.asBool()
    elif type == capnp.TYPE_INT:
        return self.asInt()
    elif type == capnp.TYPE_UINT:
        return self.asUint()
    elif type == capnp.TYPE_FLOAT:
        return self.asDouble()
    elif type == capnp.TYPE_TEXT:
        return self.asText()[:]
    elif type == capnp.TYPE_DATA:
        temp = self.asData()
        return (<char*>temp.begin())[:temp.size()]
    elif type == capnp.TYPE_LIST:
        return list(_DynamicListBuilder().init(self.asList()))
    elif type == capnp.TYPE_STRUCT:
        return _DynamicStructBuilder().init(self.asStruct())
    elif type == capnp.TYPE_UNION:
        return _DynamicUnionBuilder().init(self.asUnion())
    elif type == capnp.TYPE_ENUM:
        return self.asEnum().getRaw()
    elif type == capnp.TYPE_VOID:
        return None
    elif type == capnp.TYPE_UNKOWN:
        raise ValueError("Cannot convert type to Python. Type is unknown by capnproto library")
    else:
        raise ValueError("Cannot convert type to Python. Type is unhandled by capnproto library")

cdef class _DynamicStructReader:
    cdef C_DynamicStruct.Reader thisptr
    cdef init(self, C_DynamicStruct.Reader other):
        self.thisptr = other
        return self
        
    cpdef _get(self, field):
        return _DynamicValueReader().init(self.thisptr.get(field))

    def __getattr__(self, field):
        return self._get(field).toPython()

    def _has(self, field):
        return self.thisptr.has(field)

cdef class _DynamicStructBuilder:
    cdef C_DynamicStruct.Builder thisptr
    cdef init(self, C_DynamicStruct.Builder other):
        self.thisptr = other
        return self

    def __getattr__(self, field):
        return toPython(self.thisptr.get(field))

    def _setattr(self, field, valid_values value):
        cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(value)
        self.thisptr.set(field, temp)

    def __setattr__(self, field, value):
        self._setattr(field, value)

    def _has(self, field):
        return self.thisptr.has(field)

cdef class _DynamicUnionReader:
    cdef C_DynamicUnion.Reader thisptr
    cdef init(self, C_DynamicUnion.Reader other):
        self.thisptr = other
        return self
        
    cpdef _get(self):
        return _DynamicValueReader().init(self.thisptr.get()).toPython()

    def __getattr__(self, field):
        return self._get().toPython()

    cpdef which(self):
        return fixMaybe(self.thisptr.which()).getProto().getOrdinal()

cdef class _DynamicUnionBuilder:
    cdef C_DynamicUnion.Builder thisptr
    cdef init(self, C_DynamicUnion.Builder other):
        self.thisptr = other
        return self

    def __getattr__(self, field):
        return toPython(self.thisptr.get())

    def _setattr(self, field, valid_values value):
        cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(value)
        self.thisptr.set(field, temp)

    def __setattr__(self, field, value):
        self._setattr(field, value)

    cpdef which(self):
        return fixMaybe(self.thisptr.which()).getProto().getOrdinal()

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
    cpdef initRootDynamicStruct(self, StructSchema schema):
        return _DynamicStructBuilder().init(self.thisptr.initRootDynamicStruct(schema.thisptr))
    cpdef getRootDynamicStruct(self, StructSchema schema):
        return _DynamicStructBuilder().init(self.thisptr.getRootDynamicStruct(schema.thisptr))

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