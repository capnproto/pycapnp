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
from capnp_cpp cimport Schema as C_Schema, StructSchema as C_StructSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue, Type as C_Type, DynamicList as C_DynamicList, fixMaybe, getEnumString, SchemaParser as C_SchemaParser, ParsedSchema as C_ParsedSchema, VOID, ArrayPtr, StringPtr, String, StringTree, DynamicOrphan as C_DynamicOrphan, WordArrayPtr

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
from libcpp cimport bool as cbool

ctypedef fused _DynamicStructReaderOrBuilder:
    _DynamicStructReader
    _DynamicStructBuilder

ctypedef fused _DynamicSetterClasses:
    C_DynamicList.Builder
    C_DynamicStruct.Builder

cdef extern from "Python.h":
    cdef int PyObject_AsReadBuffer(object, void** b, Py_ssize_t* c)

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
    C_DynamicOrphan moveOrphan"std::move"(C_DynamicOrphan)

cdef extern from "<capnp/pretty-print.h>" namespace " ::capnp":
    StringTree printStructReader" ::capnp::prettyPrint"(C_DynamicStruct.Reader)
    StringTree printStructBuilder" ::capnp::prettyPrint"(C_DynamicStruct.Builder)
    StringTree printListReader" ::capnp::prettyPrint"(C_DynamicList.Reader)
    StringTree printListBuilder" ::capnp::prettyPrint"(C_DynamicList.Builder)

cdef extern from "<kj/string.h>" namespace " ::kj":
    String strStructReader" ::kj::str"(C_DynamicStruct.Reader)
    String strStructBuilder" ::kj::str"(C_DynamicStruct.Builder)
    String strListReader" ::kj::str"(C_DynamicList.Reader)
    String strListBuilder" ::kj::str"(C_DynamicList.Builder)

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
    """Class for reading Cap'n Proto Lists

    This class thinly wraps the C++ Cap'n Proto DynamicList::Reader class. __getitem__ and __len__ have been defined properly, so you can treat this class mostly like any other iterable class::

        ...
        person = addressbook.Person.read(file)

        phones = person.phones # This returns a _DynamicListReader

        phone = phones[0]
        print phone.number

        for phone in phones:
            print phone.number
    """
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
        return to_python_reader(self.thisptr[index], self._parent)

    def __len__(self):
        return self.thisptr.size()

    def __str__(self):
        return printListReader(self.thisptr).flatten().cStr()

    def __repr__(self):
        # TODO:  Print the list type.
        return '<capnp list reader %s>' % strListReader(self.thisptr).cStr()

cdef class _DynamicResizableListBuilder:
    """Class for building growable Cap'n Proto Lists

    .. warning:: You need to call :meth:`finish` on this object before serializing the Cap'n Proto message. Failure to do so will cause your objects not to be written out as well as leaking orphan structs into your message.

    This class works much like :class:`_DynamicListBuilder`, but it allows growing the list dynamically. It is meant for lists of structs, since for primitive types like int or float, you're much better off using a normal python list and then serializing straight to a Cap'n Proto list. It has __getitem__ and __len__ defined, but not __setitem__::

        ...
        person = addressbook.Person.new_message()

        phones = person.init_resizable_list('phones') # This returns a _DynamicResizableListBuilder
        
        phone = phones.add()
        phone.number = 'foo'
        phone = phones.add()
        phone.number = 'bar'

        people.finish()

        f = open('example', 'w')
        person.write(f)
    """
    cdef public object _parent, _message, _field, _schema
    cdef public list _list
    def __init__(self, parent, field, schema):
        self._parent = parent
        self._message = parent._parent
        self._field = field
        self._schema = schema

        self._list = list()

    cpdef add(self):
        """A method for adding a new struct to the list

        This will return a struct, in which you can set fields that will be reflected in the serialized Cap'n Proto message.

        :rtype: :class:`_DynamicStructBuilder`
        """
        orphan = self._message.new_orphan(self._schema)
        orphan_val = orphan.get()
        self._list.append((orphan, orphan_val))
        return orphan_val
        
    def __getitem__(self, index):
        return self._list[index][1]

    # def __setitem__(self, index, val):
    #     self._list[index] = val

    def __len__(self):
        return len(self._list)

    def finish(self):
        """A method for closing this list and serializing all its members to the message

        If you don't call this method, the items you previously added from this object will leak into the message, ie. inaccessible but still taking up space.
        """
        cdef int i = 0
        new_list = self._parent.init(self._field, len(self))
        for orphan, _ in self._list:
            new_list.adopt(i, orphan)
            i += 1

