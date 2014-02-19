# capnp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnpc capnp capnp-rpc
# cython: c_string_type = str
# cython: c_string_encoding = default
# cython: embedsignature = True

cimport cython

from .capnp.helpers.helpers cimport makeRpcClientWithRestorer

from libc.stdlib cimport malloc, free
from cython.operator cimport dereference as deref

from types import ModuleType as _ModuleType
import os as _os
import sys as _sys
import imp as _imp
import traceback as _traceback
from functools import partial as _partial
import warnings as _warnings
import inspect as _inspect
from operator import attrgetter as _attrgetter
import threading as _threading
import socket as _socket
import random as _random

_CAPNP_VERSION_MAJOR = capnp.CAPNP_VERSION_MAJOR
_CAPNP_VERSION_MINOR = capnp.CAPNP_VERSION_MINOR
_CAPNP_VERSION_MICRO = capnp.CAPNP_VERSION_MICRO
_CAPNP_VERSION = capnp.CAPNP_VERSION

# By making it public, we'll be able to call it from capabilityHelper.h
cdef public object wrap_dynamic_struct_reader(Response & r):
    return _Response()._init_childptr(new Response(moveResponse(r)), None)

cdef public PyObject * wrap_remote_call(PyObject * func, Response & r) except *:
    response = _Response()._init_childptr(new Response(moveResponse(r)), None)

    func_obj = <object>func
    ret = func_obj(response)
    Py_INCREF(ret)
    return <PyObject *>ret

cdef _find_field_order(struct_node):
    return [f.name for f in sorted(struct_node.fields, key=_attrgetter('codeOrder'))]

cdef public VoidPromise * call_server_method(PyObject * _server, char * _method_name, CallContext & _context) except *:
    server = <object>_server
    method_name = <object>_method_name

    context = _CallContext()._init(_context) # TODO:MEMORY: invalidate this with promise chain
    func = getattr(server, method_name+'_context', None)
    if func is not None:
        ret = func(context)
        if ret is not None:
            if type(ret) is _VoidPromise:
                return new VoidPromise(moveVoidPromise(deref((<_VoidPromise>ret).thisptr)))
            elif type(ret) is Promise:
                return new VoidPromise(helpers.convert_to_voidpromise(deref((<Promise>ret).thisptr)))
            else:
                try:
                    warning_msg = 'Server function (%s) returned a value that was not a Promise: return = %s' % (method_name, str(ret))
                except:
                    warning_msg = 'Server function (%s) returned a value that was not a Promise' % (method_name)
                _warnings.warn_explicit(warning_msg, UserWarning, _inspect.getsourcefile(func), _inspect.getsourcelines(func)[1])

        if ret is not None:
            if type(ret) is Promise:
                return new VoidPromise(helpers.convert_to_voidpromise(deref((<Promise>ret).thisptr)))
            elif type(ret) is Promise:
                return new VoidPromise(helpers.convert_to_voidpromise(deref((<Promise>ret).thisptr)))
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
            elif type(ret) is Promise:
                return new VoidPromise(helpers.convert_to_voidpromise(deref((<Promise>ret).thisptr)))
            if not isinstance(ret, tuple):
                ret = (ret,)
            names = _find_field_order(context.results.schema.node.struct)
            if len(ret) > len(names):
                raise ValueError('Too many values returned from `%s`. Expected %d and got %d' % (method_name, len(names), len(ret)))

            results = context.results
            for arg_name, arg_val in zip(names, ret):
                setattr(results, arg_name, arg_val)

    return NULL
    
cdef public C_Capability.Client * call_py_restorer(PyObject * _restorer, C_DynamicObject.Reader & _reader) except *:
    restorer = <object>_restorer
    reader = _DynamicObjectReader()._init(_reader, None)

    ret = restorer._restore(reader)
    cdef _DynamicCapabilityServer server = ret
    cdef _InterfaceSchema schema = ret.schema

    return new C_Capability.Client(helpers.server_to_client(schema.thisptr, <PyObject *>server))


cdef public convert_array_pyobject(PyArray & arr):
    return [<object>arr[i] for i in range(arr.size())]

cdef public PyPromise * extract_promise(object obj):
    if type(obj) is Promise:
        promise = <Promise>obj

        ret = new PyPromise(promise.thisptr.attach(capnp.makePyRefCounter(<PyObject *>promise)))
        Py_DECREF(obj)

        return ret

    return NULL

cdef public RemotePromise * extract_remote_promise(object obj):
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

_Nature = _make_enum('_Nature', 
                    PRECONDITION = 0,
                    LOCAL_BUG = 1,
                    OS_ERROR = 2,
                    NETWORK_FAILURE = 3,
                    OTHER = 4)
_Durability = _make_enum('_Durability', 
                    PERMANENT = 0,
                    TEMPORARY = 1,
                    OVERLOADED = 2)

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
    property nature:
        def __get__(self):
            cdef int temp = <int>self.thisptr.getNature()
            return _Nature.reverse_mapping[temp]
    property durability:
        def __get__(self):
            cdef int temp = <int>self.thisptr.getDurability()
            return _Durability.reverse_mapping[temp]
    property description:
        def __get__(self):
            return <char*>self.thisptr.getDescription().cStr()

    def __str__(self):
        return <char*>strException(deref(self.thisptr)).cStr()

# Extension classes can't inherit from Exception, so we're going to proxy wrap kj::Exception, and forward all calls to it from this Python class
class KjException(Exception):

    '''KjException is a wrapper of the internal C++ exception type. There are 2 enums, `Nature` and `Durability`, listed below, and a bunch of fields'''

    Nature = _make_enum('Nature', **{x : x for x in _Nature.reverse_mapping.values()})
    Durability = _make_enum('Durability', **{x : x for x in _Durability.reverse_mapping.values()})

    def __init__(self, message=None, nature=None, durability=None, wrapper=None):
        if wrapper is not None:
            self.wrapper = wrapper
            self.message = str(wrapper)
        else:
            self.message = message
            self.nature = nature
            self.durability = durability
    
    @property
    def file(self):
        return self.wrapper.file
    @property
    def line(self):
        return self.wrapper.line
    @property
    def nature(self):
        if self.wrapper is not None:
            return self.wrapper.nature
        else:
            return self.nature
    @property
    def durability(self):
        if self.wrapper is not None:
            return self.wrapper.durability
        else:
            return self.durability
    @property
    def description(self):
        if self.wrapper is not None:
            return self.wrapper.description
        else:
            return self.message

    def __str__(self):
        return self.message

