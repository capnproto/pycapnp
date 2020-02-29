# capnp.pyx
# distutils: language = c++
# distutils: libraries = capnpc capnp-rpc capnp kj-async kj
# distutils: include_dirs = .
# cython: c_string_type = str
# cython: c_string_encoding = default
# cython: embedsignature = True
# cython: language_level = 2

cimport cython

from capnp.helpers.helpers cimport AsyncIoStreamReadHelper, init_capnp_api
from capnp.includes.capnp_cpp cimport AsyncIoStream, WaitScope, PyPromise, VoidPromise

from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from cython.operator cimport dereference as deref
from cpython.exc cimport PyErr_Clear
from cpython cimport array, Py_buffer, PyObject_CheckBuffer
from cpython.buffer cimport PyBUF_SIMPLE, PyBUF_WRITABLE

from types import ModuleType as _ModuleType
import os as _os
import sys as _sys
import traceback as _traceback
from functools import partial as _partial
import warnings as _warnings
import inspect as _inspect
from operator import attrgetter as _attrgetter
import threading as _threading
import socket as _socket
import random as _random
import collections as _collections
import array
import asyncio

_CAPNP_VERSION_MAJOR = capnp.CAPNP_VERSION_MAJOR
_CAPNP_VERSION_MINOR = capnp.CAPNP_VERSION_MINOR
_CAPNP_VERSION_MICRO = capnp.CAPNP_VERSION_MICRO
_CAPNP_VERSION = capnp.CAPNP_VERSION

cdef dict _type_registry = {}

def register_type(id, klass):
    _type_registry[id] = klass

def deregister_all_types():
    _type_registry = {}

# By making it public, we'll be able to call it from capabilityHelper.h
cdef api object wrap_dynamic_struct_reader(Response & r) with gil:
    return _Response()._init_childptr(new Response(moveResponse(r)), None)

cdef api PyObject * wrap_remote_call(PyObject * func, Response & r) except * with gil:
    response = _Response()._init_childptr(new Response(moveResponse(r)), None)

    func_obj = <object>func
    ret = func_obj(response)
    Py_INCREF(ret)
    return <PyObject *>ret

cdef _find_field_order(struct_node):
    return [f.name for f in sorted(struct_node.fields, key=_attrgetter('codeOrder'))]

cdef api VoidPromise * call_server_method(PyObject * _server, char * _method_name, CallContext & _context) except * with gil:
    server = <object>_server
    method_name = <object>_method_name

    context = _CallContext()._init(_context) # TODO:MEMORY: invalidate this with promise chain
    func = getattr(server, method_name+'_context', None)
    if func is not None:
        ret = func(context)
        if ret is not None:
            if type(ret) is _VoidPromise:
                return new VoidPromise(moveVoidPromise(deref((<_VoidPromise>ret).thisptr)))
            elif type(ret) is _Promise:
                return new VoidPromise(helpers.convert_to_voidpromise(deref((<_Promise>ret).thisptr)))
            else:
                try:
                    warning_msg = 'Server function (%s) returned a value that was not a Promise: return = %s' % (method_name, str(ret))
                except:
                    warning_msg = 'Server function (%s) returned a value that was not a Promise' % (method_name)
                _warnings.warn_explicit(warning_msg, UserWarning, _inspect.getsourcefile(func), _inspect.getsourcelines(func)[1])

        if ret is not None:
            if type(ret) is _Promise:
                return new VoidPromise(helpers.convert_to_voidpromise(deref((<_Promise>ret).thisptr)))
            elif type(ret) is _Promise:
                return new VoidPromise(helpers.convert_to_voidpromise(deref((<_Promise>ret).thisptr)))
            else:
                try:
                    warning_msg = 'Server function (%s) returned a value that was not a Promise: return = %s' % (method_name, str(ret))
                except:
                    warning_msg = 'Server function (%s) returned a value that was not a Promise' % (method_name)
                _warnings.warn_explicit(warning_msg, UserWarning, _inspect.getsourcefile(func), _inspect.getsourcelines(func)[1])
    else:
        func = getattr(server, method_name) # will raise if no function found
        params = context.params
        params_dict = {name : getattr(params, name) for name in params.schema.fieldnames}
        params_dict['_context'] = context
        ret = func(**params_dict)

        if ret is not None:
            if type(ret) is _VoidPromise:
                return new VoidPromise(moveVoidPromise(deref((<_VoidPromise>ret).thisptr)))
            elif type(ret) is _Promise:
                return new VoidPromise(helpers.convert_to_voidpromise(deref((<_Promise>ret).thisptr)))
            if not isinstance(ret, tuple):
                ret = (ret,)
            names = _find_field_order(context.results.schema.node.struct)
            if len(ret) > len(names):
                raise KjException('Too many values returned from `%s`. Expected %d and got %d' % (method_name, len(names), len(ret)))

            results = context.results
            for arg_name, arg_val in zip(names, ret):
                setattr(results, arg_name, arg_val)

    return NULL

cdef api convert_array_pyobject(PyArray & arr) with gil:
    return [<object>arr[i] for i in range(arr.size())]

cdef api PyPromise * extract_promise(object obj) with gil:
    if type(obj) is _Promise:
        promise = <_Promise>obj

        ret = new PyPromise(promise.thisptr.attach(capnp.makePyRefCounter(<PyObject *>promise)))
        Py_DECREF(obj)

        return ret

    return NULL

cdef api RemotePromise * extract_remote_promise(object obj) with gil:
    if type(obj) is _RemotePromise:
        promise = <_RemotePromise>obj
        promise.is_consumed = True

        return promise.thisptr # TODO:MEMORY: fix this leak

    return NULL

cdef extern from "<kj/string.h>" namespace " ::kj":
    String strStructReader" ::kj::str"(C_DynamicStruct.Reader)
    String strStructBuilder" ::kj::str"(DynamicStruct_Builder)
    String strRequest" ::kj::str"(Request &)
    String strListReader" ::kj::str"(C_DynamicList.Reader)
    String strListBuilder" ::kj::str"(C_DynamicList.Builder)
    String strException" ::kj::str"(capnp.Exception)

def _make_enum(enum_name, *sequential, **named):
    enums = dict(zip(sequential, range(len(sequential))), **named)
    reverse = dict((value, key) for key, value in enums.iteritems())
    enums['reverse_mapping'] = reverse
    return type(enum_name, (), enums)

_Type = _make_enum('_Type',
                    FAILED = 0,
                    OVERLOADED = 1,
                    DISCONNECTED = 2,
                    UNIMPLEMENTED = 3,
                    OTHER = 4)

cdef class _KjExceptionWrapper:
    cdef capnp.Exception * thisptr

    cdef _init(self, capnp.Exception & other):
        self.thisptr = new capnp.Exception(moveException(other))
        return self

    def __dealloc__(self):
        del self.thisptr

    property file:
        def __get__(self):
            return <char*>self.thisptr.getFile()
    property line:
        def __get__(self):
            return self.thisptr.getLine()
    property type:
        def __get__(self):
            cdef int temp = <int>self.thisptr.getType()
            return _Type.reverse_mapping[temp]
    property description:
        def __get__(self):
            return <char*>self.thisptr.getDescription().cStr()

    def __str__(self):
        return <char*>strException(deref(self.thisptr)).cStr()

# Extension classes can't inherit from Exception, so we're going to proxy wrap kj::Exception, and forward all calls to it from this Python class
class KjException(Exception):

    '''KjException is a wrapper of the internal C++ exception type. There is an enum named `Type` listed below, and a bunch of fields'''

    Type = _make_enum('Type', **{x : x for x in _Type.reverse_mapping.values()})

    def __init__(self, message=None, nature=None, durability=None, wrapper=None, type=None):
        if wrapper is not None:
            self.wrapper = wrapper
            self.message = str(wrapper)
        else:
            self.wrapper = None
            self.message = message
            self.nature = nature
            self.durability = durability
            self._type = type

    @property
    def file(self):
        return self.wrapper.file
    @property
    def line(self):
        return self.wrapper.line
    @property
    def type(self):
        if self.wrapper is not None:
            return self.wrapper.type
        else:
            return self._type
    @property
    def description(self):
        if self.wrapper is not None:
            return self.wrapper.description
        else:
            return self.message

    def __str__(self):
        return self.message

    def _to_python(self):
        message = self.message
        if self.wrapper.type == 'FAILED':
            if 'has no such' in self.message:
                return AttributeError(message)
        return self

cdef api object wrap_kj_exception(capnp.Exception & exception) with gil:
    PyErr_Clear()
    wrapper = _KjExceptionWrapper()._init(exception)
    ret = KjException(wrapper=wrapper)

    return ret

cdef api object wrap_kj_exception_for_reraise(capnp.Exception & exception) with gil:
    wrapper = _KjExceptionWrapper()._init(exception)

    ret = KjException(wrapper=wrapper)
    return ret

cdef api object get_exception_info(object exc_type, object exc_obj, object exc_tb) with gil:
    try:
        return (exc_tb.tb_frame.f_code.co_filename.encode(), exc_tb.tb_lineno, (repr(exc_type) + ':' + str(exc_obj)).encode())
    except:
        return (b'', 0, b"Couldn't determine python exception")

cdef schema_cpp.ReaderOptions make_reader_opts(traversal_limit_in_words, nesting_limit) with gil:
    cdef schema_cpp.ReaderOptions opts
    if traversal_limit_in_words is not None:
        opts.traversalLimitInWords = traversal_limit_in_words
    if nesting_limit is not None:
        opts.nestingLimit = nesting_limit
    return opts

ctypedef fused _DynamicStructReaderOrBuilder:
    _DynamicStructReader
    _DynamicStructBuilder

ctypedef fused _DynamicSetterClasses:
    C_DynamicList.Builder
    DynamicStruct_Builder

ctypedef fused PromiseTypes:
    _Promise
    _RemotePromise
    _VoidPromise
    PromiseFulfillerPair

cdef extern from "Python.h":
    cdef int PyObject_GetBuffer(object, Py_buffer *view, int flags)
    cdef void PyBuffer_Release(Py_buffer *view)

# Templated classes are weird in cython. I couldn't put it in a pxd header for some reason
cdef extern from "capnp/list.h" namespace " ::capnp":
    cdef cppclass List[T]:
        cppclass Reader:
            T operator[](uint) except +reraise_kj_exception
            uint size()
        cppclass Builder:
            T operator[](uint) except +reraise_kj_exception
            uint size()

cdef extern from "<utility>" namespace "std":
    C_DynamicStruct.Pipeline moveStructPipeline"std::move"(C_DynamicStruct.Pipeline)
    C_DynamicOrphan moveOrphan"std::move"(C_DynamicOrphan)
    Request moveRequest"std::move"(Request)
    Response moveResponse"std::move"(Response)
    PyPromise movePromise"std::move"(PyPromise)
    VoidPromise moveVoidPromise"std::move"(VoidPromise)
    RemotePromise moveRemotePromise"std::move"(RemotePromise)
    CallContext moveCallContext"std::move"(CallContext)
    Own[AsyncIoStream] moveOwnAsyncIOStream"std::move"(Own[AsyncIoStream])
    capnp.Exception moveException"std::move"(capnp.Exception)
    capnp.AsyncIoContext moveAsyncContext"std::move"(capnp.AsyncIoContext)

cdef extern from "<capnp/pretty-print.h>" namespace " ::capnp":
    StringTree printStructReader" ::capnp::prettyPrint"(C_DynamicStruct.Reader) except +reraise_kj_exception
    StringTree printStructBuilder" ::capnp::prettyPrint"(DynamicStruct_Builder) except +reraise_kj_exception
    StringTree printRequest" ::capnp::prettyPrint"(Request &) except +reraise_kj_exception
    StringTree printListReader" ::capnp::prettyPrint"(C_DynamicList.Reader) except +reraise_kj_exception
    StringTree printListBuilder" ::capnp::prettyPrint"(C_DynamicList.Builder) except +reraise_kj_exception

cdef class _NodeReader:
    cdef C_Node.Reader thisptr
    cdef init(self, C_Node.Reader other):
        self.thisptr = other
        return self

    property displayName:
        def __get__(self):
            return <char*>self.thisptr.getDisplayName().cStr()
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
    property isInterface:
        def __get__(self):
            return self.thisptr.isInterface()
    property isEnum:
        def __get__(self):
            return self.thisptr.isEnum()