cdef class _DynamicListBuilder:
    """Class for building Cap'n Proto Lists

    This class thinly wraps the C++ Cap'n Proto DynamicList::Bulder class. __getitem__, __setitem__, and __len__ have been defined properly, so you can treat this class mostly like any other iterable class::

        ...
        person = addressbook.Person.new_message()

        phones = person.init('phones', 2) # This returns a _DynamicListBuilder
        
        phone = phones[0]
        phone.number = 'foo'
        phone = phones[1]
        phone.number = 'bar'

        for phone in phones:
            print phone.number
    """
    cdef C_DynamicList.Builder thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicList.Builder other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cdef _get(self, index):
        return to_python_builder(self.thisptr[index], self._parent)

    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return self._get(index)

    def __setitem__(self, index, value):
        # TODO: share code with _DynamicStructBuilder.__setattr__
        
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        _setDynamicField(self.thisptr, index, value, self._parent)

    def __len__(self):
        return self.thisptr.size()

    cpdef adopt(self, index, _DynamicOrphan orphan):
        """A method for adopting Cap'n Proto orphans

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unkown sized list.

        :type index: int
        :param index: The index of the element in the list to replace with the newly adopted object

        :type orphan: :class:`_DynamicOrphan`
        :param orphan: A Cap'n proto orphan to adopt. It will be unusable after this operation.

        :rtype: void
        """
        self.thisptr.adopt(index, orphan.move())

    cpdef disown(self, index):
        """A method for disowning Cap'n Proto orphans

        Don't use this method unless you know what you're doing.

        :type index: int
        :param index: The index of the element in the list to disown

        :rtype: :class:`_DynamicOrphan`
        """
        return _DynamicOrphan()._init(self.thisptr.disown(index), self._parent)

    def __str__(self):
        return printListBuilder(self.thisptr).flatten().cStr()

    def __repr__(self):
        # TODO:  Print the list type.
        return '<capnp list builder %s>' % strListBuilder(self.thisptr).cStr()

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

cdef to_python_reader(C_DynamicValue.Reader self, object parent):
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
        return _DynamicListReader()._init(self.asList(), parent)
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

cdef to_python_builder(C_DynamicValue.Builder self, object parent):
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
        return _DynamicListBuilder()._init(self.asList(), parent)
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

cdef C_DynamicValue.Reader _extract_dynamic_struct_builder(_DynamicStructBuilder value):
    return C_DynamicValue.Reader(value.thisptr.asReader())

cdef C_DynamicValue.Reader _extract_dynamic_struct_reader(_DynamicStructReader value):
    return C_DynamicValue.Reader(value.thisptr)

cdef _setDynamicField(_DynamicSetterClasses thisptr, field, value, parent):
    cdef C_DynamicValue.Reader temp
    value_type = type(value)

    if value_type is int or value_type is long:
        if value < 0:
           temp = C_DynamicValue.Reader(<long long>value)
        else:
           temp = C_DynamicValue.Reader(<unsigned long long>value)
        thisptr.set(field, temp)
    elif value_type is float:
        temp = C_DynamicValue.Reader(<double>value)
        thisptr.set(field, temp)
    elif value_type is bool:
        temp = C_DynamicValue.Reader(<cbool>value)
        thisptr.set(field, temp)
    elif value_type is str:
        temp = C_DynamicValue.Reader(<char*>value)
        thisptr.set(field, temp)
    elif value_type is list:
        builder = to_python_builder(thisptr.init(field, len(value)), parent)
        for (i, v) in enumerate(value):
            builder[i] = v
    elif value is None:
        temp = C_DynamicValue.Reader(VOID)
        thisptr.set(field, temp)
    elif value_type is _DynamicStructBuilder:
        thisptr.set(field, _extract_dynamic_struct_builder(value))
    elif value_type is _DynamicStructReader:
        thisptr.set(field, _extract_dynamic_struct_reader(value))
    else:
        raise ValueError("Non primitive type")

cdef _to_dict(msg):
    msg_type = type(msg)
    if msg_type is _DynamicListBuilder or msg_type is _DynamicListReader or msg_type is _DynamicResizableListBuilder:
        return [_to_dict(x) for x in msg]

    if msg_type is _DynamicStructBuilder or msg_type is _DynamicStructReader:
        ret = {}
        try:
            which = msg.which()
            ret['which'] = which
            ret[which] = getattr(msg, which)
        except ValueError:
            pass

        for field in msg.schema.non_union_fields:
            ret[field] = _to_dict(getattr(msg, field))

        return ret

    return msg