cdef public object wrap_kj_exception(capnp.Exception & exception):
    PyErr_Clear()
    wrapper = _KjExceptionWrapper()._init(exception)
    ret = KjException(wrapper=wrapper)

    return ret

cdef public object wrap_kj_exception_for_reraise(capnp.Exception & exception):
    wrapper = _KjExceptionWrapper()._init(exception)
    wrapper_msg = str(wrapper)
    
    nature = wrapper.nature

    if wrapper.nature == 'PRECONDITION':
        if 'has no such member' in wrapper_msg:
            return AttributeError(wrapper_msg)
        else:
            return ValueError(wrapper_msg)
    # elif wrapper.nature == 'LOCAL_BUG':
    #     return ValueError(str(wrapper))
    if wrapper.nature == 'OS_ERROR':
        return OSError(wrapper_msg)
    if wrapper.nature == 'NETWORK_FAILURE':
        return IOError(wrapper_msg)


    ret = KjException(wrapper=wrapper)
    return ret

cdef public object get_exception_info(object exc_type, object exc_obj, object exc_tb):
    try:
        return (exc_tb.tb_frame.f_code.co_filename.encode(), exc_tb.tb_lineno, (repr(exc_type) + ':' + str(exc_obj)).encode())
    except:
        return (b'', 0, b"Couldn't determine python exception")


ctypedef fused _DynamicStructReaderOrBuilder:
    _DynamicStructReader
    _DynamicStructBuilder

ctypedef fused _DynamicSetterClasses:
    C_DynamicList.Builder
    DynamicStruct_Builder

ctypedef fused PromiseTypes:
    Promise
    _RemotePromise
    _VoidPromise
    PromiseFulfillerPair

cdef extern from "Python.h":
    cdef int PyObject_AsReadBuffer(object, void** b, Py_ssize_t* c)
    cdef int PyObject_AsWriteBuffer(object, void** b, Py_ssize_t* c)

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
    StringTree printStructReader" ::capnp::prettyPrint"(C_DynamicStruct.Reader)
    StringTree printStructBuilder" ::capnp::prettyPrint"(DynamicStruct_Builder)
    StringTree printRequest" ::capnp::prettyPrint"(Request &)
    StringTree printListReader" ::capnp::prettyPrint"(C_DynamicList.Reader)
    StringTree printListBuilder" ::capnp::prettyPrint"(C_DynamicList.Builder)

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

    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return to_python_reader(self.thisptr[index], self._parent)

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

    cdef _set(self, index, value):
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

    def __str__(self):
        return <char*>printListBuilder(self.thisptr).flatten().cStr()

    def __repr__(self):
        # TODO:  Print the list type.
        return '<capnp list builder %s>' % <char*>strListBuilder(self.thisptr).cStr()

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

# cdef to_python_pipeline(C_DynamicValue.Pipeline self, object parent):
#     cdef int type = self.getType()
#     if type == capnp.TYPE_CAPABILITY:
#         return _DynamicCapabilityClient()._init(self.asCapability(), parent)
#     # elif type == capnp.TYPE_STRUCT:
#     #     return _DynamicStructReader()._init(self.asStruct(), parent)
#     elif type == capnp.TYPE_UNKNOWN:
#         raise ValueError("Cannot convert type to Python. Type is unknown by capnproto library")
#     else:
#         raise ValueError("Cannot convert type to Python. Type is unhandled by capnproto library")

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
        raise ValueError("Cannot convert type to Python. Type is unknown by capnproto library")
    else:
        raise ValueError("Cannot convert type to Python. Type is unhandled by capnproto library")

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

cdef _setBytes(_DynamicSetterClasses thisptr, field, value):
    cdef capnp.StringPtr temp_string = capnp.StringPtr(<char*>value, len(value))
    cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(temp_string)
    thisptr.set(field, temp)

cdef _setBaseString(_DynamicSetterClasses thisptr, field, value):
    encoded_value = value.encode()
    cdef capnp.StringPtr temp_string = capnp.StringPtr(<char*>encoded_value, len(encoded_value))
    cdef C_DynamicValue.Reader temp = C_DynamicValue.Reader(temp_string)
    thisptr.set(field, temp)

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
    elif value_type is dict:
        if _DynamicSetterClasses is DynamicStruct_Builder:
            builder = to_python_builder(thisptr.get(field), parent)
            _from_dict(builder, value)
        else:
            builder = to_python_builder(thisptr[field], parent)
            _from_dict(builder, value)
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
    else:
        raise ValueError("Tried to set field: '{}' with a value of: '{}' which is an unsupported type: '{}'".format(field, str(value), str(type(value))))

cdef _to_dict(msg, bint verbose):
    msg_type = type(msg)
    if msg_type is _DynamicListBuilder or msg_type is _DynamicListReader or msg_type is _DynamicResizableListBuilder:
        return [_to_dict(x, verbose) for x in msg]

    if msg_type is _DynamicStructBuilder or msg_type is _DynamicStructReader:
        ret = {}
        try:
            which = msg.which()
            ret[which] = _to_dict(getattr(msg, which), verbose)
        except ValueError:
            pass

        for field in msg.schema.non_union_fields:
            if verbose or msg._has(field):
                ret[field] = _to_dict(getattr(msg, field), verbose)

        return ret

    return msg


cdef _from_dict(_DynamicStructBuilder msg, dict d):
    for key, val in d.iteritems():
        if key != 'which':
            try:
                msg._set(key, val)
            except Exception as e:
                if 'expected isSetInUnion(field)' in str(e):
                    msg.init(key)
                    msg._set(key, val)

