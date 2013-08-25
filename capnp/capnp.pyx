# capnp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11 -fpermissive
# distutils: libraries = capnpc
# cython: c_string_type = str
# cython: c_string_encoding = default
# cython: embedsignature = True

cimport cython
cimport capnp_cpp as capnp
cimport schema_cpp
from capnp_cpp cimport SchemaLoader as C_SchemaLoader, Schema as C_Schema, StructSchema as C_StructSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue, Type as C_Type, DynamicList as C_DynamicList, fixMaybe, SchemaParser as C_SchemaParser, ParsedSchema as C_ParsedSchema, VOID, ArrayPtr, StringPtr

from schema_cpp cimport Node as C_Node, EnumNode as C_EnumNode
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
from libc.stdlib cimport malloc, free

ctypedef fused valid_values:
    int
    long
    float
    double
    bint
    cython.p_char

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
                    INTERFACE = capnp.TYPE_INTERFACE,
                    OBJECT = capnp.TYPE_OBJECT)

cdef extern from "capnp/list.h" namespace " ::capnp":
    cdef cppclass List[T]:
        cppclass Reader:
            T operator[](uint) except +ValueError
            uint size()
        cppclass Builder:
            T operator[](uint) except +ValueError
            uint size()

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
    property nestedNodes:
        def __get__(self):
            return _List_NestedNode_Reader()._init(self.thisptr.getNestedNodes())

cdef class _NestedNodeReader:
    cdef C_Node.NestedNode.Reader thisptr
    cdef init(self, C_Node.NestedNode.Reader other):
        self.thisptr = other
        return self

    property name:
        def __get__(self):
            return self.thisptr.getName().cStr()
    property id:
        def __get__(self):
            return self.thisptr.getId()

