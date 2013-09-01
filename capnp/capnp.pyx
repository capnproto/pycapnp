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
from capnp_cpp cimport Schema as C_Schema, StructSchema as C_StructSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue, Type as C_Type, DynamicList as C_DynamicList, fixMaybe, SchemaParser as C_SchemaParser, ParsedSchema as C_ParsedSchema, VOID, ArrayPtr, StringPtr, String, StringTree, DynamicOrphan as C_DynamicOrphan

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

_MAX_INT = 2**63 - 1
ctypedef fused _DynamicStructReaderOrBuilder:
    _DynamicStructReader
    _DynamicStructBuilder

ctypedef fused _DynamicSetterClasses:
    C_DynamicList.Builder
    C_DynamicStruct.Builder

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
        person = message.getRoot(addressbook.Person)

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
        return toPythonReader(self.thisptr[index], self._parent)

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

    This class works much like :class:`_DynamicListBuilder`, but it allows growing the list dynamically. It is meant for lists of structs, since for primitive types like int or float, you're much better off using a normal python list and then serializing straight to a Cap'n Proto list. It has __getitem__ and __len__ defined, but not __setitem__.

        ...
        person = message.initRoot(addressbook.Person)

        phones = person.initResizableList('phones') # This returns a _DynamicResizableListBuilder
        
        phone = phones.add()
        phone.number = 'foo'
        phone = phones.add()
        phone.number = 'bar'

        people.finish()

        capnp.writePackedMessageToFd(fd, message)
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
        orphan = self._message.newOrphan(self._schema)
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
        person = message.initRoot(addressbook.Person)

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

    cdef _get(self, index) except +ValueError:
        return toPython(self.thisptr[index], self._parent)

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

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unkown sized list, ie::

            message = capnp.MallocMessageBuilder()

            alice = m.newOrphan(addressbook.Person)
            alice.get().name = 'alice'

            bob = m.newOrphan(addressbook.Person)
            bob.get().name = 'bob'

            addressBook = message.initRoot(addressbook.AddressBook)
            people = addressBook.init('people', 2)

            people.adopt(0, alice)
            people.adopt(1, bob)

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

cdef C_DynamicValue.Reader _extractDynamicStructBuilder(_DynamicStructBuilder value):
    return C_DynamicValue.Reader(value.thisptr.asReader())

cdef C_DynamicValue.Reader _extractDynamicStructReader(_DynamicStructReader value):
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
        builder = toPython(thisptr.init(field, len(value)), parent)
        for (i, v) in enumerate(value):
            builder[i] = v
    elif value is None:
        temp = C_DynamicValue.Reader(VOID)
        thisptr.set(field, temp)
    elif value_type is _DynamicStructBuilder:
        thisptr.set(field, _extractDynamicStructBuilder(value))
    elif value_type is _DynamicStructReader:
        thisptr.set(field, _extractDynamicStructReader(value))
    else:
        raise ValueError("Non primitive type")