cdef _from_list(_DynamicListBuilder msg, list d):
    cdef size_t count = 0
    for val in d:
        msg._set(count, val)
        count += 1


cdef class _DynamicEnum:
    cdef capnp.DynamicEnum thisptr
    cdef public object _parent

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

cdef class _DynamicEnumField:
    cdef object thisptr

    cdef _init(self, proto):
        self.thisptr = proto
        return self

    property raw:
        """A property that returns the raw int of the enum"""
        def __get__(self):
            return self.thisptr.discriminantValue

    def __str__(self):
        return self.thisptr.name

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

cdef class _DynamicStructReader:
    """Reads Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Reader. The only difference is that instead of a `get` method, __getattr__ is overloaded and the field name is passed onto the C++ equivalent `get`. This means you just use . syntax to access any field. For field names that don't follow valid python naming convention for fields, use the global function :py:func:`getattr`::

        person = addressbook.Person.read(file) # This returns a _DynamicStructReader
        print person.name # using . syntax
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """
    cdef _init(self, C_DynamicStruct.Reader other, object parent, bint isRoot=False):
        self.thisptr = other
        self._parent = parent
        self.is_root = isRoot
        return self

    def __getattr__(self, field):
        return to_python_reader(self.thisptr.get(field), self._parent)

    def _has(self, field):
        return self.thisptr.has(field)

    cpdef _which(self):
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`exceptions.ValueError` if this struct doesn't contain a union
        """
        try:
            which = _DynamicEnumField()._init(_StructSchemaField()._init(helpers.fixMaybe(self.thisptr.which()), self).proto)
        except:
            raise ValueError("Attempted to call which on a non-union type")

        return which

    property which:
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`exceptions.ValueError` if this struct doesn't contain a union
        """
        def __get__(_DynamicStructReader self):
            return self._which()

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.fieldnames)

    def __str__(self):
        return <char*>printStructReader(self.thisptr).flatten().cStr()

    def __repr__(self):
        return '<%s reader %s>' % (self.schema.node.displayName, <char*>strStructReader(self.thisptr).cStr())

    def to_dict(self, verbose=False):
        return _to_dict(self, verbose)

    cpdef as_builder(self):
        """A method for casting this Builder to a Reader

        This is a copying operation with respect to the message's buffer. Changes in the new builder will not reflect in the original reader.

        :rtype: :class:`_DynamicStructBuilder`
        """
        builder = _MallocMessageBuilder()
        return builder.set_root(self)

cdef class _DynamicStructBuilder:
    """Builds Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Builder. The only difference is that instead of a `get`/`set` method, __getattr__/__setattr__ is overloaded and the field name is passed onto the C++ equivalent function. This means you just use . syntax to access or set any field. For field names that don't follow valid python naming convention for fields, use the global functions :py:func:`getattr`/:py:func:`setattr`::

        person = addressbook.Person.new_message() # This returns a _DynamicStructBuilder
        
        person.name = 'foo' # using . syntax
        print person.name # using . syntax

        setattr(person, 'field-with-hyphens', 'foo') # for names that are invalid for python, use setattr
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """
    cdef DynamicStruct_Builder thisptr
    cdef public object _parent
    cdef public bint is_root
    cdef bint _is_written
    cdef _init(self, DynamicStruct_Builder other, object parent, bint isRoot = False):
        self.thisptr = other
        self._parent = parent
        self.is_root = isRoot
        self._is_written = False
        return self

    cdef _check_write(self):
        if not self.is_root:
            raise ValueError("You can only call write() on the message's root struct.")
        if self._is_written:
            _warnings.warn("This message has already been written once. Be very careful that you're not setting Text/Struct/List fields more than once, since that will cause memory leaks (both in memory and in the serialized data). You can disable this warning by setting the `_is_written` field of this object to False after every write.")

    def write(self, file):
        """Writes the struct's containing message to the given file object in unpacked binary format.
        
        This is a shortcut for calling capnp._write_message_to_fd().  This can only be called on the
        message's root struct.
        
        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.
        
        :rtype: void
        
        :Raises: :exc:`exceptions.ValueError` if this isn't the message's root struct.
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
        
        :Raises: :exc:`exceptions.ValueError` if this isn't the message's root struct.
        """
        self._check_write()
        _write_packed_message_to_fd(file.fileno(), self._parent)
        self._is_written = True

    cpdef to_bytes(_DynamicStructBuilder self) except +reraise_kj_exception:
        """Returns the struct's containing message as a Python bytes object in the unpacked binary format.

        This is inefficient; it makes several copies.

        :rtype: bytes

        :Raises: :exc:`exceptions.ValueError` if this isn't the message's root struct.
        """
        self._check_write()
        cdef _MessageBuilder builder = self._parent
        array = schema_cpp.messageToFlatArray(deref(builder.thisptr))
        cdef const char* ptr = <const char *>array.begin()
        cdef bytes ret = ptr[:8*array.size()]
        self._is_written = True
        return ret

    cpdef to_bytes_packed(_DynamicStructBuilder self) except +reraise_kj_exception:
        self._check_write()
        cdef _MessageBuilder builder = self._parent
        array = helpers.messageToPackedBytes(deref(builder.thisptr))
        cdef const char* ptr = <const char *>array.begin()
        cdef bytes ret = ptr[:array.size()]
        self._is_written = True
        return ret

    cdef _get(self, field):
        cdef C_DynamicValue.Builder value = self.thisptr.get(field)

        return to_python_builder(value, self._parent)
        
    def __getattr__(self, field):
        return self._get(field)

    cdef _set(self, field, value):
        _setDynamicField(self.thisptr, field, value, self._parent)

    def __setattr__(self, field, value):
        self._set(field, value)

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

    cpdef _which(self):
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`exceptions.ValueError` if this struct doesn't contain a union
        """
        try:
            which = _DynamicEnumField()._init(_StructSchemaField()._init(helpers.fixMaybe(self.thisptr.which()), self).proto)
        except:
            raise ValueError("Attempted to call which on a non-union type")

        return which

    property which:
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`exceptions.ValueError` if this struct doesn't contain a union
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

    cpdef copy(self):
        """A method for copying this Builder

        This is a copying operation with respect to the message's buffer. Changes in the new builder will not reflect in the original reader.

        :rtype: :class:`_DynamicStructBuilder`
        """
        builder = _MallocMessageBuilder()
        return builder.set_root(self)

    property schema:
        """A property that returns the _StructSchema object matching this writer"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.fieldnames)

    def __str__(self):
        return <char*>printStructBuilder(self.thisptr).flatten().cStr()

    def __repr__(self):
        return '<%s builder %s>' % (self.schema.node.displayName, <char*>strStructBuilder(self.thisptr).cStr())

    def to_dict(self, verbose=False):
        return _to_dict(self, verbose)

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
            return _DynamicStructPipeline()._init(new C_DynamicStruct.Pipeline(moveStructPipeline((<C_DynamicValue.Pipeline>self.thisptr.get(field)).asStruct())), self._parent)
        elif type == capnp.TYPE_UNKNOWN:
            raise ValueError("Cannot convert type to Python. Type is unknown by capnproto library")
        else:
            raise ValueError("Cannot convert type to Python. Type is unhandled by capnproto library")

    def __getattr__(self, field):
        return self._get(field)

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.fieldnames)

    # def __str__(self):
    #     return printStructReader(self.thisptr).flatten().cStr()

    # def __repr__(self):
    #     return '<%s reader %s>' % (self.schema.node.displayName, strStructReader(self.thisptr).cStr())

    def to_dict(self, verbose=False):
        return _to_dict(self, verbose)

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

    cpdef set_as_text(self, text):
        self.thisptr.setAsText(text)

    cpdef as_text(self) except +reraise_kj_exception:
        return (<char*>self.thisptr.getAsText().cStr())[:]