cdef class _DynamicListReader:
    cdef C_DynamicList.Reader thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicList.Reader other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cpdef _get(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _DynamicValueReader()._init(self.thisptr[index], self._parent)

    def __getitem__(self, index):
        return self._get(index).toPython()

    def __len__(self):
        return self.thisptr.size()

cdef class _DynamicListBuilder:
    cdef C_DynamicList.Builder thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicList.Builder other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    #def _init(self, size):
    #    self.thisptr._init(size)
    #    return self

    cpdef _get(self, index) except +ValueError:
        return toPython(self.thisptr[index], self._parent)

    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return self._get(index)

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
    cdef _init(self, List[UInt64].Reader other):
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
    cdef _init(self, List[C_Node].Reader other):
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

cdef class _List_NestedNode_Reader:
    cdef List[C_Node.NestedNode].Reader thisptr
    cdef _init(self, List[C_Node.NestedNode].Reader other):
        self.thisptr = other
        return self

    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _NestedNodeReader().init(<C_Node.NestedNode.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()

cdef class _DynamicValueReader:
    cdef C_DynamicValue.Reader thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicValue.Reader other, object parent):
        self.thisptr = other
        self._parent = parent
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
            return list(_DynamicListReader()._init(self.thisptr.asList(), self._parent))
        elif type == capnp.TYPE_STRUCT:
            return _DynamicStructReader()._init(self.thisptr.asStruct(), self._parent)
        elif type == capnp.TYPE_ENUM:
            return fixMaybe(self.thisptr.asEnum().getEnumerant()).getProto().getName().cStr()
        elif type == capnp.TYPE_VOID:
            return None
        elif type == capnp.TYPE_UNKOWN:
            raise ValueError("Cannot convert type to Python. Type is unknown by capnproto library")
        else:
            raise ValueError("Cannot convert type to Python. Type is unhandled by capnproto library")

cdef toPython(C_DynamicValue.Builder self, object parent):
    cdef int type = self.getType()
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
        return list(_DynamicListBuilder()._init(self.asList(), parent))
    elif type == capnp.TYPE_STRUCT:
        return _DynamicStructBuilder()._init(self.asStruct(), parent)
    elif type == capnp.TYPE_ENUM:
        return fixMaybe(self.asEnum().getEnumerant()).getProto().getName().cStr()
    elif type == capnp.TYPE_VOID:
        return None
    elif type == capnp.TYPE_UNKOWN:
        raise ValueError("Cannot convert type to Python. Type is unknown by capnproto library")
    else:
        raise ValueError("Cannot convert type to Python. Type is unhandled by capnproto library")

cdef class _DynamicStructReader:
    cdef C_DynamicStruct.Reader thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicStruct.Reader other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cpdef _get(self, field):
        return _DynamicValueReader()._init(self.thisptr.get(field), self._parent)

    def __getattr__(self, field):
        return self._get(field).toPython()

    def _has(self, field):
        return self.thisptr.has(field)

    cpdef which(self):
        return fixMaybe(self.thisptr.which()).getProto().getName().cStr()

cdef class _DynamicStructBuilder:
    cdef C_DynamicStruct.Builder thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicStruct.Builder other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cpdef _get(self, field) except +ValueError:
        return toPython(self.thisptr.get(field), self._parent)

    def __getattr__(self, field):
        return self._get(field)

    cdef _setattrInt(self, field, value):
        cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(<long long>value)
        self.thisptr.set(field, temp)

    cdef _setattrDouble(self, field, value):
        cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(<double>value)
        self.thisptr.set(field, temp)

    cdef _setattrBool(self, field, value):
        cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(<bint>value)
        self.thisptr.set(field, temp)

    cdef _setattrString(self, field, value):
        cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(<char*>value)
        self.thisptr.set(field, temp)

    cdef _setattrVoid(self, field):
        cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(VOID)
        self.thisptr.set(field, temp)

    def __setattr__(self, field, value):
        value_type = type(value)
        if value_type is int:
            self._setattrInt(field, value)
        elif value_type is float:
            self._setattrDouble(field, value)
        elif value_type is bool:
            self._setattrBool(field, value)
        elif value_type is str:
            self._setattrString(field, value)
        elif value is None:
            self._setattrVoid(field)
        else:
            raise ValueError("Non primitive type")

    def _has(self, field):
        return self.thisptr.has(field)

    cpdef init(self, field, size=None) except +ValueError:
        if size is None:
            return toPython(self.thisptr.init(field), self._parent)
        else:
            return toPython(self.thisptr.init(field, size), self._parent)

    # cpdef which(self):
    #     try:
    #         union = fixMaybeUnion(self.thisptr.getSchema().getUnnamedUnion())
    #     except:
    #         raise TypeError("This struct has no unnamed enums. You cannot call which on it")

    #     return getWhichBuilder(self.thisptr.getByUnion(union))

cdef class Schema:
    cdef C_Schema thisptr
    cdef _init(self, C_Schema other):
        self.thisptr = other
        return self

    cpdef asStruct(self):
        return StructSchema()._init(self.thisptr.asStruct())

    cpdef getDependency(self, id):
        return Schema()._init(self.thisptr.getDependency(id))

    cpdef getProto(self):
        return _NodeReader().init(self.thisptr.getProto())

cdef class StructSchema:
    cdef C_StructSchema thisptr
    cdef _init(self, C_StructSchema other):
        self.thisptr = other
        return self

cdef class ParsedSchema:
    cdef C_ParsedSchema thisptr
    cdef _init(self, C_ParsedSchema other):
        self.thisptr = other
        return self

    cpdef asStruct(self):
        return StructSchema()._init(self.thisptr.asStruct())

    cpdef getDependency(self, id):
        return Schema()._init(self.thisptr.getDependency(id))

    cpdef getProto(self):
        return _NodeReader().init(self.thisptr.getProto())

    cpdef getNested(self, name):
        return ParsedSchema()._init(self.thisptr.getNested(name))

cdef class SchemaLoader:
    cdef C_SchemaLoader * thisptr
    def __cinit__(self):
        self.thisptr = new C_SchemaLoader()

    def __dealloc__(self):
        del self.thisptr

    cpdef load(self, _NodeReader node):
        return Schema()._init(self.thisptr.load(node.thisptr))

    cpdef get(self, id):
        return Schema()._init(self.thisptr.get(id))

cdef class SchemaParser:
    cdef C_SchemaParser * thisptr
    def __cinit__(self):
        self.thisptr = new C_SchemaParser()

    def __dealloc__(self):
        del self.thisptr

    def parseDiskFile(self, displayName, diskPath, imports):
        cdef StringPtr * importArray = <StringPtr *>malloc(sizeof(StringPtr) * len(imports))

        for i in range(len(imports)):
            importArray[i] = StringPtr(imports[i])

        cdef ArrayPtr[StringPtr] importsPtr = ArrayPtr[StringPtr](importArray, <size_t>len(imports))

        ret = ParsedSchema()
        ret._init(self.thisptr.parseDiskFile(displayName, diskPath, importsPtr))

        free(importArray)

        return ret

cdef class MessageBuilder:
    cdef schema_cpp.MessageBuilder * thisptr
    def __dealloc__(self):
        del self.thisptr
    def __init__(self):
        raise NotImplementedError("This is an abstract base class. You should use MallocMessageBuilder instead")

    cpdef initRoot(self, schema):
        cdef StructSchema s
        if hasattr(schema, 'Schema'):
            s = schema.Schema
        else:
            s = schema
        return _DynamicStructBuilder()._init(self.thisptr.initRootDynamicStruct(s.thisptr), self)
    cpdef getRoot(self, schema):
        cdef StructSchema s
        if hasattr(schema, 'Schema'):
            s = schema.Schema
        else:
            s = schema
        return _DynamicStructBuilder()._init(self.thisptr.getRootDynamicStruct(s.thisptr), self)

cdef class MallocMessageBuilder(MessageBuilder):
    def __cinit__(self):
        self.thisptr = new schema_cpp.MallocMessageBuilder()
    def __init__(self):
        pass

cdef class MessageReader:
    cdef schema_cpp.MessageReader * thisptr
    def __dealloc__(self):
        del self.thisptr
    def __init__(self):
        raise NotImplementedError("This is an abstract base class")

    cpdef _getRootNode(self):
        return _NodeReader().init(self.thisptr.getRootNode())
    cpdef getRoot(self, schema):
        cdef StructSchema s
        if hasattr(schema, 'Schema'):
            s = schema.Schema
        else:
            s = schema
        return _DynamicStructReader()._init(self.thisptr.getRootDynamicStruct(s.thisptr), self)

cdef class StreamFdMessageReader(MessageReader):
    def __init__(self, int fd):
        self.thisptr = new schema_cpp.StreamFdMessageReader(fd)

cdef class PackedFdMessageReader(MessageReader):
    def __init__(self, int fd):
        self.thisptr = new schema_cpp.PackedFdMessageReader(fd)

def writeMessageToFd(int fd, MessageBuilder m):
    schema_cpp.writeMessageToFd(fd, deref(m.thisptr))

def writePackedMessageToFd(int fd, MessageBuilder m):
    schema_cpp.writePackedMessageToFd(fd, deref(m.thisptr))

from types import ModuleType
import os

def _load(nodeSchema, module):
    module._nodeSchema = nodeSchema
    nodeProto = nodeSchema.getProto()
    module._nodeProto = nodeProto

    for node in nodeProto.nestedNodes:
        local_module = ModuleType(node.name)
        module.__dict__[node.name] = local_module

        schema = nodeSchema.getNested(node.name)
        try:
            local_module.Schema = schema.asStruct()
        except:
            pass

        _load(schema, local_module)

def load(file_name, display_name=None, imports=[]):
    if display_name is None:
        display_name = os.path.basename(file_name)
    module = ModuleType(display_name)
    parser = SchemaParser()

    module._parser = parser

    fileSchema = parser.parseDiskFile(display_name, file_name, imports)
    _load(fileSchema, module)

    return module
