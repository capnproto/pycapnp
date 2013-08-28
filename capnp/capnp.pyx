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
from capnp_cpp cimport Schema as C_Schema, StructSchema as C_StructSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue, Type as C_Type, DynamicList as C_DynamicList, fixMaybe, SchemaParser as C_SchemaParser, ParsedSchema as C_ParsedSchema, VOID, ArrayPtr, StringPtr, DynamicOrphan as C_DynamicOrphan

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

# Templated classes are weird in cython. I couldn't put it in a pxd header for some reason
cdef extern from "capnp/list.h" namespace " ::capnp":
    cdef cppclass List[T]:
        cppclass Reader:
            T operator[](uint) except +ValueError
            uint size()
        cppclass Builder:
            T operator[](uint) except +ValueError
            uint size()

cdef extern from "<utility>" namespace "std":
    C_DynamicOrphan moveOrphan"std::move"(C_DynamicOrphan &)

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
    property isStruct:
        def __get__(self):
            return self.thisptr.isStruct()
    property isConst:
        def __get__(self):
            return self.thisptr.isConst()

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

    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return toPythonReader(self.thisptr[index], self._parent)

    def __len__(self):
        return self.thisptr.size()

cdef class _DynamicListBuilder:
    cdef C_DynamicList.Builder thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicList.Builder other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

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

cdef toPythonReader(C_DynamicValue.Reader self, object parent):
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
        return list(_DynamicListReader()._init(self.asList(), parent))
    elif type == capnp.TYPE_STRUCT:
        return _DynamicStructReader()._init(self.asStruct(), parent)
    elif type == capnp.TYPE_ENUM:
        return fixMaybe(self.asEnum().getEnumerant()).getProto().getName().cStr()
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
    cdef object _obj_to_pin
    cdef _init(self, C_DynamicStruct.Reader other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    def __getattr__(self, field):
        return toPythonReader(self.thisptr.get(field), self._parent)

    def _has(self, field):
        return self.thisptr.has(field)

    cpdef which(self):
        return fixMaybe(self.thisptr.which()).getProto().getName().cStr()

    property schema:
        """A _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.fieldnames)

cdef class _DynamicStructBuilder:
    cdef C_DynamicStruct.Builder thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicStruct.Builder other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cdef _get(self, field) except +ValueError:
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

    cpdef which(self):
        return fixMaybe(self.thisptr.which()).getProto().getName().cStr()

    cpdef as_reader(self):
          cdef _DynamicStructReader reader
          reader = _DynamicStructReader()._init(self.thisptr.asReader(),
                                                self._parent)
          reader._obj_to_pin = self
          return reader

    property schema:
        """A _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.fieldnames)

cdef class _DynamicOrphan:
    cdef C_DynamicOrphan thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicOrphan other, object parent):
        self.thisptr = moveOrphan(other)
        self._parent = parent
        return self

cdef class _Schema:
    cdef C_Schema thisptr
    cdef _init(self, C_Schema other):
        self.thisptr = other
        return self

    cpdef asConstValue(self):
        return toPythonReader(<C_DynamicValue.Reader>self.thisptr.asConst(), self)

    cpdef asStruct(self):
        return _StructSchema()._init(self.thisptr.asStruct())

    cpdef getDependency(self, id):
        return _Schema()._init(self.thisptr.getDependency(id))

    cpdef getProto(self):
        return _NodeReader().init(self.thisptr.getProto())

cdef class _StructSchema:
    cdef C_StructSchema thisptr
    cdef object __fieldnames
    cdef _init(self, C_StructSchema other):
        self.thisptr = other
        self.__fieldnames = None
        return self

    property fieldnames:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__fieldnames is not None:
               return self.__fieldnames
            fieldlist = self.thisptr.getFields()
            nfields = fieldlist.size()
            self.__fieldnames = tuple(fieldlist[i].getProto().getName().cStr()
                                      for i in xrange(nfields))
            return self.__fieldnames

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), None)