cdef class _EventLoop:
    cdef capnp.AsyncIoContext * thisptr

    def __init__(self):
        self._init()

    cdef _init(self) except +reraise_kj_exception:
        self.thisptr = new capnp.AsyncIoContext(moveAsyncContext(capnp.setupAsyncIo()))

    def __dealloc__(self):
        del self.thisptr #TODO:MEMORY: fix problems with Promises still being around

    cpdef _remove(self) except +reraise_kj_exception:
        del self.thisptr
        self.thisptr = NULL

    cdef Own[AsyncIoStream] wrapSocketFd(self, int fd):
        return deref(deref(self.thisptr).lowLevelProvider).wrapSocketFd(fd)

cdef _EventLoop C_DEFAULT_EVENT_LOOP = _EventLoop()

_C_DEFAULT_EVENT_LOOP_LOCAL = None

cdef _EventLoop C_DEFAULT_EVENT_LOOP_GETTER():
    'Optimization for not having to deal with threadlocal event loops unless we need to'
    if C_DEFAULT_EVENT_LOOP is not None:
        return C_DEFAULT_EVENT_LOOP
    elif _C_DEFAULT_EVENT_LOOP_LOCAL is not None:
        loop = getattr(_C_DEFAULT_EVENT_LOOP_LOCAL, 'loop', None)
        if loop is not None:
            return <_EventLoop>_C_DEFAULT_EVENT_LOOP_LOCAL.loop
        else:
            _C_DEFAULT_EVENT_LOOP_LOCAL.loop = _EventLoop()
            return _C_DEFAULT_EVENT_LOOP_LOCAL.loop

    raise RuntimeError("You don't have any EventLoops running. Please make sure to add one")

# cpdef remove_event_loop():
#     'Remove the global event loop'
#     global C_DEFAULT_EVENT_LOOP
#     C_DEFAULT_EVENT_LOOP._remove()
#     C_DEFAULT_EVENT_LOOP = None

# cpdef create_event_loop(is_thread_local=True):
#     '''Create a new global event loop. This will not remove the previous
#     EventLoop for you, so make sure to do that first'''
#     global C_DEFAULT_EVENT_LOOP
#     global _C_DEFAULT_EVENT_LOOP_LOCAL
#     if is_thread_local:
#         if _C_DEFAULT_EVENT_LOOP_LOCAL is None:
#             _C_DEFAULT_EVENT_LOOP_LOCAL = _threading.local()
#         _C_DEFAULT_EVENT_LOOP_LOCAL.loop = _EventLoop()
#     else:
#         C_DEFAULT_EVENT_LOOP = _EventLoop()

# cpdef reset_event_loop():
#     global C_DEFAULT_EVENT_LOOP
#     C_DEFAULT_EVENT_LOOP._remove()
#     C_DEFAULT_EVENT_LOOP = _EventLoop()

def wait_forever():
    cdef _EventLoop loop = C_DEFAULT_EVENT_LOOP_GETTER()
    helpers.waitNeverDone(deref(loop.thisptr).waitScope)

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

