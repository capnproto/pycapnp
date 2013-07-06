# capnp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnp

cimport cython
cimport capnp_cpp as capnp
cimport schema_cpp
from capnp_cpp cimport SchemaLoader as C_SchemaLoader, Schema as C_Schema, StructSchema as C_StructSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue, Type as C_Type, DynamicList as C_DynamicList, DynamicUnion as C_DynamicUnion, fixMaybe

from schema_cpp cimport CodeGeneratorRequest as C_CodeGeneratorRequest, Node as C_Node, EnumNode as C_EnumNode
from cython.operator cimport dereference as deref

from schema cimport _NodeReader
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

    def __setattr__(self, field, value):
        value_type = type(value)
        if value_type is int:
            self._setattrInt(field, value)
        elif value_type is float:
            self._setattrDouble(field, value)
        elif value_type is bool:
            self._setattrBool(field, value)
        elif value_type is bytes:
            self._setattrString(field, value)
        else:
            raise ValueError("Non primitive type")

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

cdef class Schema:
    cdef C_Schema thisptr
    cdef init(self, C_Schema other):
        self.thisptr = other
        return self

    cpdef asStruct(self):
        return StructSchema().init(self.thisptr.asStruct())

    cpdef getDependency(self, id):
        return Schema().init(self.thisptr.getDependency(id))

    cpdef getProto(self):
        return _NodeReader().init(self.thisptr.getProto())

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

    cpdef get(self, id):
        return Schema().init(self.thisptr.get(id))

cdef class MessageBuilder:
    cdef schema_cpp.MessageBuilder * thisptr
    def __dealloc__(self):
        del self.thisptr
    cpdef initRoot(self, StructSchema schema):
        return _DynamicStructBuilder().init(self.thisptr.initRootDynamicStruct(schema.thisptr))
    cpdef getRoot(self, StructSchema schema):
        return _DynamicStructBuilder().init(self.thisptr.getRootDynamicStruct(schema.thisptr))

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
    cpdef getRoot(self, StructSchema schema):
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

def capitalize(s):
  if len(s) < 2:
    return s
  return s[0].upper() + s[1:]
def upper_and_under(s):
  if len(s) < 2:
    return s
  ret = [s[0]]
  for letter in s[1:]:
    if letter.isupper():
      ret.append('_')
    ret.append(letter)
  return ''.join(ret).upper()

def make_enum(enum_name, *sequential, **named):
    enums = dict(zip(sequential, range(len(sequential))), **named)
    reverse = dict((value, key) for key, value in enums.iteritems())
    enums['reverse_mapping'] = reverse
    return type(enum_name, (), enums)

from types import ModuleType
import re
import schema
import subprocess

def _load(m, n, loader, name = None, isUnion = False):
    if name is None:
        name = n.displayName
    local_m = m
    for sub_name in re.split('[:.]', name):
        new_m = local_m.__dict__.get(sub_name, ModuleType(sub_name))
        local_m.__dict__[sub_name] = new_m
        local_m = new_m
    for nestedNode in n.nestedNodes:
        s = loader.get(nestedNode.id)
        _load(m, s.getProto(), loader, name + ':' + nestedNode.name)
    body = n.body
    which = body.which()
    if which == schema.Node.Body.Which.enumNode:
        enum = body.enumNode
        local_m.Which = make_enum(name+':Which', **{upper_and_under(e.name) : e.codeOrder for e in enum.enumerants})
    elif which == schema.Node.Body.Which.structNode:
        struct = body.structNode
        for member in struct.members:
            if member.body.which() == schema.StructNode.Member.Body.Which.unionMember:
                sub_name = capitalize(member.name)
                new_m = local_m.__dict__.get(sub_name, ModuleType(sub_name))
                local_m.__dict__[sub_name] = new_m
                new_m.Which = make_enum(sub_name+':Which', **{upper_and_under(e.name) : e.ordinal for e in struct.members})
    return local_m

def load(file_name, cat_path='/bin/cat'):
    p = subprocess.Popen(['capnpc', '-o'+cat_path, file_name], stdout=subprocess.PIPE)
    ret = p.wait()
    if ret != 0:
        raise RuntimeError("capnpc failed for some reason")
    r = schema.StreamFdMessageReader(p.stdout.fileno())
    c = r.getRootCodeGeneratorRequest()
    m = ModuleType(file_name)
    l = SchemaLoader()
    m._loader = l
    for node in c.nodes:
        s = l.load(node)
    for node in c.nodes:
        s = l.load(node)
        local_m = _load(m, node, l)
        try:
            s = s.asStruct()
            local_m.Schema = s
        except: pass

    return m