cdef class _ParsedSchema:
    cdef C_ParsedSchema thisptr
    cdef _init(self, C_ParsedSchema other):
        self.thisptr = other
        return self

    cpdef asConstValue(self):
        return toPythonReader(<C_DynamicValue.Reader>self.thisptr.asConst(), self)

    cpdef asStruct(self):
        return _StructSchema()._init(self.thisptr.asStruct())

    cpdef getDependency(self, id):
        return _Schema()._init(self.thisptr.getDependency(id))

    cpdef getProto(self):
        return _NodeReader().init(self.thisptr.getProto())

    cpdef getNested(self, name):
        return _ParsedSchema()._init(self.thisptr.getNested(name))

cdef class _SchemaParser:
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

        ret = _ParsedSchema()
        ret._init(self.thisptr.parseDiskFile(displayName, diskPath, importsPtr))

        free(importArray)

        return ret

cdef class MessageBuilder:
    """An abstract base class for building Cap'n Proto messages

    .. warning:: Don't ever instantiate this class directly. It is only used for inheritance.
    """
    cdef schema_cpp.MessageBuilder * thisptr
    def __dealloc__(self):
        del self.thisptr

    def __init__(self):
        raise NotImplementedError("This is an abstract base class. You should use MallocMessageBuilder instead")

    cpdef initRoot(self, schema):
        """A method for instantiating Cap'n Proto structs

        You will need to pass in a schema to specify which struct to
        instantiate. Schemas are available in a loaded Cap'n Proto module::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.initRoot(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructBuilder`
        :return: An object where you will set all the members
        """
        cdef _StructSchema s
        if hasattr(schema, 'Schema'):
            s = schema.Schema
        else:
            s = schema
        return _DynamicStructBuilder()._init(self.thisptr.initRootDynamicStruct(s.thisptr), self)

    cpdef getRoot(self, schema):
        """A method for instantiating Cap'n Proto structs, from an already pre-written buffers

        Don't use this method unless you know what you're doing. You probably
        want to use initRoot instead::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.initRoot(addressbook.Person)
            ...
            person = message.getRoot(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructBuilder`
        :return: An object where you will set all the members
        """
        cdef _StructSchema s
        if hasattr(schema, 'Schema'):
            s = schema.Schema
        else:
            s = schema
        return _DynamicStructBuilder()._init(self.thisptr.getRootDynamicStruct(s.thisptr), self)

cdef class MallocMessageBuilder(MessageBuilder):
    """The main class for building Cap'n Proto messages

    You will use this class to handle arena allocation of the Cap'n Proto
    messages. You also use this object when you're done assigning to Cap'n
    Proto objects, and wish to serialize them::

        addressbook = capnp.load('addressbook.capnp')
        message = capnp.MallocMessageBuilder()
        person = message.initRoot(addressbook.Person)
        person.name = 'alice'
        ...
        writeMessageToFd(open('out.txt', 'w').fileno(), message)
    """
    def __cinit__(self):
        self.thisptr = new schema_cpp.MallocMessageBuilder()

    def __init__(self):
        pass

cdef class _MessageReader:
    """An abstract base class for reading Cap'n Proto messages

    .. warning:: Don't ever instantiate this class. It is only used for inheritance.
    """
    cdef schema_cpp.MessageReader * thisptr
    def __dealloc__(self):
        del self.thisptr
    def __init__(self):
        raise NotImplementedError("This is an abstract base class")

    cpdef _getRootNode(self):
        return _NodeReader().init(self.thisptr.getRootNode())

    cpdef getRoot(self, schema):
        """A method for instantiating Cap'n Proto structs

        You will need to pass in a schema to specify which struct to
        instantiate. Schemas are available in a loaded Cap'n Proto module::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.getRoot(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructReader`
        :return: An object with all the data of the read Cap'n Proto message.
            Access members with . syntax.
        """
        cdef _StructSchema s
        if hasattr(schema, 'Schema'):
            s = schema.Schema
        else:
            s = schema
        return _DynamicStructReader()._init(self.thisptr.getRootDynamicStruct(s.thisptr), self)