cdef class Promise:
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
            Py_INCREF(obj)
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
            raise ValueError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = <object>self.thisptr.wait(deref(self._event_loop.thisptr).waitScope)
        Py_DECREF(ret)

        self.is_consumed = True

        return ret

    cpdef then(self, func, error_func=None) except +reraise_kj_exception:
        if self.is_consumed:
            raise ValueError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        self.is_consumed = True

        return Promise()._init(helpers.then(deref(self.thisptr), <PyObject *>func, <PyObject *>error_func).attach(capnp.makePyRefCounter(<PyObject *>func), capnp.makePyRefCounter(<PyObject *>error_func)), self)

    def attach(self, *args):
        if self.is_consumed:
            raise ValueError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = Promise()._init(self.thisptr.attach(capnp.makePyRefCounter(<PyObject *>args)), self)
        self.is_consumed = True

        return ret

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
            raise ValueError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        self.thisptr.wait(deref(self._event_loop.thisptr).waitScope)
        self.is_consumed = True

    cpdef then(self, func, error_func=None) except +reraise_kj_exception:
        if self.is_consumed:
            raise RuntimeError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        return Promise()._init(helpers.then(deref(self.thisptr), <PyObject *>func, <PyObject *>error_func).attach(capnp.makePyRefCounter(<PyObject *>func), capnp.makePyRefCounter(<PyObject *>error_func)), self)

    cpdef as_pypromise(self) except +reraise_kj_exception:
        if self.is_consumed:
            raise RuntimeError('Promise was already used in a consuming operation. You can no longer use this Promise object')
        return Promise()._init(helpers.convert_to_pypromise(deref(self.thisptr)), self)

    def attach(self, *args):
        if self.is_consumed:
            raise ValueError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = _VoidPromise()._init(self.thisptr.attach(capnp.makePyRefCounter(<PyObject *>args)), self)
        self.is_consumed = True

        return ret

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

    cpdef wait(self) except +reraise_kj_exception:
        if self.is_consumed:
            raise ValueError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = _Response()._init_child(self.thisptr.wait(deref(self._event_loop.thisptr).waitScope), self._parent)
        self.is_consumed = True

        return ret

    cpdef as_pypromise(self) except +reraise_kj_exception:
        if self.is_consumed:
            raise RuntimeError('Promise was already used in a consuming operation. You can no longer use this Promise object')
        return Promise()._init(helpers.convert_to_pypromise(deref(self.thisptr)), self)

    cpdef then(self, func, error_func=None) except +reraise_kj_exception:
        if self.is_consumed:
            raise RuntimeError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        Py_INCREF(func)
        Py_INCREF(error_func)

        return Promise()._init(helpers.then(deref(self.thisptr), <PyObject *>func, <PyObject *>error_func).attach(capnp.makePyRefCounter(<PyObject *>func), capnp.makePyRefCounter(<PyObject *>error_func)), self)

    cpdef _get(self, field) except +reraise_kj_exception:
        cdef int type = (<C_DynamicValue.Pipeline>self.thisptr.get(field)).getType()
        if type == capnp.TYPE_CAPABILITY:
            return _DynamicCapabilityClient()._init((<C_DynamicValue.Pipeline>self.thisptr.get(field)).asCapability(), self._parent)
        elif type == capnp.TYPE_STRUCT:
            return _DynamicStructPipeline()._init(new C_DynamicStruct.Pipeline(moveStructPipeline((<C_DynamicValue.Pipeline>self.thisptr.get(field)).asStruct())), self._parent)
        elif type == capnp.TYPE_UNKNOWN:
            raise ValueError("Cannot convert type to Python. Type is unknown by capnproto library")
        else:
            raise ValueError("Cannot convert type to Python. Type is unhandled by capnproto library")

    def __getattr__(self, field):
        return self._get(field)

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.fieldnames)

    def to_dict(self, verbose=False):
        return _to_dict(self, verbose)

    # def attach(self, *args):
    #     if self.is_consumed:
    #         raise ValueError('Promise was already used in a consuming operation. You can no longer use this Promise object')

    #     ret = _RemotePromise()._init(self.thisptr.attach(capnp.makePyRefCounter(<PyObject *>args)), self)
    #     self.is_consumed = True

    #     return ret

cpdef join_promises(promises) except +reraise_kj_exception:
    heap = capnp.heapArrayBuilderPyPromise(len(promises))

    new_promises = []
    new_promises_append = new_promises.append

    for promise in promises:
        promise_type = type(promise)
        if promise_type is Promise:
            pyPromise = <Promise>promise
        elif promise_type is _RemotePromise or promise_type is _VoidPromise:
            pyPromise = <Promise>promise.as_pypromise()
            new_promises_append(pyPromise)
        else:
            raise ValueError('One of the promises passed to `join_promises` had a non promise value of: ' + str(promise))
        heap.add(movePromise(deref(pyPromise.thisptr)))
        pyPromise.is_consumed = True

    return Promise()._init(helpers.then(capnp.joinPromises(heap.finish())))

cdef class _Request(_DynamicStructBuilder):
    cdef Request * thisptr_child

    cdef _init_child(self, Request other, parent):
        self.thisptr_child = new Request(moveRequest(other))
        self._init(<DynamicStruct_Builder>deref(self.thisptr_child), parent)
        return self

    def __dealloc__(self):
        del self.thisptr_child

    cpdef send(self):
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
        return getattr(self.server, field)

cdef class _DynamicCapabilityClient:
    cdef C_DynamicCapability.Client thisptr
    cdef public object _server, _parent

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
        meth = None
        for meth in s.node.interface.methods:
            if meth.name == method_name:
                break

        params = s.get_dependency(meth.paramStructType).node
        if params.scopeId != 0:
            raise ValueError("Cannot call method `%s` with positional args, since its param struct is not implicitly defined and thus does not have a set order of arguments" % method_name)

        return _find_field_order(params.struct)

    cdef _set_fields(self, Request * request, name, args, kwargs):
        if args is not None:
            arg_names = self._find_method_args(name)
            if len(args) > len(arg_names):
                raise ValueError('Too many arguments passed to `%s`. Expected %d and got %d' % (name, len(arg_names), len(args)))
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
        if name.endswith('_request'):
            short_name = name[:-8]
            return _partial(self._request, short_name)
        return _partial(self._send, name)

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
            return _InterfaceSchema()._init(self.thisptr.getSchema())

    def __dir__(self):
        return list(self.schema.method_names)

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

cdef class _Restorer:
    cdef PyRestorer * thisptr
    cdef public object restore, _parent

    def __init__(self, restore, parent=None):
        self.thisptr = new PyRestorer(<PyObject*>self)
        self.restore = restore
        self._parent = parent

    def __dealloc__(self):
        del self.thisptr

    def _restore(self, obj):
        return self.restore(obj)

cdef class _TwoPartyVatNetwork:
    cdef Own[C_TwoPartyVatNetwork] thisptr
    cdef _FdAsyncIoStream stream

    cdef _init(self, _FdAsyncIoStream stream, Side side):
        self.stream = stream
        self.thisptr = makeTwoPartyVatNetwork(deref(stream.thisptr), side)
        return self

    cpdef on_disconnect(self) except +reraise_kj_exception:
        return _VoidPromise()._init(deref(self.thisptr).onDisconnect(), self)