import collections as _collections
cdef _from_dict_helper(msg, field, d):
    if isinstance(d, dict):
        sub_msg = getattr(msg, field)
        for key, val in d.iteritems():
            if key != 'which':
                _from_dict_helper(sub_msg, key, val)
    elif isinstance(d, _collections.Iterable) and not isinstance(d, basestring):
        l = msg.init(field, len(d))
        for i in range(len(d)):
            if isinstance(d[i], dict):
                for key, val in d[i].iteritems():
                    if key != 'which':
                        _from_dict_helper(l[i], key, val)
            else:
                l[i] = d[i]
    else:
        setattr(msg, field, d)

cdef _from_dict(msg, d):
    for key, val in d.iteritems():
        if key != 'which':
            _from_dict_helper(msg, key, val)


cdef class _DynamicStructReader:
    """Reads Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Reader. The only difference is that instead of a `get` method, __getattr__ is overloaded and the field name is passed onto the C++ equivalent `get`. This means you just use . syntax to access any field. For field names that don't follow valid python naming convention for fields, use the global function :py:func:`getattr`::

        person = addressbook.Person.read(file) # This returns a _DynamicStructReader
        print person.name # using . syntax
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """
    cdef C_DynamicStruct.Reader thisptr
    cdef public object _parent
    cdef object _obj_to_pin
    cdef _init(self, C_DynamicStruct.Reader other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    def __getattr__(self, field):
        return to_python_reader(self.thisptr.get(field), self._parent)

    def _has(self, field):
        return self.thisptr.has(field)

    cpdef which(self):
        """Returns the enum corresponding to the union in this struct

        Enums are just strings in the python Cap'n Proto API, so this function will either return a string equal to the field name of the active field in the union, or throw a ValueError if this isn't a union, or a struct with an unnamed union::

            person = addressbook.Person.new_message()
            
            person.which()
            # ValueError: member was null

            a.employment.employer = 'foo'
            print employment.which()
            # 'employer'

        :rtype: str
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`exceptions.ValueError` if this struct doesn't contain a union
        """
        cdef object which = getEnumString(self.thisptr)
        if len(which) == 0:
            raise ValueError("Attempted to call which on a non-union type")

        return which

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.fieldnames)

    def __str__(self):
        return printStructReader(self.thisptr).flatten().cStr()

    def __repr__(self):
        return '<%s reader %s>' % (self.schema.node.displayName, strStructReader(self.thisptr).cStr())

    def to_dict(self):
        return _to_dict(self)