cdef class _NestedNodeReader:
    cdef C_Node.NestedNode.Reader thisptr
    cdef init(self, C_Node.NestedNode.Reader other):
        self.thisptr = other
        return self

    property name:
        def __get__(self):
            return <char*>self.thisptr.getName().cStr()
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

    cpdef _get(self, int64_t index):
        return to_python_reader(self.thisptr[index], self._parent)

    def __getitem__(self, int64_t index):
        cdef uint size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return self._get(index)

    def __len__(self):
        return self.thisptr.size()

    def __str__(self):
        return <char*>printListReader(self.thisptr).flatten().cStr()

    def __repr__(self):
        # TODO:  Print the list type.
        return '<capnp list reader %s>' % <char*>strListReader(self.thisptr).cStr()

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

    cpdef _get(self, index):
        return self._list[index][1]

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
    cdef _init(self, C_DynamicList.Builder other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cpdef _get(self, int64_t index):
        return to_python_builder(self.thisptr[index], self._parent)

    def __getitem__(self, int64_t index):
        cdef uint size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return self._get(index)

    cpdef _set(self, index, value):
        _setDynamicField(self.thisptr, index, value, self._parent)

    def __setitem__(self, index, value):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        _setDynamicField(self.thisptr, index, value, self._parent)

    def __len__(self):
        return self.thisptr.size()

    cpdef adopt(self, index, _DynamicOrphan orphan):
        """A method for adopting Cap'n Proto orphans

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unknown sized list.

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

    cpdef init(self, index, size):
        """A method for initializing an element in a list

        :type index: int
        :param index: The index of the element in the list

        :type size: int
        :param size: Size of the element to be initialized.
        """
        return to_python_builder(self.thisptr.init(index, size), self._parent)

    def __str__(self):
        return <char*>printListBuilder(self.thisptr).flatten().cStr()

    def __repr__(self):
        # TODO:  Print the list type.
        return '<capnp list builder %s>' % <char*>strListBuilder(self.thisptr).cStr()

cdef class _List_NestedNode_Reader:
    cdef C_Node.NestedNode.Reader.ListNestedNodeReader thisptr
    cdef _init(self, List[C_Node.NestedNode].Reader other):
        self.thisptr = <C_Node.NestedNode.Reader.ListNestedNodeReader>other
        return self

    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _NestedNodeReader().init(<C_Node.NestedNode.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()

# cdef to_python_pipeline(C_DynamicValue.Pipeline self, object parent):
#     cdef int type = self.getType()
#     if type == capnp.TYPE_CAPABILITY:
#         return _DynamicCapabilityClient()._init(self.asCapability(), parent)
#     # elif type == capnp.TYPE_STRUCT:
#     #     return _DynamicStructReader()._init(self.asStruct(), parent)
#     elif type == capnp.TYPE_UNKNOWN:
#         raise KjException("Cannot convert type to Python. Type is unknown by capnproto library")
#     else:
#         raise KjException("Cannot convert type to Python. Type is unhandled by capnproto library")

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
        temp_text = self.asText()
        return (<char*>temp_text.begin())[:temp_text.size()]
    elif type == capnp.TYPE_DATA:
        temp_data = self.asData()
        return <bytes>((<char*>temp_data.begin())[:temp_data.size()])
    elif type == capnp.TYPE_LIST:
        return _DynamicListReader()._init(self.asList(), parent)
    elif type == capnp.TYPE_STRUCT:
        return _DynamicStructReader()._init(self.asStruct(), parent)
    elif type == capnp.TYPE_ENUM:
        return _DynamicEnum()._init(self.asEnum(), parent)
    elif type == capnp.TYPE_VOID:
        return None
    elif type == capnp.TYPE_ANY_POINTER:
        return _DynamicObjectReader()._init(self.asObject(), parent)
    elif type == capnp.TYPE_CAPABILITY:
        return _DynamicCapabilityClient()._init(self.asCapability(), parent)
    elif type == capnp.TYPE_UNKNOWN:
        raise KjException("Cannot convert type to Python. Type is unknown by capnproto library")
    else:
        raise KjException("Cannot convert type to Python. Type is unhandled by capnproto library")

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
        temp_text = self.asText()
        return (<char*>temp_text.begin())[:temp_text.size()]
    elif type == capnp.TYPE_DATA:
        temp_data = self.asData()
        return <bytes>((<char*>temp_data.begin())[:temp_data.size()])
    elif type == capnp.TYPE_LIST:
        return _DynamicListBuilder()._init(self.asList(), parent)
    elif type == capnp.TYPE_STRUCT:
        return _DynamicStructBuilder()._init(self.asStruct(), parent)
    elif type == capnp.TYPE_ENUM:
        return _DynamicEnum()._init(self.asEnum(), parent)
    elif type == capnp.TYPE_VOID:
        return None
    elif type == capnp.TYPE_ANY_POINTER:
        return _DynamicObjectBuilder()._init(self.asObject(), parent)
    elif type == capnp.TYPE_CAPABILITY:
        return _DynamicCapabilityClient()._init(self.asCapability(), parent)
    elif type == capnp.TYPE_UNKNOWN:
        raise KjException("Cannot convert type to Python. Type is unknown by capnproto library")
    else:
        raise KjException("Cannot convert type to Python. Type is unhandled by capnproto library")

cdef C_DynamicValue.Reader _extract_dynamic_struct_builder(_DynamicStructBuilder value):
    return C_DynamicValue.Reader(value.thisptr.asReader())

cdef C_DynamicValue.Reader _extract_dynamic_struct_reader(_DynamicStructReader value):
    return C_DynamicValue.Reader(value.thisptr)

cdef C_DynamicValue.Reader _extract_dynamic_client(_DynamicCapabilityClient value):
    return C_DynamicValue.Reader(value.thisptr)

cdef C_DynamicValue.Reader _extract_dynamic_server(object value):
    cdef _InterfaceSchema schema = value.schema
    return helpers.new_server(schema.thisptr, <PyObject *>value)

cdef C_DynamicValue.Reader _extract_dynamic_enum(_DynamicEnum value):
    return C_DynamicValue.Reader(value.thisptr)

cdef C_DynamicValue.Reader _extract_any_pointer(_DynamicObjectReader value):
    return C_DynamicValue.Reader(value.thisptr)

cdef C_DynamicValue.Reader _extract_any_pointer_builder(_DynamicObjectBuilder value):
    return C_DynamicValue.Reader(value.thisptr.asReader())

cdef _setBytes(_DynamicSetterClasses thisptr, field, value):
    cdef capnp.StringPtr temp_string = capnp.StringPtr(<char*>value, len(value))
    cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(temp_string)
    thisptr.set(field, temp)

cdef _setBaseString(_DynamicSetterClasses thisptr, field, value):
    encoded_value = value.encode('utf-8')
    cdef capnp.StringPtr temp_string = capnp.StringPtr(<char*>encoded_value, len(encoded_value))
    cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(temp_string)
    thisptr.set(field, temp)

cdef _setBytesField(DynamicStruct_Builder thisptr, _StructSchemaField field, value):
    cdef capnp.StringPtr temp_string = capnp.StringPtr(<char*>value, len(value))
    cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(temp_string)
    thisptr.setByField(field.thisptr, temp)

cdef _setBaseStringField(DynamicStruct_Builder thisptr, _StructSchemaField field, value):
    encoded_value = value.encode('utf-8')
    cdef capnp.StringPtr temp_string = capnp.StringPtr(<char*>encoded_value, len(encoded_value))
    cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(temp_string)
    thisptr.setByField(field.thisptr, temp)

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
    elif value_type is bytes:
        _setBytes(thisptr, field, value)
    elif isinstance(value, basestring):
        _setBaseString(thisptr, field, value)
    elif value_type is list:
        builder = to_python_builder(thisptr.init(field, len(value)), parent)
        _from_list(builder, value)
    elif value_type is tuple:
        builder = to_python_builder(thisptr.init(field, len(value)), parent)
        _from_tuple(builder, value)
    elif value_type is dict:
        if _DynamicSetterClasses is DynamicStruct_Builder:
            builder = to_python_builder(thisptr.get(field), parent)
            builder.from_dict(value)
        else:
            builder = to_python_builder(thisptr[field], parent)
            builder.from_dict(value)
    elif value is None:
        temp = C_DynamicValue.Reader(VOID)
        thisptr.set(field, temp)
    elif value_type is _DynamicStructBuilder:
        thisptr.set(field, _extract_dynamic_struct_builder(value))
    elif value_type is _DynamicStructReader:
        thisptr.set(field, _extract_dynamic_struct_reader(value))
    elif value_type is _DynamicCapabilityClient:
        thisptr.set(field, _extract_dynamic_client(value))
    elif value_type is _DynamicCapabilityServer or isinstance(value, _DynamicCapabilityServer):
        thisptr.set(field, _extract_dynamic_server(value))
    elif value_type is _DynamicEnum:
        thisptr.set(field, _extract_dynamic_enum(value))
    elif value_type is _DynamicObjectReader:
        thisptr.set(field, _extract_any_pointer(value))
    elif value_type is _DynamicObjectBuilder:
        thisptr.set(field, _extract_any_pointer_builder(value))
    else:
        raise KjException("Tried to set field: '{}' with a value of: '{}' which is an unsupported type: '{}'".format(field, str(value), str(type(value))))

cdef _setDynamicFieldWithField(DynamicStruct_Builder thisptr, _StructSchemaField field, value, parent):
    cdef C_DynamicValue.Reader temp
    value_type = type(value)

    if value_type is int or value_type is long:
        if value < 0:
           temp = C_DynamicValue.Reader(<long long>value)
        else:
           temp = C_DynamicValue.Reader(<unsigned long long>value)
        thisptr.setByField(field.thisptr, temp)
    elif value_type is float:
        temp = C_DynamicValue.Reader(<double>value)
        thisptr.setByField(field.thisptr, temp)
    elif value_type is bool:
        temp = C_DynamicValue.Reader(<cbool>value)
        thisptr.setByField(field.thisptr, temp)
    elif value_type is bytes:
        _setBytesField(thisptr, field, value)
    elif isinstance(value, basestring):
        _setBaseStringField(thisptr, field, value)
    elif value_type is list:
        builder = to_python_builder(thisptr.init(field.proto.name, len(value)), parent)
        _from_list(builder, value)
    elif value_type is dict:
        builder = to_python_builder(thisptr.getByField(field.thisptr), parent)
        builder.from_dict(value)
    elif value is None:
        temp = C_DynamicValue.Reader(VOID)
        thisptr.setByField(field.thisptr, temp)
    elif value_type is _DynamicStructBuilder:
        thisptr.setByField(field.thisptr, _extract_dynamic_struct_builder(value))
    elif value_type is _DynamicStructReader:
        thisptr.setByField(field.thisptr, _extract_dynamic_struct_reader(value))
    elif value_type is _DynamicCapabilityClient:
        thisptr.setByField(field.thisptr, _extract_dynamic_client(value))
    elif value_type is _DynamicCapabilityServer or isinstance(value, _DynamicCapabilityServer):
        thisptr.setByField(field.thisptr, _extract_dynamic_server(value))
    elif value_type is _DynamicEnum:
        thisptr.setByField(field.thisptr, _extract_dynamic_enum(value))
    elif value_type is _DynamicObjectReader:
        thisptr.set(field, _extract_any_pointer(value))
    elif value_type is _DynamicObjectBuilder:
        thisptr.set(field, _extract_any_pointer_builder(value))
    else:
        raise KjException("Tried to set field: '{}' with a value of: '{}' which is an unsupported type: '{}'".format(field, str(value), str(type(value))))

cdef _setDynamicFieldStatic(DynamicStruct_Builder thisptr, field, value, parent):
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
    elif value_type is bytes:
        _setBytes(thisptr, field, value)
    elif isinstance(value, basestring):
        _setBaseString(thisptr, field, value)
    elif value_type is list:
        builder = to_python_builder(thisptr.init(field, len(value)), parent)
        _from_list(builder, value)
    elif value_type is dict:
        builder = to_python_builder(thisptr.get(field), parent)
        builder.from_dict(value)
    elif value is None:
        temp = C_DynamicValue.Reader(VOID)
        thisptr.set(field, temp)
    elif value_type is _DynamicStructBuilder:
        thisptr.set(field, _extract_dynamic_struct_builder(value))
    elif value_type is _DynamicStructReader:
        thisptr.set(field, _extract_dynamic_struct_reader(value))
    elif value_type is _DynamicCapabilityClient:
        thisptr.set(field, _extract_dynamic_client(value))
    elif value_type is _DynamicCapabilityServer or isinstance(value, _DynamicCapabilityServer):
        thisptr.set(field, _extract_dynamic_server(value))
    elif value_type is _DynamicEnum:
        thisptr.set(field, _extract_dynamic_enum(value))
    elif value_type is _DynamicObjectReader:
        thisptr.set(field, _extract_any_pointer(value))
    elif value_type is _DynamicObjectBuilder:
        thisptr.set(field, _extract_any_pointer_builder(value))
    else:
        raise KjException("Tried to set field: '{}' with a value of: '{}' which is an unsupported type: '{}'".format(field, str(value), str(type(value))))

cdef _DynamicListBuilder temp_list_b
cdef _DynamicListReader temp_list_r
cdef _DynamicResizableListBuilder temp_list_rb
cdef _DynamicStructBuilder temp_msg_b
cdef _DynamicStructReader temp_msg_r
cdef _to_dict(msg, bint verbose, bint ordered):
    msg_type = type(msg)
    if msg_type is _DynamicListBuilder:
        temp_list_b = msg
        return [_to_dict(temp_list_b._get(i), verbose, ordered) for i in range(len(msg))]
    elif msg_type is _DynamicListReader:
        temp_list_r = msg
        return [_to_dict(temp_list_r._get(i), verbose, ordered) for i in range(len(msg))]
    elif msg_type is _DynamicResizableListBuilder:
        temp_list_rb = msg
        return [_to_dict(temp_list_rb._get(i), verbose, ordered) for i in range(len(msg))]

    if msg_type is _DynamicStructBuilder:
        temp_msg_b = msg
        if ordered:
            ret = _collections.OrderedDict()
        else:
            ret = {}
        try:
            which = temp_msg_b.which()
            ret[which] = _to_dict(temp_msg_b._get(which), verbose, ordered)
        except KjException:
            pass

        for field in temp_msg_b.schema.non_union_fields:
            if verbose or temp_msg_b._has(field):
                ret[field] = _to_dict(temp_msg_b._get(field), verbose, ordered)

        return ret
    elif msg_type is _DynamicStructReader:
        temp_msg_r = msg
        if ordered:
            ret = _collections.OrderedDict()
        else:
            ret = {}
        try:
            which = temp_msg_r.which()
            ret[which] = _to_dict(temp_msg_r._get(which), verbose, ordered)
        except KjException:
            pass

        for field in temp_msg_r.schema.non_union_fields:
            if verbose or temp_msg_r._has(field):
                ret[field] = _to_dict(temp_msg_r._get(field), verbose, ordered)

        return ret

    if isinstance(msg, (_DynamicStructBuilder, _DynamicStructReader)):
        return msg.to_dict(verbose, ordered)

    if msg_type is _DynamicEnum:
        return str(msg)

    return msg


cdef _from_list(_DynamicListBuilder msg, list d):
    for i, x in enumerate(d):
        msg._set(i, x)


cdef _from_tuple(_DynamicListBuilder msg, tuple d):
    for i, x in enumerate(d):
        msg._set(i, x)


cdef class _DynamicEnum:
    cdef _init(self, capnp.DynamicEnum other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cpdef _as_str(self) except +reraise_kj_exception:
        return <char*>helpers.fixMaybe(self.thisptr.getEnumerant()).getProto().getName().cStr()

    property raw:
        """A property that returns the raw int of the enum"""
        def __get__(self):
            return self.thisptr.getRaw()

    def __str__(self):
        return self._as_str()

    def __repr__(self):
        return '<%s enum>' % str(self)

    def __richcmp__(_DynamicEnum self, right, int op):
        if isinstance(right, basestring):
            left = self._as_str()
        else:
            left = self.thisptr.getRaw()

        if op == 2: # ==
            return left == right
        elif op == 3: # !=
            return left != right
        elif op == 0: # <
            return left < right
        elif op == 1: # <=
            return left <= right
        elif op == 4: # >
            return left > right
        elif op == 5: # >=
            return left >= right

    def __hash__(_DynamicEnum self):
        return hash(self._as_str())


cdef class _DynamicEnumField:
    cdef _init(self, proto):
        self.thisptr = proto
        return self

    property raw:
        """A property that returns the raw int of the enum"""
        def __get__(self):
            return self.thisptr.discriminantValue

    cpdef _str(self):
        return self.thisptr.name

    def __str__(self):
        return self._str()

    def __repr__(self):
        return '<%s which-enum>' % str(self)

    def __richcmp__(_DynamicEnumField self, right, int op):
        if isinstance(right, basestring):
            left = self.thisptr.name
        else:
            left = self.thisptr.discriminantValue

        if op == 2: # ==
            return left == right
        elif op == 3: # !=
            return left != right
        elif op == 0: # <
            return left < right
        elif op == 1: # <=
            return left <= right
        elif op == 4: # >
            return left > right
        elif op == 5: # >=
            return left >= right

    def __call__(self):
        return str(self)

cdef class _MessageSize:
    cdef public uint64_t word_count
    cdef public uint cap_count

    def __init__(self, uint64_t word_count, uint cap_count):
        self.word_count = word_count
        self.cap_count = cap_count

if getattr(_sys, 'subversion', [''])[0] == 'PyPy':
    from pickle_helper import _struct_reducer
else:
    def _struct_reducer(schema_id, data):
        return _global_schema_parser.modules_by_id[schema_id].from_bytes(data)

cdef class _DynamicStructReader:
    """Reads Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Reader. The only difference is that instead of a `get` method, __getattr__ is overloaded and the field name is passed onto the C++ equivalent `get`. This means you just use . syntax to access any field. For field names that don't follow valid python naming convention for fields, use the global function :py:func:`getattr`::

        person = addressbook.Person.read(file) # This returns a _DynamicStructReader
        print person.name # using . syntax
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """
    cdef _init(self, C_DynamicStruct.Reader other, object parent, bint isRoot=False, bint tryRegistry = True):
        self.thisptr = other
        self._parent = parent
        self.is_root = isRoot
        self._schema = None

        if tryRegistry and len(_type_registry) > 0:
            registered_type = _type_registry.get(self.thisptr.getId(), None)
            if registered_type:
                return registered_type[0](self)
        return self

    cpdef _get(self, field):
        return to_python_reader(self.thisptr.get(field), self)

    def __getattr__(self, field):
        try:
            return self._get(field)
        except KjException as e:
            raise e._to_python(), None, _sys.exc_info()[2]

    cpdef _get_by_field(self, _StructSchemaField field):
        return to_python_reader(self.thisptr.getByField(field.thisptr), self)

    cpdef _has(self, field):
        return self.thisptr.has(field)

    cpdef _has_by_field(self, _StructSchemaField field):
        return self.thisptr.hasByField(field.thisptr)

    cpdef _which_str(self):
        try:
            return <char *>helpers.fixMaybe(self.thisptr.which()).getProto().getName().cStr()
        except:
            raise KjException("Attempted to call which on a non-union type")

    cpdef _DynamicEnumField _which(self):
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
        try:
            which = _DynamicEnumField()._init(_StructSchemaField()._init(helpers.fixMaybe(self.thisptr.which()), self).proto)
        except:
            raise KjException("Attempted to call which on a non-union type")

        return which

    property which:
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
        def __get__(_DynamicStructReader self):
            return self._which()

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            if self._schema is None:
                self._schema = _StructSchema()._init(self.thisptr.getSchema())
            return self._schema

    def __dir__(self):
        return list(set(self.schema.fieldnames + tuple(dir(self.__class__))))

    def __str__(self):
        return <char*>printStructReader(self.thisptr).flatten().cStr()

    def __repr__(self):
        return '<%s reader %s>' % (self.schema.node.displayName, <char*>strStructReader(self.thisptr).cStr())

    def to_dict(self, verbose=False, ordered=False):
        return _to_dict(self, verbose, ordered)

    cpdef as_builder(self, num_first_segment_words=None):
        """A method for casting this Reader to a Builder

        This is a copying operation with respect to the message's buffer. Changes in the new builder will not reflect in the original reader.

        :type num_first_segment_words: int
        :param num_first_segment_words: Size of the first segment to allocate in the message (in words ie. 8 byte increments)

        :rtype: :class:`_DynamicStructBuilder`
        """
        builder = _MallocMessageBuilder(num_first_segment_words)
        return builder.set_root(self)

    property total_size:
        def __get__(self):
            size = self.thisptr.totalSize()
            return _MessageSize(size.wordCount, size.capCount)

    def __reduce_ex__(self, proto):
        return _struct_reducer, (self.schema.node.id, self.as_builder().to_bytes())


cdef class _DynamicStructBuilder:
    """Builds Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Builder. The only difference is that instead of a `get`/`set` method, __getattr__/__setattr__ is overloaded and the field name is passed onto the C++ equivalent function. This means you just use . syntax to access or set any field. For field names that don't follow valid python naming convention for fields, use the global functions :py:func:`getattr`/:py:func:`setattr`::

        person = addressbook.Person.new_message() # This returns a _DynamicStructBuilder

        person.name = 'foo' # using . syntax
        print person.name # using . syntax

        setattr(person, 'field-with-hyphens', 'foo') # for names that are invalid for python, use setattr
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """
    cdef _init(self, DynamicStruct_Builder other, object parent, bint isRoot = False, bint tryRegistry = True):
        self.thisptr = other
        self._parent = parent
        self.is_root = isRoot
        self._is_written = False
        self._schema = None

        if tryRegistry and len(_type_registry) > 0:
            registered_type = _type_registry.get(self.thisptr.getId(), None)
            if registered_type:
                return registered_type[1](self)
        return self

    cdef _check_write(self):
        if not self.is_root:
            raise KjException("You can only call write() on the message's root struct.")
        if self._is_written:
            _warnings.warn("This message has already been written once. Be very careful that you're not setting Text/Struct/List fields more than once, since that will cause memory leaks (both in memory and in the serialized data). You can disable this warning by calling the `clear_write_flag` method of this object after every write.")

    def write(self, file):
        """Writes the struct's containing message to the given file object in unpacked binary format.

        This is a shortcut for calling capnp._write_message_to_fd().  This can only be called on the
        message's root struct.

        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.

        :rtype: void

        :Raises: :exc:`KjException` if this isn't the message's root struct.
        """
        self._check_write()
        _write_message_to_fd(file.fileno(), self._parent)
        self._is_written = True

    def write_packed(self, file):
        """Writes the struct's containing message to the given file object in packed binary format.

        This is a shortcut for calling capnp._write_packed_message_to_fd().  This can only be called on
        the message's root struct.

        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.

        :rtype: void

        :Raises: :exc:`KjException` if this isn't the message's root struct.
        """
        self._check_write()
        _write_packed_message_to_fd(file.fileno(), self._parent)
        self._is_written = True

    cpdef to_bytes(_DynamicStructBuilder self) except +reraise_kj_exception:
        """Returns the struct's containing message as a Python bytes object in the unpacked binary format.

        This is inefficient; it makes several copies.

        :rtype: bytes

        :Raises: :exc:`KjException` if this isn't the message's root struct.
        """
        self._check_write()
        cdef _MessageBuilder builder = self._parent
        array = schema_cpp.messageToFlatArray(deref(builder.thisptr))
        cdef const char* ptr = <const char *>array.begin()
        cdef bytes ret = ptr[:8*array.size()]
        self._is_written = True
        return ret

    cpdef to_segments(_DynamicStructBuilder self) except +reraise_kj_exception:
        """Returns the struct's containing message as a Python list of Python bytes objects.

        This avoids making copies.

        NB: This is not currently supported on PyPy.

        :rtype: list
        """
        self._check_write()
        cdef _MessageBuilder builder = self._parent
        segments = builder.get_segments_for_output()
        return segments

    cpdef _to_bytes_packed_helper(_DynamicStructBuilder self, word_count) except +reraise_kj_exception:
        cdef _MessageBuilder builder = self._parent
        array = helpers.messageToPackedBytes(deref(builder.thisptr), word_count)
        cdef const char* ptr = <const char *>array.begin()
        cdef bytes ret = ptr[:array.size()]
        return ret

    cpdef to_bytes_packed(_DynamicStructBuilder self) except +reraise_kj_exception:
        self._check_write()
        word_count = self.total_size.word_count + 2

        try:
            ret = self._to_bytes_packed_helper(word_count)
        except Exception as e:
            if 'backing array was not large enough' in str(e):
                word_count *= 2
                ret = self._to_bytes_packed_helper(word_count)
            else:
                raise

        self._is_written = True
        return ret

    cpdef _get(self, field):
        return to_python_builder(self.thisptr.get(field), self._parent)

    cpdef _get_by_field(self, _StructSchemaField field):
        return to_python_builder(self.thisptr.getByField(field.thisptr), self._parent)

    def __getattr__(self, field):
        try:
            return self._get(field)
        except KjException as e:
            raise e._to_python(), None, _sys.exc_info()[2]

    cpdef _set(self, field, value):
        _setDynamicField(self.thisptr, field, value, self._parent)

    cpdef _set_by_field(self, _StructSchemaField field, value):
        _setDynamicFieldWithField(self.thisptr, field, value, self._parent)

    def __setattr__(self, field, value):
        try:
            self._set(field, value)
        except KjException as e:
            raise e._to_python(), None, _sys.exc_info()[2]

    cpdef _has(self, field):
        return self.thisptr.has(field)

    cpdef _has_by_field(self, _StructSchemaField field):
        return self.thisptr.hasByField(field.thisptr)

    cpdef init(self, field, size=None):
        """Method for initializing fields that are of type union/struct/list

        Typically, you don't have to worry about initializing structs/unions, so this method is mainly for lists.

        :type field: str
        :param field: The field name to initialize

        :type size: int
        :param size: The size of the list to initiialize. This should be None for struct/union initialization.

        :rtype: :class:`_DynamicStructBuilder` or :class:`_DynamicListBuilder`

        :Raises: :exc:`KjException` if the field isn't in this struct
        """
        if size is None:
            return to_python_builder(self.thisptr.init(field), self._parent)
        else:
            return to_python_builder(self.thisptr.init(field, size), self._parent)

    cpdef _init_by_field(self, _StructSchemaField field, size=None):
        """Method for initializing fields that are of type union/struct/list

        Typically, you don't have to worry about initializing structs/unions, so this method is mainly for lists.

        :type field: str
        :param field: The field name to initialize

        :type size: int
        :param size: The size of the list to initiialize. This should be None for struct/union initialization.

        :rtype: :class:`_DynamicStructBuilder` or :class:`_DynamicListBuilder`

        :Raises: :exc:`KjException` if the field isn't in this struct
        """
        if size is None:
            return to_python_builder(self.thisptr.initByField(field.thisptr), self._parent)
        else:
            return to_python_builder(self.thisptr.initByField(field.thisptr, size), self._parent)

    cpdef init_resizable_list(self, field):
        """Method for initializing fields that are of type list (of structs)

        This version of init returns a :class:`_DynamicResizableListBuilder` that allows you to add members one at a time (ie. if you don't know the size for sure). This is only meant for lists of Cap'n Proto objects, since for primitive types you can just define a normal python list and fill it yourself.

        .. warning:: You need to call :meth:`_DynamicResizableListBuilder.finish` on the list object before serializing the Cap'n Proto message. Failure to do so will cause your objects not to be written out as well as leaking orphan structs into your message.

        :type field: str
        :param field: The field name to initialize

        :rtype: :class:`_DynamicResizableListBuilder`

        :Raises: :exc:`KjException` if the field isn't in this struct
        """
        return _DynamicResizableListBuilder(self, field, _StructSchema()._init((<C_DynamicValue.Builder>self.thisptr.get(field)).asList().getStructElementType()))

    cpdef _which_str(self):
        try:
            return <char *>helpers.fixMaybe(self.thisptr.which()).getProto().getName().cStr()
        except:
            raise KjException("Attempted to call which on a non-union type")

    cpdef _DynamicEnumField _which(self):
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
        try:
            which = _DynamicEnumField()._init(_StructSchemaField()._init(helpers.fixMaybe(self.thisptr.which()), self).proto)
        except:
            raise KjException("Attempted to call which on a non-union type")

        return which

    property which:
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
        def __get__(_DynamicStructBuilder self):
            return self._which()

    cpdef adopt(self, field, _DynamicOrphan orphan):
        """A method for adopting Cap'n Proto orphans

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unknown sized list.

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

        This is a non-copying operation with respect to the message's buffer. This means changes to the fields in the original struct will carry over to the new reader.

        :rtype: :class:`_DynamicStructReader`
        """
        cdef _DynamicStructReader reader
        reader = _DynamicStructReader()._init(self.thisptr.asReader(),
                                            self._parent, self.is_root)
        reader._obj_to_pin = self
        return reader

    cpdef copy(self, num_first_segment_words=None):
        """A method for copying this Builder

        This is a copying operation with respect to the message's buffer. Changes in the new builder will not reflect in the original reader.

        :type num_first_segment_words: int
        :param num_first_segment_words: Size of the first segment to allocate in the message (in words ie. 8 byte increments)

        :rtype: :class:`_DynamicStructBuilder`
        """
        builder = _MallocMessageBuilder(num_first_segment_words)
        return builder.set_root(self)

    property schema:
        """A property that returns the _StructSchema object matching this writer"""
        def __get__(self):
            if self._schema is None:
                self._schema = _StructSchema()._init(self.thisptr.getSchema())
            return self._schema

    def __dir__(self):
        return list(set(self.schema.fieldnames + tuple(dir(self.__class__))))

    def __str__(self):
        return <char*>printStructBuilder(self.thisptr).flatten().cStr()

    def __repr__(self):
        return '<%s builder %s>' % (self.schema.node.displayName, <char*>strStructBuilder(self.thisptr).cStr())

    def to_dict(self, verbose=False, ordered=False):
        return _to_dict(self, verbose, ordered)

    def from_dict(self, dict d):
        for key, val in d.iteritems():
            if key != 'which':
                try:
                    self._set(key, val)
                except Exception as e:
                    if 'expected isSetInUnion(field)' in str(e):
                        self.init(key)
                        self._set(key, val)
                    else:
                        raise

    property total_size:
        def __get__(self):
            size = self.thisptr.totalSize()
            return _MessageSize(size.wordCount, size.capCount)

    def clear_write_flag(self):
        """A method used to clear the _is_written flag.

        This allows you to write the struct more than once without seeing any warnings.
        """
        self._is_written = False

    def __reduce_ex__(self, proto):
        return _struct_reducer, (self.schema.node.id, self.to_bytes())

cdef class _DynamicStructPipeline:
    """Reads Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Pipeline. The only difference is that instead of a `get` method, __getattr__ is overloaded and the field name is passed onto the C++ equivalent `get`. This means you just use . syntax to access any field. For field names that don't follow valid python naming convention for fields, use the global function :py:func:`getattr`::
    """
    cdef C_DynamicStruct.Pipeline * thisptr
    cdef public object _parent

    cdef _init(self, C_DynamicStruct.Pipeline * other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    def __dealloc__(self):
        del self.thisptr

    cpdef _get(self, field) except +reraise_kj_exception:
        cdef int type = (<C_DynamicValue.Pipeline>self.thisptr.get(field)).getType()
        if type == capnp.TYPE_CAPABILITY:
            return _DynamicCapabilityClient()._init((<C_DynamicValue.Pipeline>self.thisptr.get(field)).asCapability(), self._parent)
        elif type == capnp.TYPE_STRUCT:
            return _DynamicStructPipeline()._init(new C_DynamicStruct.Pipeline((<C_DynamicValue.Pipeline>self.thisptr.get(field)).asStruct()), self._parent)
        elif type == capnp.TYPE_UNKNOWN:
            raise KjException("Cannot convert type to Python. Type is unknown by capnproto library")
        else:
            raise KjException("Cannot convert type to Python. Type is unhandled by capnproto library")

    def __getattr__(self, field):
        try:
            return self._get(field)
        except KjException as e:
            raise e._to_python(), None, _sys.exc_info()[2]

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(set(self.schema.fieldnames + tuple(dir(self.__class__))))

    # def __str__(self):
    #     return printStructReader(self.thisptr).flatten().cStr()

    # def __repr__(self):
    #     return '<%s reader %s>' % (self.schema.node.displayName, strStructReader(self.thisptr).cStr())

    def to_dict(self, verbose=False, ordered=False):
        return _to_dict(self, verbose, ordered)

cdef class _DynamicOrphan:
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

cdef class _DynamicObjectReader:
    cdef C_DynamicObject.Reader thisptr
    cdef public object _parent

    cdef _init(self, C_DynamicObject.Reader other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cpdef as_struct(self, schema) except +reraise_kj_exception:
        cdef _StructSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicStructReader()._init(self.thisptr.getAs(s.thisptr), self._parent)

    cpdef as_interface(self, schema) except +reraise_kj_exception:
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicCapabilityClient()._init(self.thisptr.getAsCapability(s.thisptr), self._parent)

    cpdef as_list(self, schema) except +reraise_kj_exception:
        cdef ListSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicListReader()._init(self.thisptr.getAsList(s.thisptr), self._parent)

    cpdef as_text(self) except +reraise_kj_exception:
        return (<char*>self.thisptr.getAsText().cStr())[:]

cdef class _DynamicObjectBuilder:
    cdef C_DynamicObject.Builder * thisptr
    cdef public object _parent

    cdef _init(self, C_DynamicObject.Builder other, object parent):
        self.thisptr = new C_DynamicObject.Builder(other)
        self._parent = parent
        return self

    def __dealloc__(self):
        del self.thisptr

    cpdef as_struct(self, schema) except +reraise_kj_exception:
        cdef _StructSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicStructBuilder()._init(self.thisptr.getAs(s.thisptr), self._parent)

    cpdef as_interface(self, schema) except +reraise_kj_exception:
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicCapabilityClient()._init(self.thisptr.getAsCapability(s.thisptr), self._parent)

    cpdef as_list(self, schema) except +reraise_kj_exception:
        cdef ListSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicListBuilder()._init(self.thisptr.getAsList(s.thisptr), self._parent)

    cpdef set(self, other):
        "Set value of this object with the value of another AnyPointer::Reader. Don't use this for structs"
        cdef _DynamicObjectReader reader = other
        self.thisptr.set(reader.thisptr)

    cpdef set_as_text(self, text):
        self.thisptr.setAsText(text)

    cpdef init_as_list(self, schema, size):
        cdef ListSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicListBuilder()._init(self.thisptr.initAsList(s.thisptr, size), self._parent)

    cpdef as_text(self) except +reraise_kj_exception:
        return (<char*>self.thisptr.getAsText().cStr())[:]

    cpdef as_reader(self):
        return _DynamicObjectReader()._init(self.thisptr.asReader(), self._parent)

cdef class _EventLoop:
    cdef capnp.AsyncIoContext * thisptr

    def __init__(self):
        self._init()

    cdef _init(self) except +reraise_kj_exception:
        self.thisptr = new capnp.AsyncIoContext(capnp.setupAsyncIo())

    def __dealloc__(self):
        del self.thisptr #TODO:MEMORY: fix problems with Promises still being around

    cpdef _remove(self) except +reraise_kj_exception:
        del self.thisptr
        self.thisptr = NULL

    cdef TwoWayPipe makeTwoWayPipe(self):
        return deref(deref(self.thisptr).provider).newTwoWayPipe()

    cdef Own[AsyncIoStream] wrapSocketFd(self, int fd):
        return deref(deref(self.thisptr).lowLevelProvider).wrapSocketFd(fd)

cdef _EventLoop C_DEFAULT_EVENT_LOOP

_C_DEFAULT_EVENT_LOOP_LOCAL = None
_THREAD_LOCAL_EVENT_LOOPS = []

cdef _EventLoop C_DEFAULT_EVENT_LOOP_GETTER():
    'Optimization for not having to deal with threadlocal event loops unless we need to'
    global C_DEFAULT_EVENT_LOOP
    if C_DEFAULT_EVENT_LOOP is not None:
        return C_DEFAULT_EVENT_LOOP
    elif _C_DEFAULT_EVENT_LOOP_LOCAL is not None:
        loop = getattr(_C_DEFAULT_EVENT_LOOP_LOCAL, 'loop', None)
        if loop is not None:
            return <_EventLoop>_C_DEFAULT_EVENT_LOOP_LOCAL.loop
        else:
            _C_DEFAULT_EVENT_LOOP_LOCAL.loop = _EventLoop()
            return _C_DEFAULT_EVENT_LOOP_LOCAL.loop
    else:
      C_DEFAULT_EVENT_LOOP = _EventLoop()
      return C_DEFAULT_EVENT_LOOP

cdef class _Timer:
    cdef capnp.Timer * thisptr

    cdef _init(self, capnp.Timer * timer):
        self.thisptr = timer
        return self

    cpdef after_delay(self, time) except +reraise_kj_exception:
        return _VoidPromise()._init(self.thisptr.afterDelay(capnp.Nanoseconds(time)))

def getTimer():
    return _Timer()._init(helpers.getTimer(C_DEFAULT_EVENT_LOOP_GETTER().thisptr))

cpdef remove_event_loop(ignore_errors=False):
    'Remove the global event loop'
    global C_DEFAULT_EVENT_LOOP
    global _THREAD_LOCAL_EVENT_LOOPS
    global _C_DEFAULT_EVENT_LOOP_LOCAL

    if C_DEFAULT_EVENT_LOOP:
        try:
            C_DEFAULT_EVENT_LOOP._remove()
        except:
            if not ignore_errors:
                raise
        C_DEFAULT_EVENT_LOOP = None
    if len(_THREAD_LOCAL_EVENT_LOOPS) > 0:
        for loop in _THREAD_LOCAL_EVENT_LOOPS:
            try:
                loop._remove()
            except:
                if not ignore_errors:
                    raise
        _THREAD_LOCAL_EVENT_LOOPS = []
        _C_DEFAULT_EVENT_LOOP_LOCAL = None

cpdef create_event_loop(threaded=True):
    '''Create a new global event loop. This will not remove the previous
    EventLoop for you, so make sure to do that first'''
    global C_DEFAULT_EVENT_LOOP
    global _C_DEFAULT_EVENT_LOOP_LOCAL
    if threaded:
        if _C_DEFAULT_EVENT_LOOP_LOCAL is None:
            _C_DEFAULT_EVENT_LOOP_LOCAL = _threading.local()
        loop = _EventLoop()
        _C_DEFAULT_EVENT_LOOP_LOCAL.loop = loop
        _THREAD_LOCAL_EVENT_LOOPS.append(loop)
    else:
        C_DEFAULT_EVENT_LOOP = _EventLoop()

cpdef reset_event_loop():
    global C_DEFAULT_EVENT_LOOP
    C_DEFAULT_EVENT_LOOP._remove()
    C_DEFAULT_EVENT_LOOP = _EventLoop()

def wait_forever():
    cdef _EventLoop loop = C_DEFAULT_EVENT_LOOP_GETTER()
    helpers.waitNeverDone(deref(loop.thisptr).waitScope)

def poll_once():
    cdef _EventLoop loop = C_DEFAULT_EVENT_LOOP_GETTER()
    helpers.pollWaitScope(deref(loop.thisptr).waitScope)

cdef class _CallContext:
    cdef CallContext * thisptr

    cdef _init(self, CallContext other):
        self.thisptr = new CallContext(moveCallContext(other))
        return self

    def __dealloc__(self):
        del self.thisptr

    property params:
        def __get__(self):
           return _DynamicStructReader()._init(self.thisptr.getParams(), self)

    cpdef _get_results(self, uint word_count=0):
        return _DynamicStructBuilder()._init(self.thisptr.getResults(), self) # TODO: pass firstSegmentWordSize

    property results:
        def __get__(self):
           return self._get_results()

    cpdef release_params(self):
        self.thisptr.releaseParams()

    cpdef allow_cancellation(self):
        self.thisptr.allowCancellation()

    cpdef tail_call(self, _Request tailRequest):
        promise = _VoidPromise()._init(self.thisptr.tailCall(moveRequest(deref(tailRequest.thisptr_child))))
        promise.is_consumed = True
        return promise

cdef class _Promise:
    cdef PyPromise * thisptr
    cdef public bint is_consumed
    cdef public object _parent, _obj
    cdef _EventLoop _event_loop

    def __init__(self, obj=None):
        if obj is None:
            self.is_consumed = True
        else:
            self.is_consumed = False
            self._obj = obj
            Py_INCREF(obj) # TODO: MEM: fix leak
            self.thisptr = new PyPromise(<PyObject *>obj)

        self._event_loop = C_DEFAULT_EVENT_LOOP_GETTER()

    cdef _init(self, PyPromise other, parent=None):
        self.is_consumed = False
        self.thisptr = new PyPromise(movePromise(other))
        self._parent = parent
        return self

    def __dealloc__(self):
        del self.thisptr

    cpdef wait(self) except +reraise_kj_exception:
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = <object>helpers.waitPyPromise(self.thisptr, deref(self._event_loop.thisptr).waitScope)
        Py_DECREF(ret)

        self.is_consumed = True

        return ret

    cpdef then(self, func, error_func=None) except +reraise_kj_exception:
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        argspec = None
        try:
            argspec = _inspect.getfullargspec(func)
        except:
            pass
        if argspec:
            args_length = len(argspec.args) if argspec.args else 0
            defaults_length = len(argspec.defaults) if argspec.defaults else 0
            if args_length - defaults_length != 1:
                raise KjException('Function passed to `then` call must take exactly one argument')

        cdef _Promise new_promise = _Promise()._init(helpers.then(deref(self.thisptr), <PyObject *>func, <PyObject *>error_func), self)
        return _Promise()._init(new_promise.thisptr.attach(capnp.makePyRefCounter(<PyObject *>func), capnp.makePyRefCounter(<PyObject *>error_func)), new_promise)

    def attach(self, *args):
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = _Promise()._init(self.thisptr.attach(capnp.makePyRefCounter(<PyObject *>args)), self)
        self.is_consumed = True

        return ret

    cpdef cancel(self, numParents=1) except +reraise_kj_exception:
        if numParents > 0 and hasattr(self._parent, 'cancel'):
            self._parent.cancel(numParents - 1)

        self.is_consumed = True
        del self.thisptr
        self.thisptr = NULL


cdef class _VoidPromise:
    cdef VoidPromise * thisptr
    cdef public bint is_consumed
    cdef public object _parent
    cdef _EventLoop _event_loop

    def __init__(self):
        self.is_consumed = True
        self._event_loop = C_DEFAULT_EVENT_LOOP_GETTER()

    cdef _init(self, VoidPromise other, parent=None):
        self.is_consumed = False
        self.thisptr = new VoidPromise(moveVoidPromise(other))
        self._parent = parent
        return self

    def __dealloc__(self):
        del self.thisptr

    cpdef wait(self) except +reraise_kj_exception:
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        helpers.waitVoidPromise(self.thisptr, deref(self._event_loop.thisptr).waitScope)

        self.is_consumed = True

    cpdef then(self, func, error_func=None) except +reraise_kj_exception:
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        argspec = None
        try:
            argspec = _inspect.getfullargspec(func)
        except:
            pass
        if argspec:
            args_length = len(argspec.args) if argspec.args else 0
            defaults_length = len(argspec.defaults) if argspec.defaults else 0
            if args_length - defaults_length != 0:
                raise KjException('Function passed to `then` call must take no arguments')

        cdef _Promise new_promise = _Promise()._init(helpers.then(deref(self.thisptr), <PyObject *>func, <PyObject *>error_func), self)
        return _Promise()._init(new_promise.thisptr.attach(capnp.makePyRefCounter(<PyObject *>func), capnp.makePyRefCounter(<PyObject *>error_func)), new_promise)

    cpdef as_pypromise(self) except +reraise_kj_exception:
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')
        return _Promise()._init(helpers.convert_to_pypromise(deref(self.thisptr)), self)

    def attach(self, *args):
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = _VoidPromise()._init(self.thisptr.attach(capnp.makePyRefCounter(<PyObject *>args)), self)
        self.is_consumed = True

        return ret

    cpdef cancel(self, numParents=1) except +reraise_kj_exception:
        if numParents > 0 and hasattr(self._parent, 'cancel'):
            self._parent.cancel(numParents - 1)

        self.is_consumed = True
        del self.thisptr
        self.thisptr = NULL

cdef class _RemotePromise:
    cdef RemotePromise * thisptr
    cdef public bint is_consumed
    cdef public object _parent
    cdef _EventLoop _event_loop

    def __init__(self):
        self.is_consumed = True
        self._event_loop = C_DEFAULT_EVENT_LOOP_GETTER()

    cdef _init(self, RemotePromise other, parent):
        self.is_consumed = False
        self.thisptr = new RemotePromise(moveRemotePromise(other))
        self._parent = parent
        return self

    def __dealloc__(self):
        del self.thisptr

    cpdef _wait(self) except +reraise_kj_exception:
        return _Response()._init_childptr(helpers.waitRemote(self.thisptr, deref(self._event_loop.thisptr).waitScope), self._parent)

    def wait(self):
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = self._wait()
        self.is_consumed = True
        return ret

    async def a_wait(self):
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        while not helpers.pollRemote(self.thisptr, deref(self._event_loop.thisptr).waitScope):
            await asyncio.sleep(0.01)
        ret = self._wait()
        self.is_consumed = True

        return ret

    cpdef as_pypromise(self) except +reraise_kj_exception:
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')
        return _Promise()._init(helpers.convert_to_pypromise(deref(self.thisptr)), self)

    cpdef then(self, func, error_func=None) except +reraise_kj_exception:
        if self.is_consumed:
            raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

        argspec = None
        try:
            argspec = _inspect.getfullargspec(func)
        except:
            pass
        if argspec:
            args_length = len(argspec.args) if argspec.args else 0
            defaults_length = len(argspec.defaults) if argspec.defaults else 0
            if args_length - defaults_length != 1:
                raise KjException('Function passed to `then` call must take exactly one argument')

        cdef _Promise new_promise = _Promise()._init(helpers.then(deref(self.thisptr), <PyObject *>func, <PyObject *>error_func), self)
        return _Promise()._init(new_promise.thisptr.attach(capnp.makePyRefCounter(<PyObject *>func), capnp.makePyRefCounter(<PyObject *>error_func)), new_promise)

    cpdef _get(self, field) except +reraise_kj_exception:
        cdef int type = (<C_DynamicValue.Pipeline>self.thisptr.get(field)).getType()
        if type == capnp.TYPE_CAPABILITY:
            return _DynamicCapabilityClient()._init((<C_DynamicValue.Pipeline>self.thisptr.get(field)).asCapability(), self._parent)
        elif type == capnp.TYPE_STRUCT:
            return _DynamicStructPipeline()._init(new C_DynamicStruct.Pipeline((<C_DynamicValue.Pipeline>self.thisptr.get(field)).asStruct()), self._parent)
        elif type == capnp.TYPE_UNKNOWN:
            raise KjException("Cannot convert type to Python. Type is unknown by capnproto library")
        else:
            raise KjException("Cannot convert type to Python. Type is unhandled by capnproto library")

    def __getattr__(self, field):
        try:
            return self._get(field)
        except KjException as e:
            raise e._to_python(), None, _sys.exc_info()[2]

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(set(self.schema.fieldnames + tuple(dir(self.__class__))))

    def to_dict(self, verbose=False, ordered=False):
        return _to_dict(self, verbose, ordered)

    cpdef cancel(self, numParents=1) except +reraise_kj_exception:
        if numParents > 0 and hasattr(self._parent, 'cancel'):
            self._parent.cancel(numParents - 1)

        self.is_consumed = True
        del self.thisptr
        self.thisptr = NULL

    # def attach(self, *args):
    #     if self.is_consumed:
    #         raise KjException('Promise was already used in a consuming operation. You can no longer use this Promise object')

    #     ret = _RemotePromise()._init(self.thisptr.attach(capnp.makePyRefCounter(<PyObject *>args)), self)
    #     self.is_consumed = True

    #     return ret

cpdef join_promises(promises) except +reraise_kj_exception:
    heap = capnp.heapArrayBuilderPyPromise(len(promises))

    new_promises = []
    new_promises_append = new_promises.append

    for promise in promises:
        promise_type = type(promise)
        if promise_type is _Promise:
            pyPromise = <_Promise>promise
        elif promise_type is _RemotePromise or promise_type is _VoidPromise:
            pyPromise = <_Promise>promise.as_pypromise()
            new_promises_append(pyPromise)
        else:
            raise KjException('One of the promises passed to `join_promises` had a non promise value of: ' + str(promise))
        heap.add(movePromise(deref(pyPromise.thisptr)))
        pyPromise.is_consumed = True

    return _Promise()._init(helpers.then(capnp.joinPromises(heap.finish())))

cdef class _Request(_DynamicStructBuilder):
    cdef Request * thisptr_child
    cdef public bint is_consumed

    cdef _init_child(self, Request other, parent):
        self.thisptr_child = new Request(moveRequest(other))
        self._init(<DynamicStruct_Builder>deref(self.thisptr_child), parent)
        self.is_consumed = False
        return self

    def __dealloc__(self):
        del self.thisptr_child

    cpdef send(self):
        if self.is_consumed:
            raise KjException('Request has already been sent. You can only send a request once.')
        self.is_consumed = True
        return _RemotePromise()._init(self.thisptr_child.send(), self._parent)

cdef class _Response(_DynamicStructReader):
    cdef Response * thisptr_child

    cdef _init_child(self, Response other, parent):
        self.thisptr_child = new Response(moveResponse(other))
        self._init(<C_DynamicStruct.Reader>deref(self.thisptr_child), parent)
        return self

    def __dealloc__(self):
        del self.thisptr_child

    cdef _init_childptr(self, Response * other, parent):
        self.thisptr_child = other
        self._init(<C_DynamicStruct.Reader>deref(self.thisptr_child), parent)
        return self

cdef class _DynamicCapabilityServer:
    cdef public _InterfaceSchema schema
    cdef public object server

    def __init__(self, schema, server):
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        self.schema = s
        self.server = server

    def __getattr__(self, field):
        try:
            return getattr(self.server, field)
        except KjException as e:
            raise e._to_python(), None, _sys.exc_info()[2]

cdef class _DynamicCapabilityClient:
    cdef C_DynamicCapability.Client thisptr
    cdef public object _server, _parent, _cached_schema

    cdef _init(self, C_DynamicCapability.Client other, object parent):
        self.thisptr = other
        self._parent = parent
        return self

    cdef _init_vals(self, schema, server):
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        self.thisptr = helpers.new_client(s.thisptr, <PyObject *>server)
        self._server = server
        return self

    cpdef _find_method_args(self, method_name):
        s = self.schema
        meth = s.methods_inherited.get(method_name, None)
        if meth is None:
            raise AttributeError("Method named %s not found." % method_name)

        params = meth.param_type.node
        if params.scopeId != 0:
            raise KjException("Cannot call method `%s` with positional args, since its param struct is not implicitly defined and thus does not have a set order of arguments" % method_name)

        return _find_field_order(params.struct)

    cdef _set_fields(self, Request * request, name, args, kwargs):
        if args is not None and len(args) > 0:
            arg_names = self._find_method_args(name)
            if len(args) > len(arg_names):
                raise KjException('Too many arguments passed to `%s`. Expected %d and got %d' % (name, len(arg_names), len(args)))
            for arg_name, arg_val in zip(arg_names, args):
                _setDynamicField(<DynamicStruct_Builder>deref(request), arg_name, arg_val, self)

        if kwargs is not None:
            for key, val in kwargs.items():
                _setDynamicField(<DynamicStruct_Builder>deref(request), key, val, self)

    cpdef _send_helper(self, name, word_count, args, kwargs) except +reraise_kj_exception:
        # if word_count is None:
        #     word_count = 0
        cdef Request * request = new Request(self.thisptr.newRequest(name)) # TODO: pass word_count

        self._set_fields(request, name, args, kwargs)

        return _RemotePromise()._init(request.send(), self)

    cpdef _request_helper(self, name, firstSegmentWordSize, args, kwargs) except +reraise_kj_exception:
        # if word_count is None:
        #     word_count = 0
        cdef _Request req = _Request()._init_child(self.thisptr.newRequest(name), self)

        self._set_fields(req.thisptr_child, name, args, kwargs)

        return req

    def _request(self, name, *args, word_count=None, **kwargs):
        return self._request_helper(name, word_count, args, kwargs)

    def _send(self, name, *args, word_count=None, **kwargs):
        return self._send_helper(name, word_count, args, kwargs)

    def __getattr__(self, name):
        try:
            if name.endswith('_request'):
                short_name = name[:-8]
                if short_name not in self.schema.method_names_inherited:
                    raise AttributeError('Method named %s not found' % short_name)
                return _partial(self._request, short_name)

            if name not in self.schema.method_names_inherited:
                raise AttributeError('Method named %s not found' % name)
            return _partial(self._send, name)
        except KjException as e:
            raise e._to_python(), None, _sys.exc_info()[2]

    cpdef upcast(self, schema) except +reraise_kj_exception:
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicCapabilityClient()._init(self.thisptr.upcast(s.thisptr), self._parent)

    cpdef cast_as(self, schema) except +reraise_kj_exception:
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema
        return _DynamicCapabilityClient()._init(self.thisptr.castAs(s.thisptr), self._parent)

    property schema:
        """A property that returns the _InterfaceSchema object matching this client"""
        def __get__(self):
            if self._cached_schema is None:
                self._cached_schema = _InterfaceSchema()._init(self.thisptr.getSchema())
            return self._cached_schema

    def __dir__(self):
        return list(set(self.schema.method_names_inherited) + tuple(dir(self.__class__)))

cdef class _CapabilityClient:
    cdef C_Capability.Client * thisptr
    cdef public object _parent

    cdef _init(self, C_Capability.Client other, object parent):
        self.thisptr = new C_Capability.Client(other)
        self._parent = parent
        return self

    def __dealloc__(self):
        del self.thisptr

    cpdef cast_as(self, schema):
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema
        return _DynamicCapabilityClient()._init(self.thisptr.castAs(s.thisptr), self._parent)

cdef class _TwoPartyVatNetwork:
    cdef Own[C_TwoPartyVatNetwork] thisptr
    cdef _AsyncIoStream stream

    cdef _init(self, _AsyncIoStream stream, Side side, schema_cpp.ReaderOptions opts):
        self.stream = stream
        self.thisptr = makeTwoPartyVatNetwork(deref(stream.thisptr), side, opts)
        return self

    cdef _init_pipe(self, _TwoWayPipe pipe, Side side, schema_cpp.ReaderOptions opts):
        self.thisptr = makeTwoPartyVatNetwork(deref(pipe._pipe.ends[0]), side, opts)
        return self

    cpdef on_disconnect(self) except +reraise_kj_exception:
        return _VoidPromise()._init(deref(self.thisptr).onDisconnect(), self)

cdef class TwoPartyClient:
    cdef RpcSystem * thisptr
    cdef public _TwoPartyVatNetwork _network
    cdef public object _orig_stream
    cdef public _AsyncIoStream _stream
    cdef public _TwoWayPipe _pipe

    def __init__(self, socket=None, traversal_limit_in_words=None, nesting_limit=None):
        if isinstance(socket, basestring):
            socket = self._connect(socket)

        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._orig_stream = socket
        if self._orig_stream:
            self._stream = _FdAsyncIoStream(socket.fileno())
            self._network = _TwoPartyVatNetwork()._init(self._stream, capnp.CLIENT, opts)
        else:
            # Initialize TwoWayPipe, to use pipe() acquire other end of the pipe using read() and write() methods
            self._pipe = _TwoWayPipe()
            self._network = _TwoPartyVatNetwork()._init_pipe(self._pipe, capnp.CLIENT, opts)

        self.thisptr = new RpcSystem(makeRpcClient(deref(self._network.thisptr)))
        if self._orig_stream:
            Py_INCREF(self._orig_stream)
            Py_INCREF(self._stream)
        else:
            Py_INCREF(self._pipe)
        Py_INCREF(self._network) # TODO:MEMORY: attach this to onDrained, also figure out what's leaking

    async def read(self, bufsize):
        cdef AsyncIoStreamReadHelper *reader = new AsyncIoStreamReadHelper(
            self._pipe._pipe.ends[1].get(),
            &self._pipe._event_loop.thisptr.waitScope,
            bufsize
        )
        while not reader.poll():
            await asyncio.sleep(0.01)

        cdef array.array read_buffer = array.array('b', [])
        array.resize(read_buffer, reader.read_size())
        memcpy(read_buffer.data.as_voidptr, reader.read_buffer(), reader.read_size())
        del reader
        return read_buffer

    def write(self, data):
        cdef array.array write_buffer = array.array('b', data)
        deref(self._pipe._pipe.ends[1]).write(
            write_buffer.data.as_voidptr,
            len(data)
        ).wait(self._pipe._event_loop.thisptr.waitScope)

    def __dealloc__(self):
        del self.thisptr

    cpdef _connect(self, host_string):
        if host_string.startswith('unix:'):
            path = host_string[5:]
            sock = _socket.socket(_socket.AF_UNIX, _socket.SOCK_STREAM)
            sock.connect(path)
        else:
            host, port = host_string.split(':')

            sock = _socket.create_connection((host, port))

            # Set TCP_NODELAY on socket to disable Nagle's algorithm. This is not
            # neccessary, but it speeds things up.
            sock.setsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, 1)
        return sock

    cpdef bootstrap(self) except +reraise_kj_exception:
        return _CapabilityClient()._init(helpers.bootstrapHelper(deref(self.thisptr)), self)

    cpdef on_disconnect(self) except +reraise_kj_exception:
        return _VoidPromise()._init(deref(self._network.thisptr).onDisconnect())

cdef class TwoPartyServer:
    cdef RpcSystem * thisptr
    cdef public _TwoPartyVatNetwork _network
    cdef public object _orig_stream, _server_socket, _disconnect_promise
    cdef public _AsyncIoStream _stream
    cdef public _TwoWayPipe _pipe
    cdef object _port
    cdef public object port_promise, _bootstrap
    cdef capnp.TaskSet * _task_set
    cdef capnp.ErrorHandler _error_handler

    def __init__(self, socket=None, server_socket=None, bootstrap=None,
                 traversal_limit_in_words=None, nesting_limit=None):
        if not bootstrap:
            raise KjException("You must provide a bootstrap interface to a server constructor.")

        cdef _InterfaceSchema schema
        self._bootstrap = None

        if isinstance(socket, basestring):
            self._connect(socket, bootstrap, traversal_limit_in_words, nesting_limit)
            return

        self._orig_stream = socket
        if self._orig_stream:
            self._stream = _FdAsyncIoStream(socket.fileno())
            self._network = _TwoPartyVatNetwork()._init(self._stream, capnp.SERVER, make_reader_opts(traversal_limit_in_words, nesting_limit))
        else:
            # Initialize TwoWayPipe, to use pipe() acquire other end of the pipe using read() and write() methods
            self._pipe = _TwoWayPipe()
            self._network = _TwoPartyVatNetwork()._init_pipe(self._pipe, capnp.SERVER, make_reader_opts(traversal_limit_in_words, nesting_limit))

        self._server_socket = server_socket
        self._port = 0

        if bootstrap:
            self._bootstrap = bootstrap
            schema = bootstrap.schema
            self.thisptr = new RpcSystem(makeRpcServerBootstrap(deref(self._network.thisptr), helpers.server_to_client(schema.thisptr, <PyObject *>bootstrap)))

        Py_INCREF(self._orig_stream)
        Py_INCREF(self._stream)
        Py_INCREF(self._pipe)
        Py_INCREF(self._bootstrap)
        Py_INCREF(self._network)
        self._disconnect_promise = self.on_disconnect().then(self._decref)

    async def read(self, bufsize):
        cdef AsyncIoStreamReadHelper *reader = new AsyncIoStreamReadHelper(
            self._pipe._pipe.ends[1].get(),
            &self._pipe._event_loop.thisptr.waitScope,
            bufsize
        )
        while not reader.poll():
            await asyncio.sleep(0.01)

        cdef array.array read_buffer = array.array('b', [])
        array.resize(read_buffer, reader.read_size())
        memcpy(read_buffer.data.as_voidptr, reader.read_buffer(), reader.read_size())
        del reader
        return read_buffer

    async def write(self, data):
        cdef array.array write_buffer = array.array('b', data)
        deref(self._pipe._pipe.ends[1]).write(
            write_buffer.data.as_voidptr,
            len(data)
        ).wait(self._pipe._event_loop.thisptr.waitScope)

    cpdef _connect(self, host_string, bootstrap, traversal_limit_in_words, nesting_limit):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)
        cdef _InterfaceSchema schema
        cdef _EventLoop loop = C_DEFAULT_EVENT_LOOP_GETTER()
        cdef capnp.StringPtr temp_string = capnp.StringPtr(<char*>host_string, len(host_string))
        self._task_set = new capnp.TaskSet(self._error_handler)

        self._bootstrap = bootstrap
        Py_INCREF(self._bootstrap)
        schema = bootstrap.schema
        self.port_promise = _Promise()._init(helpers.connectServer(deref(self._task_set), helpers.server_to_client(schema.thisptr, <PyObject *>bootstrap), loop.thisptr, temp_string, opts))

    def _decref(self):
        Py_DECREF(self._bootstrap)
        Py_INCREF(self._pipe)
        Py_DECREF(self._orig_stream)
        Py_DECREF(self._stream)
        Py_DECREF(self._network)

    def __dealloc__(self):
        del self.thisptr
        del self._task_set

    cpdef on_disconnect(self) except +reraise_kj_exception:
        return _VoidPromise()._init(deref(self._network.thisptr).onDisconnect())

    def poll_once(self):
        return poll_once()

    async def poll_forever(self):
        while True:
            poll_once()
            await asyncio.sleep(0.01)

    cpdef run_forever(self):
        if self.port_promise is None:
            raise KjException("You must pass a string as the socket parameter in __init__ to use this function")

        wait_forever()

    cpdef bootstrap(self) except +reraise_kj_exception:
        return _CapabilityClient()._init(helpers.bootstrapHelperServer(deref(self.thisptr)), self)

    property port:
        def __get__(self):
            if self._port is None:
                self._port = self.port_promise.wait()
                return self._port
            else:
                return self._port

cdef class _AsyncIoStream:
    cdef Own[AsyncIoStream] thisptr

cdef class _TwoWayPipe:
    cdef _EventLoop _event_loop
    cdef TwoWayPipe _pipe

    def __init__(self):
        self._init()

    cpdef _init(self) except +reraise_kj_exception:
        self._event_loop = C_DEFAULT_EVENT_LOOP_GETTER()
        # Create two way pipe using AsyncIoContext
        self._pipe = self._event_loop.makeTwoWayPipe()

cdef class _FdAsyncIoStream(_AsyncIoStream):
    cdef _EventLoop _event_loop

    def __init__(self, int fd):
        self._init(fd)

    cdef _init(self, int fd) except +reraise_kj_exception:
        self._event_loop = C_DEFAULT_EVENT_LOOP_GETTER()
        self.thisptr = self._event_loop.wrapSocketFd(fd)

cdef class PyAsyncIoStream(_AsyncIoStream):
    def __init__(self, int fd):
        pass

cdef class PromiseFulfillerPair:
    cdef Own[C_PromiseFulfillerPair] thisptr
    cdef public bint is_consumed
    cdef public _VoidPromise promise

    def __init__(self):
        self.thisptr = copyPromiseFulfillerPair(newPromiseAndFulfiller())
        self.is_consumed = False
        self.promise = _VoidPromise()._init(moveVoidPromise(deref(self.thisptr).promise))

    cpdef fulfill(self):
        deref(deref(self.thisptr).fulfiller).fulfill()

cdef class _Schema:
    cdef _init(self, C_Schema other):
        self.thisptr = other
        return self

    cpdef as_const_value(self):
        return to_python_reader(<C_DynamicValue.Reader>self.thisptr.asConst(), self)

    cpdef as_struct(self):
        return _StructSchema()._init(self.thisptr.asStruct())

    cpdef as_interface(self):
        return _InterfaceSchema()._init(self.thisptr.asInterface())

    cpdef as_enum(self):
        return _EnumSchema()._init(self.thisptr.asEnum())

    cpdef get_proto(self):
        return _NodeReader().init(self.thisptr.getProto())

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

cdef class _StructSchema:
    cdef C_StructSchema thisptr
    cdef object __fieldnames, __union_fields, __non_union_fields, __fields, __getters
    cdef list __fields_list
    cdef _init(self, C_StructSchema other):
        self.thisptr = other
        self.__fieldnames = None
        self.__union_fields = None
        self.__non_union_fields = None
        self.__fields = None
        self.__fields_list = None
        self.__getters = None
        return self

    property fieldnames:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__fieldnames is not None:
               return self.__fieldnames
            fieldlist = self.thisptr.getFields()
            nfields = fieldlist.size()
            self.__fieldnames = tuple(<char*>fieldlist[i].getProto().getName().cStr()
                                      for i in xrange(nfields))
            return self.__fieldnames

    property union_fields:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__union_fields is not None:
               return self.__union_fields
            fieldlist = self.thisptr.getUnionFields()
            nfields = fieldlist.size()
            self.__union_fields = tuple(<char*>fieldlist[i].getProto().getName().cStr()
                                      for i in xrange(nfields))
            return self.__union_fields

    property non_union_fields:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__non_union_fields is not None:
               return self.__non_union_fields
            fieldlist = self.thisptr.getNonUnionFields()
            nfields = fieldlist.size()
            self.__non_union_fields = tuple(<char*>fieldlist[i].getProto().getName().cStr()
                                      for i in xrange(nfields))
            return self.__non_union_fields

    property fields:
        """All of the _StructSchemaField in this schema as a dict"""
        def __get__(self):
            if self.__fields is not None:
               return self.__fields
            fieldlist = self.thisptr.getFields()
            nfields = fieldlist.size()
            self.__fields = {<char*>fieldlist[i].getProto().getName().cStr() : _StructSchemaField()._init(fieldlist[i], self)
                                      for i in xrange(nfields)}
            return self.__fields

    property fields_list:
        """All of the _StructSchemaField in this schema as a list"""
        def __get__(self):
            if self.__fields_list is not None:
               return self.__fields_list
            fieldlist = self.thisptr.getFields()
            nfields = fieldlist.size()
            self.__fields_list = [_StructSchemaField()._init(fieldlist[i], self)
                                      for i in xrange(nfields)]
            return self.__fields_list

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

    def __richcmp__(_StructSchema self, _StructSchema other, mode):
        if mode == 2:
            return self.thisptr == other.thisptr
        elif mode == 3:
            return not (self.thisptr == other.thisptr)
        else:
            raise NotImplementedError()

    def __repr__(self):
        return '<schema for %s>' % self.node.displayName

cdef typeAsSchema(capnp.SchemaType fieldType):
    # TODO(soon): make sure this is memory safe
    if fieldType.isInterface():
        return _InterfaceSchema()._init(fieldType.asInterface())
    elif fieldType.isStruct():
        return _StructSchema()._init(fieldType.asStruct())
    elif fieldType.isEnum():
        return _EnumSchema()._init(fieldType.asEnum())
    elif fieldType.isList():
        return ListSchema()._init(fieldType.asList())
    else:
        raise KjException("Schema type is unknown")

cdef class _StructSchemaField:
    cdef _init(self, C_StructSchema.Field other, parent=None):
        self.thisptr = other
        self._parent = parent
        return self

    property proto:
        """The raw schema proto"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

    property schema:
        """The schema of this field, or None if it's a type without a schema"""
        def __get__(self):
            return typeAsSchema(self.thisptr.getType())

    def __repr__(self):
        return '<field schema for %s>' % self.proto.name

cdef class _InterfaceMethod:
    cdef C_InterfaceSchema.Method thisptr

    cdef _init(self, C_InterfaceSchema.Method other):
        self.thisptr = other
        return self

    property param_type:
        """The type of this method's parameter struct"""
        def __get__(self):
            # TODO(soon): make sure this is memory safe
            return _StructSchema()._init(self.thisptr.getParamType())

    property result_type:
        """The type of this method's result struct"""
        def __get__(self):
            # TODO(soon): make sure this is memory safe
            return _StructSchema()._init(self.thisptr.getResultType())

cdef class _InterfaceSchema:
    cdef _init(self, C_InterfaceSchema other):
        self.thisptr = other
        return self

    property method_names:
        """A tuple of the function names in the interface."""
        def __get__(self):
            if self.__method_names is not None:
               return self.__method_names
            fieldlist = self.thisptr.getMethods()
            nfields = fieldlist.size()
            self.__method_names = tuple(<char*>fieldlist[i].getProto().getName().cStr()
                                      for i in xrange(nfields))
            return self.__method_names

    property method_names_inherited:
        """A set of the function names in the interface, including inherited methods"""
        def __get__(self):
            if self.__method_names_inherited is not None:
               return self.__method_names_inherited

            fieldlist = self.thisptr.getMethods()
            nfields = fieldlist.size()
            self.__method_names_inherited = set(<char*>fieldlist[i].getProto().getName().cStr()
                                      for i in xrange(nfields))
            for interface in self.superclasses:
                self.__method_names_inherited |= interface.method_names_inherited

            return self.__method_names_inherited

    property methods:
        """A mapping of method names to their respective _InterfaceMethod"""
        def __get__(self):
            if self.__methods is not None:
               return self.__methods

            fieldlist = self.thisptr.getMethods()
            nfields = fieldlist.size()
            # TODO(soon): make sure this is memory safe
            self.__methods = {fieldlist[i].getProto().getName().cStr() : _InterfaceMethod()._init(fieldlist[i])
                                      for i in xrange(nfields)}
            return self.__methods

    property methods_inherited:
        """A mapping of method names to their respective _InterfaceMethod, including inherited methods"""
        def __get__(self):
            if self.__methods_inherited is not None:
               return self.__methods_inherited

            fieldlist = self.thisptr.getMethods()
            nfields = fieldlist.size()
            # TODO(soon): make sure this is memory safe
            self.__methods_inherited = {fieldlist[i].getProto().getName().cStr() : _InterfaceMethod()._init(fieldlist[i])
                                      for i in xrange(nfields)}
            for interface in self.superclasses:
                self.__methods_inherited.update(interface.methods_inherited)

            return self.__methods_inherited

    property superclasses:
        """A list of superclasses for this interface"""
        def __get__(self):
            cdef C_InterfaceSchema.SuperclassList classes = self.thisptr.getSuperclasses()
            return [_InterfaceSchema()._init(classes[i]) for i in range(classes.size())]

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

    def __repr__(self):
        return '<schema for %s>' % self.node.displayName

cdef class _EnumSchema:
    cdef C_EnumSchema thisptr

    cdef _init(self, C_EnumSchema other):
        self.thisptr = other
        return self

    property enumerants:
        """The list of enumerants as a dictionary"""
        def __get__(self):
            ret = {}
            enumerants = self.thisptr.getEnumerants()
            for i in range(enumerants.size()):
                enumerant = enumerants[i]
                ret[<char *>enumerant.getProto().getName().cStr()] = enumerant.getOrdinal()

            return ret

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

cdef class _SchemaType:
    cdef capnp.SchemaType thisptr

types = _ModuleType('capnp.types')
cdef _SchemaType _void = _SchemaType()
_void.thisptr = capnp.SchemaType(capnp.TypeWhichVOID)
types.Void = _void

cdef _SchemaType _bool = _SchemaType()
_bool.thisptr = capnp.SchemaType(capnp.TypeWhichBOOL)
types.Bool = _bool

cdef _SchemaType _int8 = _SchemaType()
_int8.thisptr = capnp.SchemaType(capnp.TypeWhichINT8)
types.Int8 = _int8

cdef _SchemaType _int16 = _SchemaType()
_int16.thisptr = capnp.SchemaType(capnp.TypeWhichINT16)
types.Int16 = _int16

cdef _SchemaType _int32 = _SchemaType()
_int32.thisptr = capnp.SchemaType(capnp.TypeWhichINT32)
types.Int32 = _int32

cdef _SchemaType _int64 = _SchemaType()
_int64.thisptr = capnp.SchemaType(capnp.TypeWhichINT64)
types.Int64 = _int64

cdef _SchemaType _uint8 = _SchemaType()
_uint8.thisptr = capnp.SchemaType(capnp.TypeWhichUINT8)
types.UInt8 = _uint8

cdef _SchemaType _uint16 = _SchemaType()
_uint16.thisptr = capnp.SchemaType(capnp.TypeWhichUINT16)
types.UInt16 = _uint16

cdef _SchemaType _uint32 = _SchemaType()
_uint32.thisptr = capnp.SchemaType(capnp.TypeWhichUINT32)
types.UInt32 = _uint32

cdef _SchemaType _uint64 = _SchemaType()
_uint64.thisptr = capnp.SchemaType(capnp.TypeWhichUINT64)
types.UInt64 = _uint64

cdef _SchemaType _float32 = _SchemaType()
_float32.thisptr = capnp.SchemaType(capnp.TypeWhichFLOAT32)
types.Float32 = _float32

cdef _SchemaType _float64 = _SchemaType()
_float64.thisptr = capnp.SchemaType(capnp.TypeWhichFLOAT64)
types.Float64 = _float64

cdef _SchemaType _text = _SchemaType()
_text.thisptr = capnp.SchemaType(capnp.TypeWhichTEXT)
types.Text = _text

cdef _SchemaType _data = _SchemaType()
_data.thisptr = capnp.SchemaType(capnp.TypeWhichDATA)
types.Data = _data

# cdef _SchemaType _list = _SchemaType()
# _list.thisptr = capnp.SchemaType(capnp.TypeWhichLIST)
# types.list = _list

# cdef _SchemaType _enum = _SchemaType()
# _enum.thisptr = capnp.SchemaType(capnp.TypeWhichENUM)
# types.Enum = _enum

# cdef _SchemaType _struct = _SchemaType()
# _struct.thisptr = capnp.SchemaType(capnp.TypeWhichSTRUCT)
# types.struct = _struct

# cdef _SchemaType _interface = _SchemaType()
# _interface.thisptr = capnp.SchemaType(capnp.TypeWhichINTERFACE)
# types.interface = _interface

cdef _SchemaType _any_pointer = _SchemaType()
_any_pointer.thisptr = capnp.SchemaType(capnp.TypeWhichANY_POINTER)
types.AnyPointer = _any_pointer

cdef class ListSchema:
    cdef C_ListSchema thisptr

    def __init__(self, schema=None):
        cdef _StructSchema ss
        cdef _EnumSchema es
        cdef _InterfaceSchema iis
        cdef ListSchema ls
        cdef _SchemaType st

        if schema is not None:
            if hasattr(schema, 'schema'):
                s = schema.schema
            else:
                s = schema

            typeSchema = type(s)
            if typeSchema is _StructSchema:
                ss = s
                self.thisptr = capnp.listSchemaOfStruct(ss.thisptr)
            elif typeSchema is _EnumSchema:
                es = s
                self.thisptr = capnp.listSchemaOfEnum(es.thisptr)
            elif typeSchema is _InterfaceSchema:
                iis = s
                self.thisptr = capnp.listSchemaOfInterface(iis.thisptr)
            elif typeSchema is ListSchema:
                ls = s
                self.thisptr = capnp.listSchemaOfList(ls.thisptr)
            elif typeSchema is _SchemaType:
                st = s
                self.thisptr = capnp.listSchemaOfType(st.thisptr)
            else:
                raise KjException("Unknown schema type")

    cdef _init(self, C_ListSchema other):
        self.thisptr = other
        return self

    property elementType:
        """The schema of the element type of this list"""
        def __get__(self):
            return typeAsSchema(self.thisptr.getElementType())

cdef class _ParsedSchema(_Schema):
    cdef C_ParsedSchema thisptr_child
    cdef _init_child(self, C_ParsedSchema other):
        self.thisptr_child = other
        self._init(other)
        return self

    cpdef get_nested(self, name):
        return _ParsedSchema()._init_child(self.thisptr_child.getNested(name))

class _StructABCMeta(type):
    """A metaclass for the Type.Reader and Type.Builder ABCs."""
    def __instancecheck__(cls, obj):
        return isinstance(obj, cls.__base__) and obj.schema == cls._schema

cdef _new_message(self, kwargs, num_first_segment_words):
    builder = _MallocMessageBuilder(num_first_segment_words)
    msg = builder.init_root(self.schema)
    if kwargs is not None:
        msg.from_dict(kwargs)
    return msg

class _StructModuleWhich(object):
    pass

class _StructModule(object):
    def __init__(self, schema, name):
        self.schema = schema

        # Add enums for union fields
        for field, raw_field in zip(schema.node.struct.fields, schema.fields_list):
            if field.which() == 'group':
                name = field.name[0].upper() + field.name[1:]
                raw_schema = raw_field.schema
                field_schema = raw_schema.node.struct

                if field_schema.discriminantCount == 0:
                    sub_module = _StructModule(raw_schema, name)
                else:
                    sub_module = _StructModuleWhich()
                    setattr(sub_module, 'schema', raw_schema)
                    for union_field in field_schema.fields:
                        setattr(sub_module, union_field.name, union_field.discriminantValue)
                setattr(self, name, sub_module)

    def read(self, file, traversal_limit_in_words = None, nesting_limit = None):
        """Returns a Reader for the unpacked object read from file.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`"""
        reader = _StreamFdMessageReader(file, traversal_limit_in_words, nesting_limit)
        return reader.get_root(self.schema)
    def read_multiple(self, file, traversal_limit_in_words = None, nesting_limit = None, skip_copy = False):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type skip_copy: bool
        :param skip_copy: By default, each message is copied because the file needs to advance, even if the message is never read completely. Skip this only if you know what you're doing.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultipleMessageReader(file, self.schema, traversal_limit_in_words, nesting_limit, skip_copy)
        return reader
    def read_packed(self, file, traversal_limit_in_words = None, nesting_limit = None):
        """Returns a Reader for the packed object read from file.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`"""
        reader = _PackedFdMessageReader(file, traversal_limit_in_words, nesting_limit)
        return reader.get_root(self.schema)
    def read_multiple_packed(self, file, traversal_limit_in_words = None, nesting_limit = None, skip_copy = False):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type skip_copy: bool
        :param skip_copy: By default, each message is copied because the file needs to advance, even if the message is never read completely. Skip this only if you know what you're doing.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultiplePackedMessageReader(file, self.schema, traversal_limit_in_words, nesting_limit, skip_copy)
        return reader
    def read_multiple_bytes(self, buf, traversal_limit_in_words = None, nesting_limit = None):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultipleBytesMessageReader(buf, self.schema, traversal_limit_in_words, nesting_limit)
        return reader
    def read_multiple_bytes_packed(self, buf, traversal_limit_in_words = None, nesting_limit = None):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultipleBytesPackedMessageReader(buf, self.schema, traversal_limit_in_words, nesting_limit)
        return reader
    def from_bytes(self, buf, traversal_limit_in_words = None, nesting_limit = None, builder=False):
        """Returns a Reader for the unpacked object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type builder: bool
        :param builder: If true, return a builder object. This will allow you to change the contents of `buf`, so do this with care.

        :rtype: :class:`_DynamicStructReader` or :class:`_DynamicStructBuilder`
        """
        if builder:
            # message = _FlatMessageBuilder(buf)
            message = _FlatArrayMessageReader(buf, traversal_limit_in_words, nesting_limit)
            return message.get_root(self.schema).as_builder()
        else:
            message = _FlatArrayMessageReader(buf, traversal_limit_in_words, nesting_limit)
            return message.get_root(self.schema)
    def from_segments(self, segments, traversal_limit_in_words = None, nesting_limit = None):
        """Returns a Reader for a list of segment bytes.

        This avoids making copies.

        NB: This is not currently supported on PyPy.

        :rtype: list
        """
        message = _SegmentArrayMessageReader(segments, traversal_limit_in_words, nesting_limit)
        return message.get_root(self.schema)
    def from_bytes_packed(self, buf, traversal_limit_in_words = None, nesting_limit = None):
        """Returns a Reader for the packed object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the readable buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`
        """
        return _PackedMessageReaderBytes(buf, traversal_limit_in_words, nesting_limit).get_root(self.schema)
    def __call__(self, num_first_segment_words=None, **kwargs):
        return self.new_message(num_first_segment_words=num_first_segment_words, **kwargs)
    def new_message(self, num_first_segment_words=None, **kwargs):
        """Returns a newly allocated builder message.

        :type num_first_segment_words: int
        :param num_first_segment_words: Size of the first segment to allocate in the message (in words ie. 8 byte increments)

        :type kwargs: dict
        :param kwargs: A list of fields and their values to initialize in the struct. Note, this is not an actual argument, but refers to Python's ability to pass keyword arguments. ie. new_message(my_field=100)

        :rtype: :class:`_DynamicStructBuilder`
        """
        return _new_message(self, kwargs, num_first_segment_words)
    def from_dict(self, kwargs):
        '.. warning:: This method is deprecated and will be removed in the 0.5 release. Use the :meth:`new_message` function instead with **kwargs'
        _warnings.warn('This method is deprecated and will be removed in the 0.5 release. Use the :meth:`new_message` function instead with **kwargs', UserWarning)
        return _new_message(self, kwargs, None)
    def from_object(self, obj):
        '.. warning:: This method is deprecated and will be removed in the 0.5 release. Use the :meth:`_DynamicStructReader.as_builder` or :meth:`_DynamicStructBuilder.copy` functions instead'
        _warnings.warn('This method is deprecated and will be removed in the 0.5 release. Use the :meth:`_DynamicStructReader.as_builder` or :meth:`_DynamicStructBuilder.copy` functions instead', UserWarning)
        builder = _MallocMessageBuilder()
        return builder.set_root(obj)

class _InterfaceModule(object):
    def __init__(self, schema, name):
        def server_init(server_self):
            pass
        self.schema = schema
        self.Server = type(name + '.Server', (_DynamicCapabilityServer,), {'__init__': server_init, 'schema':schema})

    def _new_client(self, server):
        return _DynamicCapabilityClient()._init_vals(self.schema, server)

    def _new_server(self, server):
        return _DynamicCapabilityServer(self.schema, server)

class _EnumModule(object):
    def __init__(self, schema, name):
        self.schema = schema
        for name, val in schema.enumerants.items():
            setattr(self, name, val)

cdef class _StringArrayPtr:
    def __cinit__(self, size_t size, parent):
        self.size = size
        self.thisptr = <StringPtr *>malloc(sizeof(StringPtr) * size)
        self.parent = parent

    def __dealloc__(self):
        free(self.thisptr)

    cdef ArrayPtr[StringPtr] asArrayPtr(self) except +reraise_kj_exception:
        return ArrayPtr[StringPtr](self.thisptr, self.size)


cdef class SchemaParser:
    """A class for loading Cap'n Proto schema files.

    Do not use this class unless you're sure you know what you're doing. Use the convenience method :func:`load` instead.
    """

    def __cinit__(self):
        self.thisptr = new C_SchemaParser()
        self.modules_by_id = {}
        self._all_imports = []

    def __dealloc__(self):
        del self.thisptr

    cpdef _parse_disk_file(self, displayName, diskPath, imports) except +reraise_kj_exception:
        cdef _StringArrayPtr importArray

        if self._last_import_array and self._last_import_array.parent == imports:
            importArray = self._last_import_array
        else:
            importArray = _StringArrayPtr(len(imports), imports)

            for i in range(len(imports)):
                curr_import = imports[i]
                importArray.thisptr[i] = StringPtr(curr_import, <size_t>len(curr_import))

            self._all_imports.append(importArray)
            self._last_import_array = importArray

        ret = _ParsedSchema()
        # TODO (HaaTa): Convert to parseFromDirectory() as per deprecation note
        ret._init_child(self.thisptr.parseDiskFile(displayName, diskPath, importArray.asArrayPtr()))

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
            - :exc:`KjException` if the Cap'n Proto C++ library has any problems loading the schema

        """
        def _load(nodeSchema, module):
            module._nodeSchema = nodeSchema
            nodeProto = nodeSchema.get_proto()
            module._nodeProto = nodeProto

            self.modules_by_id[nodeProto.id] = module

            for node in nodeProto.nestedNodes:
                local_module = _ModuleType(node.name)

                schema = nodeSchema.get_nested(node.name)
                proto = schema.get_proto()
                if proto.isStruct:
                    local_module = _StructModule(schema.as_struct(), node.name)
                    class Reader(_DynamicStructReader):
                        """An abstract base class.  Readers are 'instances' of this class."""
                        __metaclass__ = _StructABCMeta
                        __slots__ = []
                        _schema = local_module.schema
                        def __new__(self):
                            raise TypeError('This is an abstract base class')
                    class Builder(_DynamicStructBuilder):
                        """An abstract base class.  Builders are 'instances' of this class."""
                        __metaclass__ = _StructABCMeta
                        __slots__ = []
                        _schema = local_module.schema
                        def __new__(self):
                            raise TypeError('This is an abstract base class')

                    local_module.Reader = Reader
                    local_module.Builder = Builder

                    module.__dict__[node.name] = local_module
                elif proto.isConst:
                    module.__dict__[node.name] = schema.as_const_value()
                elif proto.isInterface:
                    local_module = _InterfaceModule(schema.as_interface(), node.name)

                    module.__dict__[node.name] = local_module
                elif proto.isEnum:
                    local_module = _EnumModule(schema.as_enum(), node.name)

                    module.__dict__[node.name] = local_module

                _load(schema, local_module)
        if not _os.path.isfile(file_name):
            raise IOError("File not found: " + file_name)

        if not file_name.endswith('.capnp'):
            raise ValueError("File does not end with .capnp, {}".format(file_name))

        if display_name is None:
            display_name = _os.path.basename(file_name)

        module = _ModuleType(display_name)
        parser = self

        module._parser = parser

        # Some systems (Windows running pytest) add non-directories to the sys.path used for imports
        # Filter these out so kj doesn't implode when searching paths
        filtered_imports = []
        for imp in imports:
            if _os.path.isdir(imp):
                filtered_imports.append(imp)
        fileSchema = parser._parse_disk_file(display_name, file_name, filtered_imports)
        _load(fileSchema, module)

        abs_path = _os.path.abspath(file_name)
        module.__path__ = [_os.path.dirname(abs_path)]
        module.__file__ = abs_path
        module.schema = fileSchema

        return module

cdef class _MessageBuilder:
    """An abstract base class for building Cap'n Proto messages

    .. warning:: Don't ever instantiate this class directly. It is only used for inheritance.
    """
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

    cpdef get_root(self, schema) except +reraise_kj_exception:
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

    cpdef get_root_as_any(self) except +reraise_kj_exception:
        """A method for getting a Cap'n Proto AnyPointer, from an already pre-written buffer

        Don't use this method unless you know what you're doing.

        :rtype: :class:`_DynamicObjectBuilder`
        :return: An AnyPointer that you can set fields in
        """
        return _DynamicObjectBuilder()._init(self.thisptr.getRootAnyPointer(), self)

    cpdef set_root(self, value) except +reraise_kj_exception:
        """A method for instantiating Cap'n Proto structs by copying from an existing struct

        :type value: :class:`_DynamicStructReader`
        :param value: A Cap'n Proto struct value to copy

        :rtype: void
        """
        value_type = type(value)
        if value_type is _DynamicStructBuilder:
            self.thisptr.setRootDynamicStruct((<_DynamicStructReader>value.as_reader()).thisptr)
            return self.get_root(value.schema)
        elif value_type is _DynamicStructReader:
            self.thisptr.setRootDynamicStruct((<_DynamicStructReader>value).thisptr)
            return self.get_root(value.schema)

    cpdef get_segments_for_output(self) except +reraise_kj_exception:
        segments = self.thisptr.getSegmentsForOutput()
        res = []
        cdef const char* ptr
        cdef bytes segment_bytes
        for i in range(0, segments.size()):
            segment = segments[i]
            ptr = <const char *> segment.begin()
            segment_bytes = ptr[:8*segment.size()]
            res.append(segment_bytes)
        return res

    cpdef new_orphan(self, schema) except +reraise_kj_exception:
        """A method for instantiating Cap'n Proto orphans

        Don't use this method unless you know what you're doing. Orphans are useful for dynamically allocating objects for an unknown sized list, ie::

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
    def __init__(self, size=None):
        if size is None:
            self.thisptr = new schema_cpp.MallocMessageBuilder()
        else:
            self.thisptr = new schema_cpp.MallocMessageBuilder(size)

cdef class _MessageReader:
    """An abstract base class for reading Cap'n Proto messages

    .. warning:: Don't ever instantiate this class. It is only used for inheritance.
    """
    cdef public object _parent
    cdef schema_cpp.MessageReader * thisptr

    def __init__(self):
        raise NotImplementedError("This is an abstract base class")

    cpdef get_root(self, schema) except +reraise_kj_exception:
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

    cpdef get_root_as_any(self) except +reraise_kj_exception:
        """A method for getting a Cap'n Proto AnyPointer, from an already pre-written buffer

        Don't use this method unless you know what you're doing.

        :rtype: :class:`_DynamicObjectReader`
        :return: An AnyPointer that you can read from
        """
        return _DynamicObjectReader()._init(self.thisptr.getRootAnyPointer(), self)

cdef class _StreamFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_message_to_fd` and :class:`_MessageBuilder`, but in one class::

        f = open('out.txt')
        message = _StreamFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, file, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = file
        self.thisptr = new schema_cpp.StreamFdMessageReader(file.fileno(), opts)

    def __dealloc__(self):
        del self.thisptr


cdef class _PackedMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self):
        pass

    cdef _init(self, schema_cpp.BufferedInputStream & stream, traversal_limit_in_words = None, nesting_limit = None, parent = None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = parent
        self.thisptr = new schema_cpp.PackedMessageReader(stream, opts)
        return self

    def __dealloc__(self):
        del self.thisptr


cdef class _PackedMessageReaderBytes(_MessageReader):
    cdef schema_cpp.ArrayInputStream * stream
    cdef Py_buffer view

    def __init__(self, buf, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = buf

        if PyObject_GetBuffer(buf, &self.view, PyBUF_SIMPLE) != 0:
            raise KjException("could not get read buffer")

        self.stream = new schema_cpp.ArrayInputStream(schema_cpp.ByteArrayPtr(<byte *>self.view.buf, self.view.len))

        self.thisptr = new schema_cpp.PackedMessageReader(deref(self.stream), opts)

    def __dealloc__(self):
        del self.thisptr
        del self.stream
        PyBuffer_Release(&self.view)

cdef class _InputMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self):
        pass

    cdef _init(self, schema_cpp.BufferedInputStream & stream, traversal_limit_in_words = None, nesting_limit = None, parent = None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = parent
        self.thisptr = new schema_cpp.InputStreamMessageReader(stream, opts)
        return self

    def __dealloc__(self):
        del self.thisptr


cdef class _PackedFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, file, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = file
        self.thisptr = new schema_cpp.PackedFdMessageReader(file.fileno(), opts)

    def __dealloc__(self):
        del self.thisptr


cdef class _MultipleMessageReader:
    cdef schema_cpp.FdInputStream * stream
    cdef schema_cpp.BufferedInputStream * buffered_stream
    cdef cbool skip_copy

    cdef public object traversal_limit_in_words, nesting_limit, schema, file

    def __init__(self, file, schema, traversal_limit_in_words = None, nesting_limit = None, skip_copy = False):
        self.file = file
        self.schema = schema
        self.traversal_limit_in_words = traversal_limit_in_words
        self.nesting_limit = nesting_limit
        self.skip_copy = skip_copy

        self.stream = new schema_cpp.FdInputStream(file.fileno())
        self.buffered_stream = new schema_cpp.BufferedInputStreamWrapper(deref(self.stream))

    def __dealloc__(self):
        del self.stream
        del self.buffered_stream

    def __next__(self):
        try:
            reader = _InputMessageReader()._init(deref(self.buffered_stream), self.traversal_limit_in_words, self.nesting_limit, self)
            ret = reader.get_root(self.schema)
            if not self.skip_copy:
              ret = ret.as_builder().as_reader()
            return ret
        except KjException as e:
            if 'EOF' in str(e):
                raise StopIteration
            else:
                raise

    def __iter__(self):
        return self

cdef class _MultiplePackedMessageReader:
    cdef schema_cpp.FdInputStream * stream
    cdef schema_cpp.BufferedInputStream * buffered_stream
    cdef cbool skip_copy

    cdef public object traversal_limit_in_words, nesting_limit, schema, file

    def __init__(self, file, schema, traversal_limit_in_words = None, nesting_limit = None, skip_copy = False):
        self.file = file
        self.schema = schema
        self.traversal_limit_in_words = traversal_limit_in_words
        self.nesting_limit = nesting_limit
        self.skip_copy = skip_copy

        self.stream = new schema_cpp.FdInputStream(file.fileno())
        self.buffered_stream = new schema_cpp.BufferedInputStreamWrapper(deref(self.stream))

    def __dealloc__(self):
        del self.stream
        del self.buffered_stream

    def __next__(self):
        try:
            reader = _PackedMessageReader()._init(deref(self.buffered_stream), self.traversal_limit_in_words, self.nesting_limit, self)
            ret = reader.get_root(self.schema)
            if not self.skip_copy:
              ret = ret.as_builder().as_reader()
            return ret
        except KjException as e:
            if 'EOF' in str(e):
                raise StopIteration
            else:
                raise

    def __iter__(self):
        return self

cdef class _MultipleBytesMessageReader:
    cdef Py_ssize_t offset, sz
    cdef const char *ptr
    cdef object _object_to_pin
    cdef public object traversal_limit_in_words, nesting_limit, schema

    def __init__(self, buf, schema, traversal_limit_in_words = None, nesting_limit = None):
        self.offset = 0
        self.schema = schema
        self.traversal_limit_in_words = traversal_limit_in_words
        self.nesting_limit = nesting_limit

        self.sz = len(buf)
        if isinstance(buf, bytes):
            self.ptr = buf
            if (<uintptr_t>self.ptr) % 8 != 0:
                aligned = _AlignedBuffer(buf)
                self.ptr = aligned.buf
                self._object_to_pin = aligned
            else:
                self._object_to_pin = buf
                self.ptr = buf
        elif PyObject_CheckBuffer(buf):
            view = _BufferView(buf)
            self.ptr = view.buf
            self._object_to_pin = view
        else:
            raise TypeError('expected buffer-like object in FlatArrayMessageReader')


    def __next__(self):
        cdef _FlatArrayMessageReaderAligned reader
        if self.offset == self.sz:
            raise StopIteration
        try:
            reader = _FlatArrayMessageReaderAligned()
            reader._init(self._object_to_pin, self.ptr + self.offset, self.sz - self.offset, self.traversal_limit_in_words, self.nesting_limit)
            self.offset += reader.msg_size
            return reader.get_root(self.schema)
        except KjException as e:
            if 'EOF' in str(e):
                raise StopIteration
            else:
                raise

    def __iter__(self):
        return self

cdef class _MultipleBytesPackedMessageReader:
    cdef schema_cpp.ArrayInputStream * stream
    cdef schema_cpp.BufferedInputStream * buffered_stream
    cdef Py_buffer view

    cdef public object traversal_limit_in_words, nesting_limit, schema, buf

    def __init__(self, buf, schema, traversal_limit_in_words = None, nesting_limit = None):
        self.schema = schema
        self.traversal_limit_in_words = traversal_limit_in_words
        self.nesting_limit = nesting_limit

        if PyObject_GetBuffer(buf, &self.view, PyBUF_SIMPLE) != 0:
            raise KjException("could not get read buffer")

        self.buf = buf
        self.stream = new schema_cpp.ArrayInputStream(schema_cpp.ByteArrayPtr(<byte *>self.view.buf, self.view.len))
        self.buffered_stream = new schema_cpp.BufferedInputStreamWrapper(deref(self.stream))

    def __dealloc__(self):
        PyBuffer_Release(&self.view)
        del self.buffered_stream
        del self.stream

    def __next__(self):
        try:
            reader = _PackedMessageReader()._init(deref(self.buffered_stream), self.traversal_limit_in_words, self.nesting_limit, self)
            return reader.get_root(self.schema)
        except KjException as e:
            if 'EOF' in str(e):
                raise StopIteration
            else:
                raise

    def __iter__(self):
        return self

@cython.internal
cdef class _AlignedBuffer:
    cdef char * buf
    cdef bint allocated
    cdef Py_buffer view

    # other should also have a length that's a multiple of 8
    def __init__(self, other):
        if PyObject_GetBuffer(other, &self.view, PyBUF_SIMPLE) != 0:
            raise KjException("could not get read buffer")
        other_len = len(other)

        # malloc is defined as being word aligned
        # we don't care about adding NULL terminating character
        self.buf = <char *>malloc(other_len)
        memcpy(self.buf, self.view.buf, other_len)
        self.allocated = True

    def __dealloc__(self):
        if self.allocated:
            free(self.buf)
        PyBuffer_Release(&self.view)


@cython.internal
cdef class _BufferView:
    cdef Py_buffer view
    cdef char * buf

    def __init__(self, other):
        cdef int ret = PyObject_GetBuffer(other, &self.view, PyBUF_SIMPLE)
        if ret < 0:
          raise ValueError("Invalid buffer passed to BufferView")
        self.buf = <char*>self.view.buf

    def __dealloc__(self):
        PyBuffer_Release(&self.view)

@cython.internal
cdef class _FlatArrayMessageReaderAligned(_MessageReader):
    """
    Creates a reader based on a contiguous block of memory

    For performance consideration it's assumed that the provided buffer is already aligned. This
    allows us to align a set of adjacent messages with a single align operation.
    """
    cdef object _object_to_pin
    cdef Py_ssize_t msg_size
    def __init__(self):
        self.msg_size = 0


    cdef _init(self, buf, const char *ptr, Py_ssize_t sz, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)
        cdef schema_cpp.FlatArrayMessageReader * flat_reader

        self._object_to_pin = buf

        flat_reader = new schema_cpp.FlatArrayMessageReader(
            schema_cpp.WordArrayPtr(<schema_cpp.word*>ptr, sz//8),
            opts)
        self.thisptr = flat_reader
        self.msg_size = <char *>flat_reader.getEnd() - ptr
        return self

    def __dealloc__(self):
        del self.thisptr


@cython.internal
cdef class _FlatArrayMessageReader(_MessageReader):
    cdef object _object_to_pin
    def __init__(self, buf, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)
        cdef _AlignedBuffer aligned

        sz = len(buf)
        if sz % 8 != 0:
            raise ValueError("input length must be a multiple of eight bytes")

        cdef char * ptr
        if isinstance(buf, bytes):
            ptr = buf
            if (<uintptr_t>ptr) % 8 != 0:
                aligned = _AlignedBuffer(buf)
                ptr = aligned.buf
                self._object_to_pin = aligned
            else:
                self._object_to_pin = buf
        elif PyObject_CheckBuffer(buf):
            view = _BufferView(buf)
            ptr = view.buf
            self._object_to_pin = view
        else:
            raise TypeError('expected buffer-like object in FlatArrayMessageReader')

        self.thisptr = new schema_cpp.FlatArrayMessageReader(
            schema_cpp.WordArrayPtr(<schema_cpp.word*>ptr, sz//8),
            opts)

    def __dealloc__(self):
        del self.thisptr


@cython.internal
cdef class _SegmentArrayMessageReader(_MessageReader):

    cdef object _objects_to_pin
    cdef schema_cpp.ConstWordArrayPtr* _seg_ptrs
    cdef Py_buffer* views

    def __init__(self, segments, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)
        # take a Python array of bytes and constructs a ConstWordArrayArrayPtr
        num_segments = len(segments)
        cdef schema_cpp.ConstWordArrayPtr seg_ptr
        self._seg_ptrs = <schema_cpp.ConstWordArrayPtr*>malloc(num_segments * sizeof(schema_cpp.ConstWordArrayPtr))
        self.views = <Py_buffer*>malloc(num_segments * sizeof(Py_buffer))
        self._objects_to_pin = []
        for i in range(0, num_segments):
            if PyObject_GetBuffer(segments[i], &self.views[i], PyBUF_SIMPLE) != 0:
                raise KjException("could not get read buffer")

            if (<uintptr_t>self.views[i].buf) % 8 != 0:
                aligned = _AlignedBuffer(segments[i])
                self.views[i].buf = aligned.buf
                self._objects_to_pin.append(aligned)
            else:
                self._objects_to_pin.append(segments[i])
            seg_ptr = schema_cpp.ConstWordArrayPtr(<schema_cpp.word*>self.views[i].buf, self.views[i].len//8)
            self._seg_ptrs[i] = seg_ptr
        self.thisptr = new schema_cpp.SegmentArrayMessageReader(
            schema_cpp.ConstWordArrayArrayPtr(self._seg_ptrs, num_segments),
            opts)

    def __dealloc__(self):
        free(self._seg_ptrs)
        free(self.views)
        del self.thisptr


@cython.internal
cdef class _FlatMessageBuilder(_MessageBuilder):
    cdef object _object_to_pin
    cdef Py_buffer view
    def __init__(self, buf):
        if PyObject_GetBuffer(buf, &self.view, PyBUF_WRITABLE) != 0:
            raise KjException("expected variable length string object")
        if self.view.len % 8 != 0:
            raise KjException("input length must be a multiple of eight bytes")
        self._object_to_pin = buf
        self.thisptr = new schema_cpp.FlatMessageBuilder(schema_cpp.WordArrayPtr(<schema_cpp.word*>self.view.buf, self.view.len//8))

    def __dealloc__(self):
        PyBuffer_Release(&self.view)

def _message_to_packed_bytes(_MessageBuilder message):
    r, w = _os.pipe()

    writer = new schema_cpp.FdOutputStream(w)
    schema_cpp.writePackedMessage(deref(writer), deref(message.thisptr))
    _os.close(w)

    reader = _os.fdopen(r, 'rb')
    ret = reader.read()

    del writer
    reader.close()

    return ret

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
        _StreamFdMessageReader(f)

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
        _PackedFdMessageReader(f)

    :type fd: int
    :param fd: A file descriptor

    :type message: :class:`_MessageBuilder`
    :param message: The Cap'n Proto message to serialize

    :rtype: void
    """
    schema_cpp.writePackedMessageToFd(fd, deref(message.thisptr))

_global_schema_parser = None

def cleanup_global_schema_parser():
    """Unloads all of the schema from the current context"""
    global _global_schema_parser
    if _global_schema_parser:
        del _global_schema_parser
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

    :Raises: :exc:`KjException` if `file_name` doesn't exist

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
        has_underscores = False

        if '_' in capnp_module_name:
            capnp_module_name_dashes = capnp_module_name.replace('_', '-')
            capnp_module_name_spaces = capnp_module_name.replace('_', ' ')
            has_underscores = True

        if package_path:
            paths = list(package_path)
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
            if has_underscores:
                if is_file(path+sep+capnp_module_name_dashes):
                    return _Loader(fullname, join_path(path, capnp_module_name_dashes), self.additional_paths)
                if is_file(path+sep+capnp_module_name_spaces):
                    return _Loader(fullname, join_path(path, capnp_module_name_spaces), self.additional_paths)

_importer = None

def add_import_hook(additional_paths=[]):
    """Add a hook to the python import system, so that Cap'n Proto modules are directly importable

    After calling this function, you can use the python import syntax to directly import capnproto schemas. This function is automatically called upon first import of `capnp`, so you will typically never need to use this function.::

        import capnp
        capnp.add_import_hook()

        import addressbook_capnp
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

def _init_capnp_api():
    """ Initialize static function pointers for cdef api functions. """
    init_capnp_api()