cdef _Restorer _convert_restorer(restorer):
    if isinstance(restorer, _RestorerImpl):
        return _Restorer(restorer._restore, restorer)
    elif type(restorer) is _Restorer:
        return restorer
    elif hasattr(restorer, 'restore'):
        return _Restorer(restorer.restore, restorer)
    elif callable(restorer):
        return _Restorer(restorer)
    else:
        raise ValueError("Restorer object ({}) isn't able to be used as a restore".format(str(restorer)))

cdef class TwoPartyClient:
    cdef RpcSystem * thisptr
    cdef public _TwoPartyVatNetwork _network
    cdef public object _orig_stream
    cdef public _Restorer _restorer
    cdef public _FdAsyncIoStream _stream

    def __init__(self, socket, restorer=None):
        if isinstance(socket, basestring):
            socket = self._connect(socket)

        self._orig_stream = socket
        self._stream = _FdAsyncIoStream(socket.fileno())
        self._network = _TwoPartyVatNetwork()._init(self._stream, capnp.CLIENT)
        if restorer is None:
            self.thisptr = new RpcSystem(makeRpcClient(deref(self._network.thisptr)))
            self._restorer = None
        else:
            self._restorer = _convert_restorer(restorer)
            self.thisptr = new RpcSystem(makeRpcClientWithRestorer(deref(self._network.thisptr), deref(self._restorer.thisptr)))

        Py_INCREF(self._restorer)
        Py_INCREF(self._orig_stream)
        Py_INCREF(self._stream)
        Py_INCREF(self._network) # TODO:MEMORY: attach this to onDrained, also figure out what's leaking

    def __dealloc__(self):
        del self.thisptr

    cpdef _connect(self, host_string):
        host, port = host_string.split(':')

        sock = _socket.create_connection((host, port))

        # Set TCP_NODELAY on socket to disable Nagle's algorithm. This is not
        # neccessary, but it speeds things up.
        sock.setsockopt(_socket.IPPROTO_TCP, _socket.TCP_NODELAY, 1)
        return sock

    cpdef restore(self, objectId) except +reraise_kj_exception:
        cdef _MessageBuilder builder 
        cdef _MessageReader reader
        cdef _DynamicObjectBuilder object_builder
        cdef _DynamicObjectReader object_reader

        if type(objectId) is _DynamicObjectBuilder:
            object_builder = objectId
            return _CapabilityClient()._init(helpers.restoreHelper(deref(self.thisptr), deref(object_builder.thisptr)), self)
        elif type(objectId) is _DynamicObjectReader:
            object_reader = objectId
            return _CapabilityClient()._init(helpers.restoreHelper(deref(self.thisptr), object_reader.thisptr), self)
        else:
            if not hasattr(objectId, 'is_root'):
                raise ValueError("objectId was not a valid Cap'n Proto struct")
            if not objectId.is_root:
                raise ValueError("objectId must be the root of a Cap'n Proto message, ie. addressbook_capnp.Person.new_message()")

            try:
                builder = objectId._parent
            except:
                reader = objectId._parent

            if builder is not None:
                return _CapabilityClient()._init(helpers.restoreHelper(deref(self.thisptr), deref(builder.thisptr)), self)
            elif reader is not None:
                return _CapabilityClient()._init(helpers.restoreHelper(deref(self.thisptr), deref(reader.thisptr)), self)
            else:
                raise ValueError("objectId unexpectedly was not convertible to the proper type")

    cpdef ez_restore(self, textId) except +reraise_kj_exception:
        # ez-rpc from the C++ API uses Text under the hood
        ref = _MallocMessageBuilder().get_root_as_any()
        # objectId is an AnyPointer, so we have a special method for setting it to text
        ref.set_as_text(textId)

        return self.restore(ref)

    cpdef on_disconnect(self) except +reraise_kj_exception:
        return _VoidPromise()._init(deref(self._network.thisptr).onDisconnect())

cdef class TwoPartyServer:
    cdef RpcSystem * thisptr
    cdef public _TwoPartyVatNetwork _network
    cdef public object _orig_stream, _server_socket, _disconnect_promise
    cdef public _Restorer _restorer
    cdef public _FdAsyncIoStream _stream
    cdef object _port
    cdef public object port_promise
    cdef capnp.TaskSet * _task_set
    cdef capnp.ErrorHandler _error_handler

    def __init__(self, socket, restorer, server_socket=None):
        self._restorer = _convert_restorer(restorer)
        if isinstance(socket, basestring):
            self._connect(socket)
        else:
            self._orig_stream = socket
            self._stream = _FdAsyncIoStream(socket.fileno())
            self._server_socket = server_socket
            self._port = 0
            self._network = _TwoPartyVatNetwork()._init(self._stream, capnp.SERVER)
            self.thisptr = new RpcSystem(makeRpcServer(deref(self._network.thisptr), deref(self._restorer.thisptr)))

            Py_INCREF(self._orig_stream)
            Py_INCREF(self._stream)
            Py_INCREF(self._restorer)
            Py_INCREF(self._network)
            self._disconnect_promise = self.on_disconnect().then(self._decref)

    cpdef _connect(self, host_string):
        cdef _EventLoop loop = C_DEFAULT_EVENT_LOOP_GETTER()
        cdef capnp.StringPtr temp_string = capnp.StringPtr(<char*>host_string, len(host_string))
        self._task_set = new capnp.TaskSet(self._error_handler)
        self.port_promise = Promise()._init(helpers.connectServer(deref(self._task_set), deref(self._restorer.thisptr), loop.thisptr, temp_string))

    def _decref(self):
        Py_DECREF(self._restorer)
        Py_DECREF(self._orig_stream)
        Py_DECREF(self._stream)
        Py_DECREF(self._network)

    def __dealloc__(self):
        del self.thisptr
        del self._task_set

    cpdef on_disconnect(self) except +reraise_kj_exception:
        return _VoidPromise()._init(deref(self._network.thisptr).onDisconnect())

    cpdef run_forever(self):
        if self.port_promise is None:
            raise ValueError("You must pass a string as the socket parameter in __init__ to use this function")

        wait_forever()

    property port:
        def __get__(self):
            if self._port is None:
                self._port = self.port_promise.wait()
                return self._port
            else:
                return self._port

    # TODO: add restore functionality here?