cdef class _DynamicStructBuilder:
    """Builds Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Builder. The only difference is that instead of a `get`/`set` method, __getattr__/__setattr__ is overloaded and the field name is passed onto the C++ equivalent function. This means you just use . syntax to access or set any field. For field names that don't follow valid python naming convention for fields, use the global functions :py:func:`getattr`/:py:func:`setattr`::

        person = addressbook.Person.new_message() # This returns a _DynamicStructBuilder
        
        person.name = 'foo' # using . syntax
        print person.name # using . syntax

        setattr(person, 'field-with-hyphens', 'foo') # for names that are invalid for python, use setattr
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """
    cdef C_DynamicStruct.Builder thisptr
    cdef public object _parent
    cdef bint _isRoot
    cdef _init(self, C_DynamicStruct.Builder other, object parent, bint isRoot = False):
        self.thisptr = other
        self._parent = parent
        self._isRoot = isRoot
        return self
    
    def write(self, file):
        """Writes the struct's containing message to the given file object in unpacked binary format.
        
        This is a shortcut for calling capnp._write_message_to_fd().  This can only be called on the
        message's root struct.
        
        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.
        
        :rtype: void
        
        :Raises: :exc:`exceptions.ValueError` if this isn't the message's root struct.
        """
        if not self._isRoot:
            raise ValueError("You can only call write() on the message's root struct.")
        _write_message_to_fd(file.fileno(), self._parent)

    def write_packed(self, file):
        """Writes the struct's containing message to the given file object in packed binary format.
        
        This is a shortcut for calling capnp._write_packed_message_to_fd().  This can only be called on
        the message's root struct.
        
        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.
        
        :rtype: void
        
        :Raises: :exc:`exceptions.ValueError` if this isn't the message's root struct.
        """
        if not self._isRoot:
            raise ValueError("You can only call write() on the message's root struct.")
        _write_packed_message_to_fd(file.fileno(), self._parent)

    def to_bytes(_DynamicStructBuilder self):
        """Returns the struct's containing message as a Python bytes object in the unpacked binary format.

        This is inefficient; it makes several copies.

        :rtype: bytes

        :Raises: :exc:`exceptions.ValueError` if this isn't the message's root struct.
        """
        if not self._isRoot:
            raise ValueError("You can only call write() on the message's root struct.")
        cdef _MessageBuilder builder = self._parent
        array = schema_cpp.messageToFlatArray(deref(builder.thisptr))
        cdef const char* ptr = <const char *>array.begin()
        cdef bytes ret = ptr[:8*array.size()]
        return ret

    cdef _get(self, field):
        return to_python_builder(self.thisptr.get(field), self._parent)

    def __getattr__(self, field):
        return self._get(field)

    def __setattr__(self, field, value):
        _setDynamicField(self.thisptr, field, value, self._parent)

    def _has(self, field):
        return self.thisptr.has(field)

    cpdef init(self, field, size=None):
        """Method for initializing fields that are of type union/struct/list

        Typically, you don't have to worry about initializing structs/unions, so this method is mainly for lists. 

        :type field: str
        :param field: The field name to initialize

        :type size: int
        :param size: The size of the list to initiialize. This should be None for struct/union initialization.

        :rtype: :class:`_DynamicStructBuilder` or :class:`_DynamicListBuilder`

        :Raises: :exc:`exceptions.ValueError` if the field isn't in this struct
        """
        if size is None:
            return to_python_builder(self.thisptr.init(field), self._parent)
        else:
            return to_python_builder(self.thisptr.init(field, size), self._parent)

    cpdef init_resizable_list(self, field):
        """Method for initializing fields that are of type list (of structs)

        This version of init returns a :class:`_DynamicResizableListBuilder` that allows you to add members one at a time (ie. if you don't know the size for sure). This is only meant for lists of Cap'n Proto objects, since for primitive types you can just define a normal python list and fill it yourself. 

        .. warning:: You need to call :meth:`_DynamicResizableListBuilder.finish` on the list object before serializing the Cap'n Proto message. Failure to do so will cause your objects not to be written out as well as leaking orphan structs into your message.

        :type field: str
        :param field: The field name to initialize

        :rtype: :class:`_DynamicResizableListBuilder`

        :Raises: :exc:`exceptions.ValueError` if the field isn't in this struct
        """
        return _DynamicResizableListBuilder(self, field, _StructSchema()._init((<C_DynamicValue.Builder>self.thisptr.get(field)).asList().getStructElementType()))

    cpdef which(self):
        """Returns the enum corresponding to the union in this struct

        Enums are just strings in the python Cap'n Proto API, so this function will either return a string equal to the field name of the active field in the union, or throw a ValueError if this isn't a union, or a struct with an unnamed union::

            person = addressbook.Person.new_message()
            
            person.which()
            # ValueError: member was null

            a.employment.employer = 'foo'
            print employment.which()
            # 'employer'
            
        :rtype: str
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`exceptions.ValueError` if this struct doesn't contain a union
        """
        cdef object which = getEnumString(self.thisptr)
        if len(which) == 0:
            raise ValueError("Attempted to call which on a non-union type")

        return which

    cpdef adopt(self, field, _DynamicOrphan orphan):
        """A method for adopting Cap'n Proto orphans

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unkown sized list.

        :type field: str
        :param field: The field name in the struct

        :type orphan: :class:`_DynamicOrphan`
        :param orphan: A Cap'n proto orphan to adopt. It will be unusable after this operation.

        :rtype: void
        """
        self.thisptr.adopt(field, orphan.move())

    cpdef disown(self, field):
        """A method for disowning Cap'n Proto orphans

        Don't use this method unless you know what you're doing.

        :type field: str
        :param field: The field name in the struct

        :rtype: :class:`_DynamicOrphan`
        """
        return _DynamicOrphan()._init(self.thisptr.disown(field), self._parent)

    cpdef as_reader(self):
        """A method for casting this Builder to a Reader

        Don't use this method unless you know what you're doing.

        :rtype: :class:`_DynamicStructReader`
        """
        cdef _DynamicStructReader reader
        reader = _DynamicStructReader()._init(self.thisptr.asReader(),
                                            self._parent)
        reader._obj_to_pin = self
        return reader

    property schema:
        """A property that returns the _StructSchema object matching this writer"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.fieldnames)

    def __str__(self):
        return printStructBuilder(self.thisptr).flatten().cStr()

    def __repr__(self):
        return '<%s builder %s>' % (self.schema.node.displayName, strStructBuilder(self.thisptr).cStr())

    def to_dict(self):
        return _to_dict(self)

cdef class _DynamicOrphan:
    cdef C_DynamicOrphan thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicOrphan other, object parent):
        self.thisptr = moveOrphan(other)
        self._parent = parent
        return self

    cdef C_DynamicOrphan move(self):
        return moveOrphan(self.thisptr)

    cpdef get(self):
        """Returns a python object corresponding to the DynamicValue owned by this orphan

        Use this DynamicValue to set fields inside the orphan
        """
        return to_python_builder(self.thisptr.get(), self._parent)

    def __str__(self):
        return str(self.get())

    def __repr__(self):
        return repr(self.get())

cdef class _Schema:
    cdef C_Schema thisptr
    cdef _init(self, C_Schema other):
        self.thisptr = other
        return self

    cpdef as_const_value(self):
        return to_python_reader(<C_DynamicValue.Reader>self.thisptr.asConst(), self)

    cpdef as_struct(self):
        return _StructSchema()._init(self.thisptr.asStruct())

    cpdef get_dependency(self, id):
        return _Schema()._init(self.thisptr.getDependency(id))

    cpdef get_proto(self):
        return _NodeReader().init(self.thisptr.getProto())

cdef class _StructSchema:
    cdef C_StructSchema thisptr
    cdef object __fieldnames, __union_fields, __non_union_fields
    cdef _init(self, C_StructSchema other):
        self.thisptr = other
        self.__fieldnames = None
        self.__union_fields = None
        self.__non_union_fields = None
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

    property union_fields:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__union_fields is not None:
               return self.__union_fields
            fieldlist = self.thisptr.getUnionFields()
            nfields = fieldlist.size()
            self.__union_fields = tuple(fieldlist[i].getProto().getName().cStr()
                                      for i in xrange(nfields))
            return self.__union_fields

    property non_union_fields:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__non_union_fields is not None:
               return self.__non_union_fields
            fieldlist = self.thisptr.getNonUnionFields()
            nfields = fieldlist.size()
            self.__non_union_fields = tuple(fieldlist[i].getProto().getName().cStr()
                                      for i in xrange(nfields))
            return self.__non_union_fields

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), None)

    def __richcmp__(_StructSchema self, _StructSchema other, mode):
        if mode == 2:
            return self.thisptr == other.thisptr
        elif mode == 3:
            return not (self.thisptr == other.thisptr)
        else:
            raise NotImplementedError()

    def __repr__(self):
        return '<schema for %s>' % self.node.displayName

cdef class _ParsedSchema:
    cdef C_ParsedSchema thisptr
    cdef _init(self, C_ParsedSchema other):
        self.thisptr = other
        return self

    cpdef as_const_value(self):
        return to_python_reader(<C_DynamicValue.Reader>self.thisptr.asConst(), self)

    cpdef as_struct(self):
        return _StructSchema()._init(self.thisptr.asStruct())

    cpdef get_dependency(self, id):
        return _Schema()._init(self.thisptr.getDependency(id))

    cpdef get_proto(self):
        return _NodeReader().init(self.thisptr.getProto())

    cpdef getNested(self, name):
        return _ParsedSchema()._init(self.thisptr.getNested(name))

class _StructABCMeta(type):
    """A metaclass for the Type.Reader and Type.Builder ABCs."""
    def __instancecheck__(cls, obj):
        return isinstance(obj, cls.__base__) and obj.schema == cls._schema

cdef class SchemaParser:
    """A class for loading Cap'n Proto schema files.

    Do not use this class unless you're sure you know what you're doing. Use the convenience method :func:`load` instead.
    """
    cdef C_SchemaParser * thisptr
    def __cinit__(self):
        self.thisptr = new C_SchemaParser()

    def __dealloc__(self):
        del self.thisptr

    def _parse_disk_file(self, displayName, diskPath, imports):
        cdef StringPtr * importArray = <StringPtr *>malloc(sizeof(StringPtr) * len(imports))

        for i in range(len(imports)):
            importArray[i] = StringPtr(imports[i])

        cdef ArrayPtr[StringPtr] importsPtr = ArrayPtr[StringPtr](importArray, <size_t>len(imports))

        ret = _ParsedSchema()
        ret._init(self.thisptr.parseDiskFile(displayName, diskPath, importsPtr))

        free(importArray)

        return ret

    def load(self, file_name, display_name=None, imports=[]):
        """Load a Cap'n Proto schema from a file 

        You will have to load a schema before you can begin doing anything
        meaningful with this library. Loading a schema is much like loading
        a Python module (and load even returns a `ModuleType`). Once it's been
        loaded, you use it much like any other Module::

            parser = capnp.SchemaParser()
            addressbook = parser.load('addressbook.capnp')
            print addressbook.qux # qux is a top level constant
            # 123
            person = addressbook.Person.new_message()

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

        :Raises:
            - :exc:`exceptions.IOError` if `file_name` doesn't exist
            - :exc:`exceptions.RuntimeError` if the Cap'n Proto C++ library has any problems loading the schema

        """
        def _load(nodeSchema, module):
            module._nodeSchema = nodeSchema
            nodeProto = nodeSchema.get_proto()
            module._nodeProto = nodeProto

            for node in nodeProto.nestedNodes:
                local_module = _ModuleType(node.name)
                module.__dict__[node.name] = local_module

                schema = nodeSchema.getNested(node.name)
                proto = schema.get_proto()
                if proto.isStruct:
                    local_module.schema = schema.as_struct()
                    def read(bound_local_module):
                        def helper(file):
                            reader = _StreamFdMessageReader(file.fileno())
                            return reader.get_root(bound_local_module)
                        return helper
                    def read_packed(bound_local_module):
                        def helper(file):
                            reader = _PackedFdMessageReader(file.fileno())
                            return reader.get_root(bound_local_module)
                        return helper
                    def make_from_bytes(bound_local_module):
                        def from_bytes(buf):
                            """Returns a Reader for the unpacked object in buf.

                            :type buf: buffer
                            :param buf: Any Python object that supports the readable buffer interface.  If buf is mutable, then changes to the object will be reflected in the returned Reader, which may be surprising.  If buf is an ordinary bytes object, then there should be no concern."""
                            reader = _FlatArrayMessageReader(buf)
                            return reader.get_root(bound_local_module)
                        return from_bytes
                    def new_message(bound_local_module):
                        def helper():
                            builder = _MallocMessageBuilder()
                            return builder.init_root(bound_local_module)
                        return helper
                    def from_dict(bound_local_module):
                        def helper(d):
                            builder = _MallocMessageBuilder()
                            msg = builder.init_root(bound_local_module)
                            _from_dict(msg, d)
                            return msg
                        return helper
                    class Reader(_DynamicStructReader):
                        """An abstract base class.  Readers are 'instances' of this class."""
                        __metaclass__ = _StructABCMeta
                        __slots__ = []
                        _schema = local_module.schema
                        def __new__(self):
                            raise TypeError('This is an abstract base class')
                    Reader._module = local_module
                    class Builder(_DynamicStructBuilder):
                        """An abstract base class.  Builders are 'instances' of this class."""
                        __metaclass__ = _StructABCMeta
                        __slots__ = []
                        _schema = local_module.schema
                        def __new__(self):
                            raise TypeError('This is an abstract base class')

                    local_module.read = read(local_module)
                    local_module.read_packed = read_packed(local_module)
                    local_module.new_message = new_message(local_module)
                    local_module.from_dict = from_dict(local_module)
                    local_module.from_bytes = make_from_bytes(local_module)
                    local_module.Reader = Reader
                    local_module.Builder = Builder
                elif proto.isConst:
                    module.__dict__[node.name] = schema.as_const_value()

                _load(schema, local_module)
        if not _os.path.isfile(file_name):
            raise IOError("File not found: " + file_name)

        if display_name is None:
            display_name = _os.path.basename(file_name)

        module = _ModuleType(display_name)
        parser = self

        module._parser = parser

        fileSchema = parser._parse_disk_file(display_name, file_name, imports)
        _load(fileSchema, module)

        abs_path = _os.path.abspath(file_name)
        module.__path__ = _os.path.dirname(abs_path)
        module.__file__ = abs_path

        return module

cdef class _MessageBuilder:
    """An abstract base class for building Cap'n Proto messages

    .. warning:: Don't ever instantiate this class directly. It is only used for inheritance.
    """
    cdef schema_cpp.MessageBuilder * thisptr
    def __dealloc__(self):
        del self.thisptr

    def __init__(self):
        raise NotImplementedError("This is an abstract base class. You should use MallocMessageBuilder instead")

    cpdef init_root(self, schema):
        """A method for instantiating Cap'n Proto structs

        You will need to pass in a schema to specify which struct to
        instantiate. Schemas are available in a loaded Cap'n Proto module::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.init_root(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructBuilder`
        :return: An object where you will set all the members
        """
        cdef _StructSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema
        return _DynamicStructBuilder()._init(self.thisptr.initRootDynamicStruct(s.thisptr), self, True)

    cpdef get_root(self, schema):
        """A method for instantiating Cap'n Proto structs, from an already pre-written buffer

        Don't use this method unless you know what you're doing. You probably
        want to use init_root instead::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.init_root(addressbook.Person)
            ...
            person = message.get_root(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructBuilder`
        :return: An object where you will set all the members
        """
        cdef _StructSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema
        return _DynamicStructBuilder()._init(self.thisptr.getRootDynamicStruct(s.thisptr), self, True)
    
    cpdef set_root(self, value):
        """A method for instantiating Cap'n Proto structs by copying from an existing struct

        :type value: :class:`_DynamicStructReader`
        :param value: A Cap'n Proto struct value to copy

        :rtype: void
        """
        
        if type(value) is _DynamicStructBuilder:
            value = value.as_reader();
        self.thisptr.setRootDynamicStruct((<_DynamicStructReader>value).thisptr)

    cpdef new_orphan(self, schema):
        """A method for instantiating Cap'n Proto orphans

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unkown sized list, ie::

            addressbook = capnp.load('addressbook.capnp')
            m = capnp._MallocMessageBuilder()
            alice = m.new_orphan(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicOrphan`
        :return: An orphan representing a :class:`_DynamicStructBuilder`
        """
        cdef _StructSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicOrphan()._init(self.thisptr.newOrphan(s.thisptr), self)

cdef class _MallocMessageBuilder(_MessageBuilder):
    """The main class for building Cap'n Proto messages

    You will use this class to handle arena allocation of the Cap'n Proto
    messages. You also use this object when you're done assigning to Cap'n
    Proto objects, and wish to serialize them::

        addressbook = capnp.load('addressbook.capnp')
        message = capnp._MallocMessageBuilder()
        person = message.init_root(addressbook.Person)
        person.name = 'alice'
        ...
        f = open('out.txt', 'w')
        _write_message_to_fd(f.fileno(), message)
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

    cpdef _get_root_node(self):
        return _NodeReader().init(self.thisptr.getRootNode())

    cpdef get_root(self, schema):
        """A method for instantiating Cap'n Proto structs

        You will need to pass in a schema to specify which struct to
        instantiate. Schemas are available in a loaded Cap'n Proto module::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.get_root(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructReader`
        :return: An object with all the data of the read Cap'n Proto message.
            Access members with . syntax.
        """
        cdef _StructSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema
        return _DynamicStructReader()._init(self.thisptr.getRootDynamicStruct(s.thisptr), self)

cdef class _StreamFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_message_to_fd` and :class:`_MessageBuilder`, but in one class::

        f = open('out.txt')
        message = _StreamFdMessageReader(f.fileno())
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, int fd):
        self.thisptr = new schema_cpp.StreamFdMessageReader(fd)

cdef class _PackedFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f.fileno())
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, int fd):
        self.thisptr = new schema_cpp.PackedFdMessageReader(fd)

@cython.internal
cdef class _FlatArrayMessageReader(_MessageReader):
    cdef object _object_to_pin
    def __init__(self, buf):
        cdef const void *ptr
        cdef Py_ssize_t sz
        PyObject_AsReadBuffer(buf, &ptr, &sz)
        if sz % 8 != 0:
            raise ValueError("input length must be a multiple of eight bytes")
        self._object_to_pin = buf
        self.thisptr = new schema_cpp.FlatArrayMessageReader(capnp.WordArrayPtr(<capnp.word*>ptr, sz//8))

def _write_message_to_fd(int fd, _MessageBuilder message):
    """Serialize a Cap'n Proto message to a file descriptor

    You use this method to serialize your message to a file. Please note that
    you must pass a file descriptor (ie. an int), not a file object. Make sure
    you use the proper reader to match this (ie. don't use _PackedFdMessageReader)::

        message = capnp._MallocMessageBuilder()
        ...
        f = open('out.txt', 'w')
        _write_message_to_fd(f.fileno(), message)
        ...
        f = open('out.txt')
        _StreamFdMessageReader(f.fileno())

    :type fd: int
    :param fd: A file descriptor

    :type message: :class:`_MessageBuilder`
    :param message: The Cap'n Proto message to serialize

    :rtype: void
    """
    schema_cpp.writeMessageToFd(fd, deref(message.thisptr))

def _write_packed_message_to_fd(int fd, _MessageBuilder message):
    """Serialize a Cap'n Proto message to a file descriptor in a packed manner

    You use this method to serialize your message to a file. Please note that
    you must pass a file descriptor (ie. an int), not a file object. Also, note
    the difference in names with _write_message_to_fd. This method uses a different
    serialization specification, and your reader will need to match.::

        message = capnp._MallocMessageBuilder()
        ...
        f = open('out.txt', 'w')
        _write_packed_message_to_fd(f.fileno(), message)
        ...
        f = open('out.txt')
        _PackedFdMessageReader(f.fileno())

    :type fd: int
    :param fd: A file descriptor

    :type message: :class:`_MessageBuilder`
    :param message: The Cap'n Proto message to serialize

    :rtype: void
    """
    schema_cpp.writePackedMessageToFd(fd, deref(message.thisptr))

from types import ModuleType as _ModuleType
import os as _os
import sys as _sys
import imp as _imp

_global_schema_parser = None

def load(file_name, display_name=None, imports=[]):
    """Load a Cap'n Proto schema from a file 

    You will have to load a schema before you can begin doing anything
    meaningful with this library. Loading a schema is much like loading
    a Python module (and load even returns a `ModuleType`). Once it's been
    loaded, you use it much like any other Module::

        addressbook = capnp.load('addressbook.capnp')
        print addressbook.qux # qux is a top level constant in the addressbook.capnp schema
        # 123
        person = addressbook.Person.new_message()

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
    global _global_schema_parser
    if _global_schema_parser is None:
        _global_schema_parser = SchemaParser()

    return _global_schema_parser.load(file_name, display_name, imports)

class _Loader:
    def __init__(self, fullname, path, additional_paths):
        self.fullname = fullname
        self.path = path

        # Add current directory of the capnp schema to search path
        dir_name = _os.path.dirname(path)
        if path is not '':
            additional_paths = [dir_name] + additional_paths

        self.additional_paths = additional_paths

    def load_module(self, fullname):
        assert self.fullname == fullname, (
            "invalid module, expected %s, got %s" % (
            self.fullname, fullname))

        imports = self.additional_paths + _sys.path
        imports = [path if path != '' else '.' for path in imports] # convert empty path '' to '.'
        module = load(self.path, fullname, imports=imports)
        _sys.modules[fullname] = module

        return module

class _Importer:
    def __init__(self, additional_paths):
        self.extension = '.capnp'
        self.additional_paths = additional_paths
    def find_module(self, fullname, package_path=None):
        if fullname in _sys.modules: # Don't allow re-imports
            return None

        if '.' in fullname: # only when package_path anyway?
            mod_parts = fullname.split('.')
            module_name = mod_parts[-1]
        else:
            module_name = fullname

        if not module_name.endswith('_capnp'):
            return None

        module_name = module_name[:-len('_capnp')]
        capnp_module_name = module_name + self.extension

        if package_path:
            paths = package_path
        else:
            paths = _sys.path
        join_path = _os.path.join
        is_file = _os.path.isfile
        is_abs = _os.path.isabs
        abspath = _os.path.abspath
        #is_dir = os.path.isdir
        sep = _os.path.sep

        paths = self.additional_paths + paths
        for path in paths:
            if not path:
                path = _os.getcwd()
            elif not is_abs(path):
                path = abspath(path)
            if is_file(path+sep+capnp_module_name):
                return _Loader(fullname, join_path(path, capnp_module_name), self.additional_paths)

_importer = None

def add_import_hook(additional_paths=[]):
    """Add a hook to the python import system, so that Cap'n Proto modules are directly importable

    After calling this function, you can use the python import syntax to directly import capnproto schemas::

        import capnp
        capnp.add_import_hook()

        import addressbook
        # equivalent to capnp.load('addressbook.capnp', 'addressbook', sys.path), except it will search for 'addressbook.capnp' in all directories of sys.path

    :type additional_paths: list
    :param additional_paths: Additional paths, listed as strings, to be used to search for the .capnp files. It is prepended to the beginning of sys.path. It also affects imports inside of Cap'n Proto schemas.
    """
    global _importer
    if _importer is not None:
        remove_import_hook()

    _importer = _Importer(additional_paths)
    _sys.meta_path.append(_importer)

def remove_import_hook():
    """Remove the import hook, and return python's import to normal"""
    global _importer
    if _importer is not None:
        _sys.meta_path.remove(_importer)
    _importer = None