cdef class _DynamicStructReader:
    """Reads Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Reader. The only difference is that instead of a `get` method, __getattr__ is overloaded and the field name is passed onto the C++ equivalent `get`. This means you just use . syntax to access any field. For field names that don't follow valid python naming convention for fields, use the global function :py:func:`getattr`::

        person = message.getRoot(addressbook.Person) # This returns a _DynamicStructReader
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
        return toPythonReader(self.thisptr.get(field), self._parent)

    def _has(self, field):
        return self.thisptr.has(field)

    cpdef which(self) except +ValueError:
        """Returns the enum corresponding to the union in this struct

        Enums are just strings in the python Cap'n Proto API, so this function will either return a string equal to the field name of the active field in the union, or throw a ValueError if this isn't a union, or a struct with an unnamed union::

            person = message.initRoot(addressbook.Person)
            
            person.which()
            # ValueError: member was null

            a.employment.employer = 'foo'
            print employment.which()
            # 'employer'

        :rtype: str
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`exceptions.ValueError` if this struct doesn't contain a union
        """
        return fixMaybe(self.thisptr.which()).getProto().getName().cStr()

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

cdef class _DynamicStructBuilder:
    """Builds Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Builder. The only difference is that instead of a `get`/`set` method, __getattr__/__setattr__ is overloaded and the field name is passed onto the C++ equivalent function. This means you just use . syntax to access or set any field. For field names that don't follow valid python naming convention for fields, use the global functions :py:func:`getattr`/:py:func:`setattr`::

        person = message.initRoot(addressbook.Person) # This returns a _DynamicStructBuilder
        
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
    
    def writeTo(self, file):
        """Writes the struct's containing message to the given file object in unpacked binary format.
        
        This is a shortcut for calling capnp.writeMessageToFd().  This can only be called on the
        message's root struct.
        
        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.
        
        :rtype: void
        
        :Raises: :exc:`exceptions.ValueError` if this isn't the message's root struct.
        """
        if not self._isRoot:
            raise ValueError("You can only call writeTo() on the message's root struct.")
        writeMessageToFd(file.fileno(), self._parent)

    def writePackedTo(self, file):
        """Writes the struct's containing message to the given file object in packed binary format.
        
        This is a shortcut for calling capnp.writePackedMessageToFd().  This can only be called on
        the message's root struct.
        
        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.
        
        :rtype: void
        
        :Raises: :exc:`exceptions.ValueError` if this isn't the message's root struct.
        """
        if not self._isRoot:
            raise ValueError("You can only call writeTo() on the message's root struct.")
        writePackedMessageToFd(file.fileno(), self._parent)

    cdef _get(self, field) except +ValueError:
        return toPython(self.thisptr.get(field), self._parent)

    def __getattr__(self, field):
        return self._get(field)

    def __setattr__(self, field, value):
        _setDynamicField(self.thisptr, field, value, self._parent)

    def _has(self, field):
        return self.thisptr.has(field)

    cpdef init(self, field, size=None) except +AttributeError:
        """Method for initializing fields that are of type union/struct/list

        Typically, you don't have to worry about initializing structs/unions, so this method is mainly for lists. 

        :type field: str
        :param field: The field name to initialize

        :type size: int
        :param size: The size of the list to initiialize. This should be None for struct/union initialization.

        :rtype: :class:`_DynamicStructBuilder` or :class:`_DynamicListBuilder`

        :Raises: :exc:`exceptions.AttributeError` if the field isn't in this struct
        """
        if size is None:
            return toPython(self.thisptr.init(field), self._parent)
        else:
            return toPython(self.thisptr.init(field, size), self._parent)

    cpdef initResizableList(self, field):
        """Method for initializing fields that are of type list (of structs)

        This version of init returns a :class:`_DynamicResizableListBuilder` that allows you to add members one at a time (ie. if you don't know the size for sure). This is only meant for lists of Cap'n Proto objects, since for primitive types you can just define a normal python list and fill it yourself. 

        .. warning:: You need to call :meth:`_DynamicResizableListBuilder.finish` on the list object before serializing the Cap'n Proto message. Failure to do so will cause your objects not to be written out as well as leaking orphan structs into your message.

        :type field: str
        :param field: The field name to initialize

        :rtype: :class:`_DynamicResizableListBuilder`

        :Raises: :exc:`exceptions.AttributeError` if the field isn't in this struct
        """
        return _DynamicResizableListBuilder(self, field, _StructSchema()._init((<C_DynamicValue.Builder>self.thisptr.get(field)).asList().getStructElementType()))

    cpdef which(self) except +ValueError:
        """Returns the enum corresponding to the union in this struct

        Enums are just strings in the python Cap'n Proto API, so this function will either return a string equal to the field name of the active field in the union, or throw a ValueError if this isn't a union, or a struct with an unnamed union::

            person = message.initRoot(addressbook.Person)
            
            person.which()
            # ValueError: member was null

            a.employment.employer = 'foo'
            print employment.which()
            # 'employer'
            
        :rtype: str
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`exceptions.ValueError` if this struct doesn't contain a union
        """
        return fixMaybe(self.thisptr.which()).getProto().getName().cStr()

    cpdef adopt(self, field, _DynamicOrphan orphan):
        """A method for adopting Cap'n Proto orphans

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unkown sized list, ie::

            message = capnp.MallocMessageBuilder()

            alice = m.newOrphan(addressbook.Person)
            alice.get().name = 'alice'

            bob = m.newOrphan(addressbook.Person)
            bob.get().name = 'bob'

            addressBook = message.initRoot(addressbook.AddressBook)
            people = addressBook.init('people', 2)

            people.adopt(0, alice)
            people.adopt(1, bob)

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

    cpdef asReader(self):
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
        return toPython(self.thisptr.get(), self._parent)

    def __str__(self):
        return str(self.get())

    def __repr__(self):
        return repr(self.get())

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

    def __repr__(self):
        return '<schema for %s>' % self.node.displayName

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

cdef class SchemaParser:
    """A class for loading Cap'n Proto schema files.

    Do not use this class unless you're sure you know what you're doing. Use the convenience method :func:`load` instead.
    """
    cdef C_SchemaParser * thisptr
    def __cinit__(self):
        self.thisptr = new C_SchemaParser()

    def __dealloc__(self):
        del self.thisptr

    def _parseDiskFile(self, displayName, diskPath, imports):
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
                    local_module.schema = schema.asStruct()
                    def readFrom(file):
                        reader = StreamFdMessageReader(file.fileno())
                        return reader.getRoot(local_module)
                    def readPackedFrom(file):
                        reader = PackedFdMessageReader(file.fileno())
                        return reader.getRoot(local_module)
                    def newMessage():
                        builder = MallocMessageBuilder()
                        return builder.initRoot(local_module)
                    local_module.readFrom = readFrom
                    local_module.readPackedFrom = readPackedFrom
                    local_module.newMessage = newMessage
                elif proto.isConst:
                    module.__dict__[node.name] = schema.asConstValue()

                _load(schema, local_module)

        if display_name is None:
            display_name = _os.path.basename(file_name)

        module = _ModuleType(display_name)
        parser = self

        module._parser = parser

        fileSchema = parser._parseDiskFile(display_name, file_name, imports)
        _load(fileSchema, module)

        return module

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
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema
        return _DynamicStructBuilder()._init(self.thisptr.initRootDynamicStruct(s.thisptr), self, True)

    cpdef getRoot(self, schema):
        """A method for instantiating Cap'n Proto structs, from an already pre-written buffer

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
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema
        return _DynamicStructBuilder()._init(self.thisptr.getRootDynamicStruct(s.thisptr), self, True)
    
    cpdef setRoot(self, value):
        """A method for instantiating Cap'n Proto structs by copying from an existing struct

        :type value: :class:`_DynamicStructReader`
        :param value: A Cap'n Proto struct value to copy

        :rtype: void
        """
        
        if type(value) is _DynamicStructBuilder:
            value = value.asReader();
        self.thisptr.setRootDynamicStruct((<_DynamicStructReader>value).thisptr)

    cpdef newOrphan(self, schema):
        """A method for instantiating Cap'n Proto orphans

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unkown sized list, ie::

            addressbook = capnp.load('addressbook.capnp')

            alice = m.newOrphan(addressbook.Person)

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
        f = open('out.txt', 'w')
        writeMessageToFd(f.fileno(), message)
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
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema
        return _DynamicStructReader()._init(self.thisptr.getRootDynamicStruct(s.thisptr), self)

cdef class StreamFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`writeMessageToFd` and :class:`MessageBuilder`, but in one class::

        f = open('out.txt')
        message = StreamFdMessageReader(f.fileno())
        person = message.getRoot(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, int fd):
        self.thisptr = new schema_cpp.StreamFdMessageReader(fd)

cdef class PackedFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`writePackedMessageToFd` and :class:`MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = StreamFdMessageReader(f.fileno())
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
        f = open('out.txt', 'w')
        writeMessageToFd(f.fileno(), message)
        ...
        f = open('out.txt')
        StreamFdMessageReader(f.fileno())

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
        f = open('out.txt', 'w')
        writePackedMessageToFd(f.fileno(), message)
        ...
        f = open('out.txt')
        PackedFdMessageReader(f.fileno())

    :type fd: int
    :param fd: A file descriptor

    :type message: :class:`MessageBuilder`
    :param message: The Cap'n Proto message to serialize

    :rtype: void
    """
    schema_cpp.writePackedMessageToFd(fd, deref(message.thisptr))

from types import ModuleType as _ModuleType
import os as _os

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
    global _global_schema_parser
    if _global_schema_parser is None:
        _global_schema_parser = SchemaParser()

    return _global_schema_parser.load(file_name, display_name, imports)