cdef class _FdAsyncIoStream:
    cdef Own[AsyncIoStream] thisptr
    cdef _EventLoop _event_loop

    def __init__(self, int fd):
        self._init(fd)

    cdef _init(self, int fd) except +reraise_kj_exception:
        self._event_loop = C_DEFAULT_EVENT_LOOP_GETTER()
        self.thisptr = self._event_loop.wrapSocketFd(fd)

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
    cdef C_Schema thisptr
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

    cpdef get_dependency(self, id):
        return _Schema()._init(self.thisptr.getDependency(id))

    cpdef get_proto(self):
        return _NodeReader().init(self.thisptr.getProto())

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

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

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

    cpdef get_dependency(self, id):
        return _Schema()._init(self.thisptr.getDependency(id))

    def __richcmp__(_StructSchema self, _StructSchema other, mode):
        if mode == 2:
            return self.thisptr == other.thisptr
        elif mode == 3:
            return not (self.thisptr == other.thisptr)
        else:
            raise NotImplementedError()

    def __repr__(self):
        return '<schema for %s>' % self.node.displayName

cdef class _StructSchemaField:
    cdef C_StructSchema.Field thisptr
    cdef object _parent
    cdef _init(self, C_StructSchema.Field other, parent=None):
        self.thisptr = other
        self._parent = parent
        return self

    property proto:
        """The raw schema proto"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

    def __repr__(self):
        return '<field schema for %s>' % self.proto.name

cdef class _InterfaceSchema:
    cdef C_InterfaceSchema thisptr
    cdef object __method_names

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

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr.getProto(), self)

    cpdef get_dependency(self, id):
        return _Schema()._init(self.thisptr.getDependency(id))

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

cdef _new_message(self, kwargs):
    builder = _MallocMessageBuilder()
    msg = builder.init_root(self.schema)
    if kwargs is not None:
        _from_dict(msg, kwargs)
    return msg

class _RestorerImpl(object):
    pass

class _StructModuleWhich(object):
    pass

class _StructModule(object):
    def __init__(self, schema, name):
        def _restore(self, obj):
            return self.restore(obj.as_struct(self.schema))
        self.schema = schema

        self.Restorer = type(name + '.Restorer', (_RestorerImpl,), {'schema':schema, '_restore':_restore})

        # Add enums for union fields
        for field in schema.node.struct.fields:
            if field.which() == 'group':
                name = field.name.capitalize()
                union_schema = schema.get_dependency(field.group.typeId).node.struct
                
                if union_schema.discriminantCount == 0:
                    continue

                union_module = _StructModuleWhich()
                setattr(union_module, 'schema', union_schema)
                for union_field in union_schema.fields:
                    setattr(union_module, union_field.name, union_field.discriminantValue)
                setattr(self, name, union_module)

    def read(self, file, traversal_limit_in_words = None, nesting_limit = None):
        """Returns a Reader for the unpacked object read from file.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.
        
        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`"""
        reader = _StreamFdMessageReader(file.fileno(), traversal_limit_in_words, nesting_limit)
        return reader.get_root(self.schema)
    def read_multiple(self, file, traversal_limit_in_words = None, nesting_limit = None):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.
        
        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultipleMessageReader(file.fileno(), self.schema, traversal_limit_in_words, nesting_limit)
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
        reader = _PackedFdMessageReader(file.fileno(), traversal_limit_in_words, nesting_limit)
        return reader.get_root(self.schema)
    def read_multiple_packed(self, file, traversal_limit_in_words = None, nesting_limit = None):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.
        
        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed. Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultiplePackedMessageReader(file.fileno(), self.schema, traversal_limit_in_words, nesting_limit)
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
            message = _FlatMessageBuilder(buf)
        else:
            message = _FlatArrayMessageReader(buf, traversal_limit_in_words, nesting_limit)
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
    def new_message(self, **kwargs):
        """Returns a newly allocated builder message.

        :type kwargs: dict
        :param kwargs: A list of fields and their values to initialize in the struct

        :rtype: :class:`_DynamicStructBuilder`
        """
        return _new_message(self, kwargs)
    def from_dict(self, kwargs):
        '.. warning:: This method is deprecated and will be removed in the 0.5 release. Use the :meth:`new_message` function instead with **kwargs'
        _warnings.warn('This method is deprecated and will be removed in the 0.5 release. Use the :meth:`new_message` function instead with **kwargs', UserWarning)
        return _new_message(self, kwargs)
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

cdef class SchemaParser:
    """A class for loading Cap'n Proto schema files.

    Do not use this class unless you're sure you know what you're doing. Use the convenience method :func:`load` instead.
    """
    cdef C_SchemaParser * thisptr
    def __cinit__(self):
        self.thisptr = new C_SchemaParser()

    def __dealloc__(self):
        del self.thisptr

    cpdef _parse_disk_file(self, displayName, diskPath, imports) except +reraise_kj_exception:
        cdef StringPtr * importArray = <StringPtr *>malloc(sizeof(StringPtr) * len(imports))

        for i in range(len(imports)):
            importArray[i] = StringPtr(imports[i])

        cdef ArrayPtr[StringPtr] importsPtr = ArrayPtr[StringPtr](importArray, <size_t>len(imports))

        ret = _ParsedSchema()
        ret._init_child(self.thisptr.parseDiskFile(displayName, diskPath, importsPtr))

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
        message = _StreamFdMessageReader(f.fileno())
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, int fd, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts

        if traversal_limit_in_words is not None:
            opts.traversalLimitInWords = traversal_limit_in_words
        if nesting_limit is not None:
            opts.nestingLimit = nesting_limit

        self.thisptr = new schema_cpp.StreamFdMessageReader(fd, opts)

cdef class _PackedMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f.fileno())
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    cdef public object _parent
    def __init__(self):
        pass

    cdef _init(self, schema_cpp.BufferedInputStream & stream, traversal_limit_in_words = None, nesting_limit = None, parent = None):
        cdef schema_cpp.ReaderOptions opts

        self._parent = parent

        if traversal_limit_in_words is not None:
            opts.traversalLimitInWords = traversal_limit_in_words
        if nesting_limit is not None:
            opts.nestingLimit = nesting_limit
            
        self.thisptr = new schema_cpp.PackedMessageReader(stream, opts)
        return self

cdef class _PackedMessageReaderBytes(_MessageReader):
    cdef public object _parent
    cdef schema_cpp.ArrayInputStream * stream

    def __init__(self, buf, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts

        self._parent = buf

        if traversal_limit_in_words is not None:
            opts.traversalLimitInWords = traversal_limit_in_words
        if nesting_limit is not None:
            opts.nestingLimit = nesting_limit
            
        cdef const void *ptr
        cdef Py_ssize_t sz
        PyObject_AsReadBuffer(buf, &ptr, &sz)

        self.stream = new schema_cpp.ArrayInputStream(schema_cpp.ByteArrayPtr(<byte *>ptr, sz))
            
        self.thisptr = new schema_cpp.PackedMessageReader(deref(self.stream), opts)

    def __dealloc__(self):
        del self.stream

cdef class _InputMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f.fileno())
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    cdef public object _parent
    def __init__(self):
        pass

    cdef _init(self, schema_cpp.BufferedInputStream & stream, traversal_limit_in_words = None, nesting_limit = None, parent = None):
        cdef schema_cpp.ReaderOptions opts

        self._parent = parent

        if traversal_limit_in_words is not None:
            opts.traversalLimitInWords = traversal_limit_in_words
        if nesting_limit is not None:
            opts.nestingLimit = nesting_limit
            
        self.thisptr = new schema_cpp.InputStreamMessageReader(stream, opts)
        return self

cdef class _PackedFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f.fileno())
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, int fd, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts

        if traversal_limit_in_words is not None:
            opts.traversalLimitInWords = traversal_limit_in_words
        if nesting_limit is not None:
            opts.nestingLimit = nesting_limit
            
        self.thisptr = new schema_cpp.PackedFdMessageReader(fd, opts)

cdef class _MultipleMessageReader:
    cdef schema_cpp.FdInputStream * stream
    cdef schema_cpp.BufferedInputStream * buffered_stream

    cdef public object traversal_limit_in_words, nesting_limit, schema

    def __init__(self, int fd, schema, traversal_limit_in_words = None, nesting_limit = None):
        self.schema = schema
        self.traversal_limit_in_words = traversal_limit_in_words
        self.nesting_limit = nesting_limit
            
        self.stream = new schema_cpp.FdInputStream(fd)
        self.buffered_stream = new schema_cpp.BufferedInputStreamWrapper(deref(self.stream))

    def __dealloc__(self):
        del self.stream
        del self.buffered_stream

    def __next__(self):
        try:
            reader = _InputMessageReader()._init(deref(self.buffered_stream), self.traversal_limit_in_words, self.nesting_limit, self)
            return reader.get_root(self.schema)
        except ValueError as e:
            if 'EOF' in str(e):
                raise StopIteration
            else:
                raise

    def __iter__(self):
        return self

cdef class _MultiplePackedMessageReader:
    cdef schema_cpp.FdInputStream * stream
    cdef schema_cpp.BufferedInputStream * buffered_stream

    cdef public object traversal_limit_in_words, nesting_limit, schema

    def __init__(self, int fd, schema, traversal_limit_in_words = None, nesting_limit = None):
        self.schema = schema
        self.traversal_limit_in_words = traversal_limit_in_words
        self.nesting_limit = nesting_limit
            
        self.stream = new schema_cpp.FdInputStream(fd)
        self.buffered_stream = new schema_cpp.BufferedInputStreamWrapper(deref(self.stream))

    def __dealloc__(self):
        del self.stream
        del self.buffered_stream

    def __next__(self):
        try:
            reader = _PackedMessageReader()._init(deref(self.buffered_stream), self.traversal_limit_in_words, self.nesting_limit, self)
            return reader.get_root(self.schema)
        except ValueError as e:
            if 'EOF' in str(e):
                raise StopIteration
            else:
                raise

    def __iter__(self):
        return self

@cython.internal
cdef class _FlatArrayMessageReader(_MessageReader):
    cdef object _object_to_pin
    def __init__(self, buf, traversal_limit_in_words = None, nesting_limit = None):
        cdef schema_cpp.ReaderOptions opts

        if traversal_limit_in_words is not None:
            opts.traversalLimitInWords = traversal_limit_in_words
        if nesting_limit is not None:
            opts.nestingLimit = nesting_limit
            
        cdef const void *ptr
        cdef Py_ssize_t sz
        PyObject_AsReadBuffer(buf, &ptr, &sz)
        if sz % 8 != 0:
            raise ValueError("input length must be a multiple of eight bytes")
        self._object_to_pin = buf

        self.thisptr = new schema_cpp.FlatArrayMessageReader(schema_cpp.WordArrayPtr(<schema_cpp.word*>ptr, sz//8))

@cython.internal
cdef class _FlatMessageBuilder(_MessageBuilder):
    cdef object _object_to_pin
    def __init__(self, buf):
        cdef void *ptr
        cdef Py_ssize_t sz
        PyObject_AsWriteBuffer(buf, &ptr, &sz)
        if sz % 8 != 0:
            raise ValueError("input length must be a multiple of eight bytes")
        self._object_to_pin = buf
        self.thisptr = new schema_cpp.FlatMessageBuilder(schema_cpp.WordArrayPtr(<schema_cpp.word*>ptr, sz//8))

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