cdef class StreamFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor

    You use this class to for reading message(s) from a file. It's analagous to the inverse of writeMessageToFd and :class:`MessageBuilder`, but in one class.::

        message = StreamFdMessageReader(open('out.txt').fileno())
        person = message.getRoot(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, int fd):
        self.thisptr = new schema_cpp.StreamFdMessageReader(fd)

cdef class PackedFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of writePackedMessageToFd and :class:`MessageBuilder`, but in one class.::

        message = StreamFdMessageReader(open('out.txt').fileno())
        person = message.getRoot(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, int fd):
        self.thisptr = new schema_cpp.PackedFdMessageReader(fd)

def writeMessageToFd(int fd, MessageBuilder message):
    """Serialize a Cap'n Proto message to a file descriptor

    You use this method to serialize your message to a file. Please note that
    you must pass a file descriptor (ie. an int), not a file object. Make sure
    you use the proper reader to match this (ie. don't use PackedFdMessageReader)::

        message = capnp.MallocMessageBuilder()
        ...
        writeMessageToFd(open('out.txt', 'w').fileno(), message)
        ...
        StreamFdMessageReader(open('out.txt').fileno())

    :type fd: int
    :param fd: A file descriptor

    :type message: :class:`MessageBuilder`
    :param message: The Cap'n Proto message to serialize

    :rtype: void
    """
    schema_cpp.writeMessageToFd(fd, deref(message.thisptr))

def writePackedMessageToFd(int fd, MessageBuilder message):
    """Serialize a Cap'n Proto message to a file descriptor in a packed manner

    You use this method to serialize your message to a file. Please note that
    you must pass a file descriptor (ie. an int), not a file object. Also, note
    the difference in names with writeMessageToFd. This method uses a different
    serialization specification, and your reader will need to match.::

        message = capnp.MallocMessageBuilder()
        ...
        writePackedMessageToFd(open('out.txt', 'w').fileno(), message)
        ...
        PackedFdMessageReader(open('out.txt').fileno())

    :type fd: int
    :param fd: A file descriptor

    :type message: :class:`MessageBuilder`
    :param message: The Cap'n Proto message to serialize

    :rtype: void
    """
    schema_cpp.writePackedMessageToFd(fd, deref(message.thisptr))

from types import ModuleType as _ModuleType
import os as _os

def load(file_name, display_name=None, imports=[]):
    """Load a Cap'n Proto schema from a file 

    You will have to load a schema before you can begin doing anything
    meaningful with this library. Loading a schema is much like Loading
    a Python module (and load even returns a `ModuleType`). Once it's been
    loaded, you use it much like any other Module::

        addressbook = capnp.load('addressbook.capnp')
        print addressbook.qux # qux is a top level constant
        # 123
        message = capnp.MallocMessageBuilder()
        person = message.initRoot(addressbook.Person)

    :type file_name: str
    :param file_name: A relative or absolute path to a Cap'n Proto schema

    :type display_name: str
    :param display_name: The name internally used by the Cap'n Proto library
        for the loaded schema. By default, it's just os.path.basename(file_name)

    :type imports: list
    :param imports: A list of str directories to add to the import path.

    :rtype: ModuleType
    :return: A module corresponding to the loaded schema. You can access
        parsed schemas and constants with . syntax

    :Raises: :exc:`exceptions.ValueError` if `file_name` doesn't exist

    """
    def _load(nodeSchema, module):
        module._nodeSchema = nodeSchema
        nodeProto = nodeSchema.getProto()
        module._nodeProto = nodeProto

        for node in nodeProto.nestedNodes:
            local_module = _ModuleType(node.name)
            module.__dict__[node.name] = local_module

            schema = nodeSchema.getNested(node.name)
            proto = schema.getProto()
            if proto.isStruct:
                local_module.Schema = schema.asStruct()
            elif proto.isConst:
                module.__dict__[node.name] = schema.asConstValue()

            _load(schema, local_module)

    if display_name is None:
        display_name = _os.path.basename(file_name)
    module = _ModuleType(display_name)
    parser = _SchemaParser()

    module._parser = parser

    fileSchema = parser.parseDiskFile(display_name, file_name, imports)
    _load(fileSchema, module)

    return module
