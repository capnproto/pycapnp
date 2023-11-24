# capnp.pyx
# distutils: language = c++
# distutils: libraries = capnpc capnp-rpc capnp kj-async kj
# distutils: include_dirs = .
# cython: c_string_type = str
# cython: c_string_encoding = default
# cython: embedsignature = True
# cython: language_level = 2

cimport cython  # noqa: E402

from capnp.helpers.helpers cimport init_capnp_api
from capnp.includes.capnp_cpp cimport AsyncIoStream, WaitScope, PyPromise, VoidPromise, EventPort, EventLoop, Canceler, PyAsyncIoStream, PromiseFulfiller, VoidPromiseFulfiller, tryReadMessage, writeMessage, makeException, PythonInterfaceDynamicImpl
from capnp.includes.schema_cpp cimport (MessageReader,)

from cpython cimport array, Py_buffer, PyObject_CheckBuffer, memoryview, buffer
from cpython.buffer cimport PyBUF_SIMPLE, PyBUF_WRITABLE
from cpython.exc cimport PyErr_Clear
from cython.operator cimport dereference as deref
from libc.stdlib cimport malloc, free
from libc.string cimport memcpy
from libcpp.utility cimport move


import array
import asyncio
import collections as _collections
import contextlib
import enum as _enum
import inspect as _inspect
import os as _os
import random as _random
import socket as _socket
import sys as _sys
import threading as _threading
import traceback as _traceback
import warnings as _warnings
import weakref as _weakref
import traceback as _traceback

from types import ModuleType as _ModuleType
from operator import attrgetter as _attrgetter
from functools import partial as _partial
from contextlib import asynccontextmanager as _asynccontextmanager
from importlib.machinery import ModuleSpec

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
    return _Response()._init_childptr(new Response(move(r)), None)

cdef _find_field_order(struct_node):
    return [f.name for f in sorted(struct_node.fields, key=_attrgetter('codeOrder'))]

cdef class _VoidPromiseFulfiller:
   cdef VoidPromiseFulfiller* fulfiller

   cdef _init(self, VoidPromiseFulfiller* fulfiller):
       self.fulfiller = fulfiller
       return self

def void_task_done_callback(method_name, _VoidPromiseFulfiller fulfiller, task):
    if fulfiller.fulfiller == NULL:
        if not task.cancelled():
            exc = task.exception()
            if exc is not None:
                context = {
                    'message': f"Cancelled server method {method_name} raised an exception",
                    'exception': exc,
                    'task': task,
                }
                asyncio.get_running_loop().call_exception_handler(context)
        return

    if task.cancelled():
        fulfiller.fulfiller.reject(makeException(capnp.StringPtr(
            f"Server task for method {method_name} was cancelled")))
        return

    exc = task.exception()
    if exc is not None:
        fulfiller.fulfiller.reject(makeException(capnp.StringPtr(''.join(
            _traceback.format_exception(type(exc), exc, exc.__traceback__)))))
        return

    res = task.result()
    if res is not None:
        fulfiller.fulfiller.reject(makeException(capnp.StringPtr(
            f"Async server function ({method_name}) returned a non-none value: return = {res}")))
    else:
        fulfiller.fulfiller.fulfill()

cdef api void promise_task_add_done_callback(object task, object callback, VoidPromiseFulfiller& fulfiller):
    wrapper = _VoidPromiseFulfiller()._init(&fulfiller)
    task.add_done_callback(_partial(callback, wrapper))
    task._fulfiller = wrapper

cdef api void promise_task_cancel(object task):
    (<_VoidPromiseFulfiller>task._fulfiller).fulfiller = NULL
    task.cancel()

def fill_context(method_name, context, returned_data):
    if returned_data is None:
        return
    if not isinstance(returned_data, tuple):
        returned_data = (returned_data,)
    names = _find_field_order(context.results.schema.node.struct)
    if len(returned_data) > len(names):
        raise KjException(
            "Too many values returned from `{}`. Expected {} and got {}"
            .format(method_name, len(names), len(returned_data)))

    results = context.results
    for arg_name, arg_val in zip(names, returned_data):
        setattr(results, arg_name, arg_val)

cdef api VoidPromise * call_server_method(object server,
                                          char * _method_name,
                                          CallContext & _context,
                                          object _kj_loop) except * with gil:
    method_name = <object>_method_name
    kj_loop = <_EventLoop>_kj_loop
    kj_loop.check()

    context = _CallContext()._init(_context) # TODO:MEMORY: invalidate this with promise chain
    func = getattr(server, method_name+'_context', None)
    if func is not None:
        ret = func(context)
        if not asyncio.iscoroutine(ret):
            raise ValueError(
                "Server function ({}) is not a coroutine"
                .format(method_name, str(ret)))
        task = asyncio.create_task(ret)
    else:
        async def finalize():
            params = context.params
            params_dict = {name: getattr(params, name) for name in params.schema.fieldnames}
            params_dict['_context'] = context
            func = getattr(server, method_name) # will raise if no function found
            ret = func(**params_dict)
            if not asyncio.iscoroutine(ret):
                raise ValueError(
                    "Server function ({}) is not a coroutine"
                    .format(method_name, str(ret)))
            fill_context(method_name, context, await ret)
        task = asyncio.create_task(finalize())

    kj_loop.active_tasks.add(task)
    callback = _partial(void_task_done_callback, method_name)
    return new VoidPromise(helpers.taskToPromise(
        capnp.heap[PyRefCounter](<PyObject*>task),
        <PyObject*>callback))


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


_Type = _make_enum(
    "_Type",
    FAILED=0,
    OVERLOADED=1,
    DISCONNECTED=2,
    UNIMPLEMENTED=3,
    OTHER=4,
)


cdef class _KjExceptionWrapper:
    cdef capnp.Exception * thisptr

    cdef _init(self, capnp.Exception & other):
        self.thisptr = new capnp.Exception(move(other))
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


# Extension classes can't inherit from Exception, so we're going to proxy wrap kj::Exception,
# and forward all calls to it from this Python class
class KjException(Exception):

    """KjException is a wrapper of the internal C++ exception type.

    There is an enum named `Type` listed below, and a bunch of fields."""

    Type = _make_enum("Type", **{x: x for x in _Type.reverse_mapping.values()})

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
        if self.wrapper is not None and self.wrapper.type == 'FAILED':
            if 'has no such' in self.message:
                return AttributeError(message).with_traceback(self.__traceback__)
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


cdef void reraise_kj_exception():
    helpers.reraise_kj_exception()


cdef api object get_exception_info(object exc_type, object exc_obj, object exc_tb) with gil:
    try:
        return (exc_tb.tb_frame.f_code.co_filename.encode(),
                exc_tb.tb_lineno,
                (repr(exc_type) + ":" + str(exc_obj)).encode())
    except Exception:
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
    
    property node:
        """A property that returns the NodeReader as a DynamicStructReader."""
        def __get__(self):
            return _DynamicStructReader()._init(self.thisptr, self)


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

    This class thinly wraps the C++ Cap'n Proto DynamicList::Reader class. __getitem__ and __len__
    have been defined properly, so you can treat this class mostly like any other iterable class::

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

    .. warning::
        You need to call :meth:`finish` on this object before serializing the
        Cap'n Proto message. Failure to do so will cause your objects not to be
        written out as well as leaking orphan structs into your message.

    This class works much like :class:`_DynamicListBuilder`, but it allows growing the list dynamically.
    It is meant for lists of structs, since for primitive types like int or float, you're much better off
    using a normal python list and then serializing straight to a Cap'n Proto list.
    It has __getitem__ and __len__ defined, but not __setitem__::

        ...
        person = addressbook.Person.new_message()

        phones = person.init_resizable_list('phones') # This returns a _DynamicResizableListBuilder

        phone = phones.add()
        phone.number = 'foo'
        phone = phones.add()
        phone.number = 'bar'

        phones.finish()

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

        This will return a struct, in which you can set fields that will be reflected in the serialized
        Cap'n Proto message.

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

        If you don't call this method, the items you previously added from this object will leak into the message,
        ie. inaccessible but still taking up space.
        """
        cdef int i = 0
        new_list = self._parent.init(self._field, len(self))
        for orphan, _ in self._list:
            new_list.adopt(i, orphan)
            i += 1


cdef class _DynamicListBuilder:
    """Class for building Cap'n Proto Lists

    This class thinly wraps the C++ Cap'n Proto DynamicList::Bulder class. __getitem__, __setitem__, and __len__
    have been defined properly, so you can treat this class mostly like any other iterable class::

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

        Don't use this method unless you know what you're doing.
        Orphans are useful for dynamically allocating objects for an unknown sized list.

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


cdef C_DynamicValue.Reader _extract_dynamic_list_builder(_DynamicListBuilder value):
    return C_DynamicValue.Reader(value.thisptr.asReader())


cdef C_DynamicValue.Reader _extract_dynamic_list_reader(_DynamicListReader value):
    return C_DynamicValue.Reader(value.thisptr)


cdef C_DynamicValue.Reader _extract_dynamic_client(_DynamicCapabilityClient value):
    return C_DynamicValue.Reader(value.thisptr)


cdef C_DynamicValue.Reader _extract_dynamic_server(object value):
    cdef _InterfaceSchema schema = value.schema
    kj_loop = C_DEFAULT_EVENT_LOOP_GETTER()
    return C_DynamicValue.Reader(capnp.heap[PythonInterfaceDynamicImpl](
        schema.thisptr,
        capnp.heap[PyRefCounter](<PyObject*>value),
        capnp.heap[PyRefCounter](<PyObject*>kj_loop)))


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
    elif value_type is _DynamicListBuilder:
        thisptr.set(field, _extract_dynamic_list_builder(value))
    elif value_type is _DynamicListReader:
        thisptr.set(field, _extract_dynamic_list_reader(value))
    elif value_type is _DynamicCapabilityClient:
        thisptr.set(field, _extract_dynamic_client(value))
    elif isinstance(value, _DynamicCapabilityServer):
        thisptr.set(field, _extract_dynamic_server(value))
    elif value_type is _DynamicEnum:
        thisptr.set(field, _extract_dynamic_enum(value))
    elif value_type is _DynamicObjectReader:
        thisptr.set(field, _extract_any_pointer(value))
    elif value_type is _DynamicObjectBuilder:
        thisptr.set(field, _extract_any_pointer_builder(value))
    else:
        raise KjException(
            "Tried to set field: '{}' with a value of: '{}' which is an unsupported type: '{}'"
            .format(field, str(value), str(type(value))))


# TODO: Is this function used by anyone? Can it be removed?
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
    elif value_type is _DynamicListBuilder:
        thisptr.setByField(field.thisptr, _extract_dynamic_list_builder(value))
    elif value_type is _DynamicListReader:
        thisptr.setByField(field.thisptr, _extract_dynamic_list_reader(value))
    elif value_type is _DynamicCapabilityClient:
        thisptr.setByField(field.thisptr, _extract_dynamic_client(value))
    elif isinstance(value, _DynamicCapabilityServer):
        thisptr.setByField(field.thisptr, _extract_dynamic_server(value))
    elif value_type is _DynamicEnum:
        thisptr.setByField(field.thisptr, _extract_dynamic_enum(value))
    elif value_type is _DynamicObjectReader:
        thisptr.set(field, _extract_any_pointer(value))
    elif value_type is _DynamicObjectBuilder:
        thisptr.set(field, _extract_any_pointer_builder(value))
    else:
        raise KjException(
            "Tried to set field: '{}' with a value of: '{}' which is an unsupported type: '{}'"
            .format(field, str(value), str(type(value))))


# TODO: Is this function used by anyone? Can it be removed?
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
    elif value_type is _DynamicListBuilder:
        thisptr.set(field, _extract_dynamic_list_builder(value))
    elif value_type is _DynamicListReader:
        thisptr.set(field, _extract_dynamic_list_reader(value))
    elif value_type is _DynamicCapabilityClient:
        thisptr.set(field, _extract_dynamic_client(value))
    elif isinstance(value, _DynamicCapabilityServer):
        thisptr.set(field, _extract_dynamic_server(value))
    elif value_type is _DynamicEnum:
        thisptr.set(field, _extract_dynamic_enum(value))
    elif value_type is _DynamicObjectReader:
        thisptr.set(field, _extract_any_pointer(value))
    elif value_type is _DynamicObjectBuilder:
        thisptr.set(field, _extract_any_pointer_builder(value))
    else:
        raise KjException(
            "Tried to set field: '{}' with a value of: '{}' which is an unsupported type: '{}'"
            .format(field, str(value), str(type(value))))


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

    if msg_type is _DynamicStructBuilder or isinstance(msg, _Request):
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
    elif msg_type is _DynamicStructReader or isinstance(msg, _Response):
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
        with _global_schema_parser.modules_by_id[schema_id].from_bytes(data) as msg:
            return msg


cdef class _DynamicStructReader:
    """Reads Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Reader.
    The only difference is that instead of a `get` method, __getattr__ is overloaded and the field name
    is passed onto the C++ equivalent `get`. This means you just use . syntax to access any field.
    For field names that don't follow valid python naming convention for fields, use the global function
    :py:func:`getattr`::

        person = addressbook.Person.read(file) # This returns a _DynamicStructReader
        print person.name # using . syntax
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """
    cdef _init(self, C_DynamicStruct.Reader other, object parent, bint isRoot=False, bint tryRegistry=True):
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
            raise e._to_python() from None

    cpdef _get_by_field(self, _StructSchemaField field):
        return to_python_reader(self.thisptr.getByField(field.thisptr), self)

    cpdef _has(self, field):
        return self.thisptr.has(field)

    cpdef _has_by_field(self, _StructSchemaField field):
        return self.thisptr.hasByField(field.thisptr)

    cpdef _which_str(self):
        try:
            return <char *>helpers.fixMaybe(self.thisptr.which()).getProto().getName().cStr()
        except RuntimeError as e:
            if str(e) == "Member was null.":
                raise KjException("Attempted to call which on a non-union type")
            raise

    cpdef _DynamicEnumField _which(self):
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
        try:
            which = _DynamicEnumField()._init(
                _StructSchemaField()._init(helpers.fixMaybe(self.thisptr.which()), self).proto)
        except RuntimeError as e:
            if str(e) == "Member was null.":
                raise KjException("Attempted to call which on a non-union type")
            raise

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
                self._schema = _StructSchema()._init_child(self.thisptr.getSchema())
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

        This is a copying operation with respect to the message's buffer.
        Changes in the new builder will not reflect in the original reader.

        :type num_first_segment_words: int
        :param num_first_segment_words: Size of the first segment to allocate (in words ie. 8 byte increments)

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

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Builder.
    The only difference is that instead of a `get`/`set` method, __getattr__/__setattr__ is overloaded
    and the field name is passed onto the C++ equivalent function.

    This means you just use . syntax to access or set any field. For field names that don't follow valid
    python naming convention for fields, use the global functions :py:func:`getattr`/:py:func:`setattr`::

        person = addressbook.Person.new_message() # This returns a _DynamicStructBuilder

        person.name = 'foo' # using . syntax
        print person.name # using . syntax

        setattr(person, 'field-with-hyphens', 'foo') # for names that are invalid for python, use setattr
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """
    cdef _init(self, DynamicStruct_Builder other, object parent, bint isRoot=False, bint tryRegistry=True):
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
            _warnings.warn(
                "This message has already been written once. Be very careful that you're not setting "
                "Text/Struct/List fields more than once, since that will cause memory leaks "
                "(both in memory and in the serialized data). You can disable this warning by "
                "calling the `clear_write_flag` method of this object after every write.")

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

    async def write_async(self, _AsyncIoStream stream):
        """Async version of of write().

        This is a shortcut for calling capnp._write_message_to_fd().  This can only be called on the
        message's root struct.

        :type file: AsyncIoStream
        :param file: The AsyncIoStream to write the message to

        :rtype: void

        :Raises: :exc:`KjException` if this isn't the message's root struct.
        """
        self._check_write()
        await _voidpromise_to_asyncio(
            writeMessage(deref(stream.thisptr), deref((<_MessageBuilder>self._parent).thisptr)))
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
            raise e._to_python() from None

    cpdef _set(self, field, value):
        _setDynamicField(self.thisptr, field, value, self._parent)

    cpdef _set_by_field(self, _StructSchemaField field, value):
        _setDynamicFieldWithField(self.thisptr, field, value, self._parent)

    def __setattr__(self, field, value):
        try:
            self._set(field, value)
        except KjException as e:
            raise e._to_python() from None

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
        if isinstance(field, _StructModuleWhich):
            field = field.name[0].lower() + field.name[1:]
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

        This version of init returns a :class:`_DynamicResizableListBuilder` that allows
        you to add members one at a time (ie. if you don't know the size for sure).
        This is only meant for lists of Cap'n Proto objects, since for primitive types
        you can just define a normal python list and fill it yourself.

        .. warning::
            You need to call :meth:`_DynamicResizableListBuilder.finish` on the
            list object before serializing the Cap'n Proto message. Failure to do
            so will cause your objects not to be written out as well as leaking
            orphan structs into your message.

        :type field: str
        :param field: The field name to initialize

        :rtype: :class:`_DynamicResizableListBuilder`

        :Raises: :exc:`KjException` if the field isn't in this struct
        """
        return _DynamicResizableListBuilder(self, field, _StructSchema()._init_child(
            (<C_DynamicValue.Builder>self.thisptr.get(field)).asList().getStructElementType()))

    cpdef _which_str(self):
        try:
            return <char *>helpers.fixMaybe(self.thisptr.which()).getProto().getName().cStr()
        except RuntimeError as e:
            if str(e) == "Member was null.":
                raise KjException("Attempted to call which on a non-union type")
            raise

    cpdef _DynamicEnumField _which(self):
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
        try:
            which = _DynamicEnumField()._init(
                _StructSchemaField()._init(helpers.fixMaybe(self.thisptr.which()), self).proto)
        except RuntimeError as e:
            if str(e) == "Member was null.":
                raise KjException("Attempted to call which on a non-union type")
            raise

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

        Don't use this method unless you know what you're doing.
        Orphans are useful for dynamically allocating objects for an unknown sized list.

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

        This is a non-copying operation with respect to the message's buffer.
        This means changes to the fields in the original struct will carry over to the new reader.

        :rtype: :class:`_DynamicStructReader`
        """
        cdef _DynamicStructReader reader
        reader = _DynamicStructReader()._init(
            self.thisptr.asReader(), self._parent, self.is_root)
        reader._obj_to_pin = self
        return reader

    cpdef copy(self, num_first_segment_words=None):
        """A method for copying this Builder

        This is a copying operation with respect to the message's buffer.
        Changes in the new builder will not reflect in the original reader.

        :type num_first_segment_words: int
        :param num_first_segment_words: Size of the first segment to allocate (in words ie. 8 byte increments)

        :rtype: :class:`_DynamicStructBuilder`
        """
        builder = _MallocMessageBuilder(num_first_segment_words)
        return builder.set_root(self)

    property schema:
        """A property that returns the _StructSchema object matching this writer"""
        def __get__(self):
            if self._schema is None:
                self._schema = _StructSchema()._init_child(self.thisptr.getSchema())
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

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Pipeline.
    The only difference is that instead of a `get` method, __getattr__ is overloaded and the
    field name is passed onto the C++ equivalent `get`. This means you just use . syntax to
    access any field. For field names that don't follow valid python naming convention for fields,
    use the global function :py:func:`getattr`::
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
            return _DynamicCapabilityClient()._init(
                (<C_DynamicValue.Pipeline>self.thisptr.get(field)).asCapability(), self._parent)
        elif type == capnp.TYPE_STRUCT:
            return _DynamicStructPipeline()._init(
                new C_DynamicStruct.Pipeline(
                    (<C_DynamicValue.Pipeline>self.thisptr.get(field)).asStruct()), self._parent)
        elif type == capnp.TYPE_UNKNOWN:
            raise KjException("Cannot convert type to Python. Type is unknown by capnproto library")
        else:
            raise KjException("Cannot convert type to Python. Type is unhandled by capnproto library")

    def __getattr__(self, field):
        try:
            return self._get(field)
        except KjException as e:
            raise e._to_python() from None

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            return _StructSchema()._init_child(self.thisptr.getSchema())

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
        self.thisptr = move(other)
        self._parent = parent
        return self

    cdef C_DynamicOrphan move(self):
        return move(self.thisptr)

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

        return _DynamicStructReader()._init(self.thisptr.getAs(s._thisptr()), self._parent)

    cpdef as_interface(self, schema) except +reraise_kj_exception:
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicCapabilityClient()._init(self.thisptr.getAsCapability(s.thisptr), self._parent)

    cpdef as_list(self, schema) except +reraise_kj_exception:
        cdef _ListSchema s
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

        return _DynamicStructBuilder()._init(self.thisptr.getAs(s._thisptr()), self._parent)

    cpdef as_interface(self, schema) except +reraise_kj_exception:
        cdef _InterfaceSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicCapabilityClient()._init(self.thisptr.getAsCapability(s.thisptr), self._parent)

    cpdef as_list(self, schema) except +reraise_kj_exception:
        cdef _ListSchema s
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
        cdef _ListSchema s
        if hasattr(schema, 'schema'):
            s = schema.schema
        else:
            s = schema

        return _DynamicListBuilder()._init(self.thisptr.initAsList(s.thisptr, size), self._parent)

    cpdef as_text(self) except +reraise_kj_exception:
        return (<char*>self.thisptr.getAsText().cStr())[:]

    cpdef as_reader(self):
        return _DynamicObjectReader()._init(self.thisptr.asReader(), self._parent)

cdef void kjloop_runnable_callback(void* data) with gil:
    cdef AsyncIoEventPort *port = <AsyncIoEventPort*>data
    assert port.runHandle is not None
    port.kjLoop.run()

cdef cppclass AsyncIoEventPort(EventPort):
    EventLoop *kjLoop
    object asyncioLoop;
    object runHandle;

    __init__(object asyncioLoop):
        this.kjLoop = new EventLoop(deref(this))
        this.runHandle = None
        this.asyncioLoop = asyncioLoop

    __dealloc__():
        if this.runHandle is not None:
            this.runHandle.cancel()
        del this.kjLoop

    cbool wait() except* with gil:
        raise KjException("Currently you cannot wait for promises while pycapnp is running in asyncio mode. " +
                          "You should instead use 'await'. If you have a use-case to start the asyncio loop " +
                          "using wait(), please report")

    cbool poll() except* with gil:
        raise KjException("Currently you cannot poll promises while pycapnp is running in asyncio mode. " +
                          "If you have a use-case to poll the asyncio loop using poll(), please report")

    void setRunnable(cbool runnable) except* with gil:
        if runnable:
            assert this.runHandle is None
            us = <void*>this;
            while True:
                # TODO: This loop is a workaround for the following occasional nondeterministic bug
                #       that appears on Python 3.8 and 3.9:
                # AttributeError: '_UnixSelectorEventLoop' object has no attribute 'call_soon'
                # The cause of this is unknown (either a bug in our code, Cython, or Python).
                # It appears to no longer exist in Python 3.10. This can be removed once 3.9 is EOL.
                try:
                    this.runHandle = this.asyncioLoop.call_soon(lambda: kjloop_runnable_callback(us))
                    break
                except AttributeError:
                    pass
        else:
            assert this.runHandle is not None
            this.runHandle.cancel()
            this.runHandle = None

    EventLoop *getKjLoop():
        return this.kjLoop

cdef class _EventLoop:
    cdef Own[WaitScope] wait_scope
    cdef Own[AsyncIoEventPort] event_port
    cdef object active_streams
    cdef object active_rpcs
    cdef object active_tasks
    cdef cbool closed

    cdef _init(self, asyncio_loop) except +reraise_kj_exception:
        self.event_port = capnp.heap[AsyncIoEventPort](<PyObject*>asyncio_loop)
        kj_loop = deref(self.event_port).getKjLoop()
        self.wait_scope = capnp.heap[WaitScope](deref(kj_loop))
        self.active_streams = _weakref.WeakSet()
        self.active_rpcs = _weakref.WeakSet()
        self.active_tasks = _weakref.WeakSet()
        self.closed = False
        return self

    def __dealloc__(self):
        self.close()

    cdef close(self):
        if not self.closed:
            self.closed = True
            deref(self.event_port).kjLoop.run()
            self.wait_scope = Own[WaitScope]()
            self.event_port = Own[AsyncIoEventPort]()

    cdef check(self):
        if self.closed:
            raise RuntimeError(
                "The KJ event-loop is not running (on this thread). Please start it through 'capnp.kj_loop()'")

@_asynccontextmanager
async def kj_loop():
    """Context manager for running the KJ event loop

    As long as the context manager is active it is guaranteed that the KJ event
    loop is running. When the context manager is exited, the KJ event loop is
    shut down properly and pending tasks are cancelled.

    :raises [RuntimeError]: If the KJ event loop is already running (on this thread).

    .. warning:: Every capnp rpc call required a running KJ event loop.
    """
    asyncio_loop = asyncio.get_running_loop()
    if hasattr(asyncio_loop, '_kj_loop'):
        raise RuntimeError("The KJ event-loop is already running (on this thread).")
    cdef _EventLoop kj_loop = _EventLoop()._init(asyncio_loop)
    asyncio_loop._kj_loop = kj_loop
    try:
        yield
    finally:
        # Close any asynciostream that has not been closed
        for stream in list(kj_loop.active_streams): stream.close()

        # Shut down all the RPC clients and servers
        for rpc in list(kj_loop.active_rpcs): rpc.close()

        # Cancel any pending task that is a RPC call
        # TODO: What if the cancellation is inhibited?
        tasks = list(kj_loop.active_tasks)
        for task in tasks: task.cancel()
        await asyncio.gather(*tasks, return_exceptions=True)

        try:
            del asyncio_loop._kj_loop
        except AttributeError: pass
        kj_loop.close()

async def run(coro):
    """Ensure that the coroutine runs while the KJ event loop is running

    This is a shortcut for wrapping the coroutine in a :py:meth:`capnp.kj_loop` context manager.

    :param coro: Coroutine to run
    """
    async with kj_loop():
        return await coro

cdef _EventLoop C_DEFAULT_EVENT_LOOP_GETTER():
    asyncio_loop = asyncio.get_running_loop()
    kj_loop = getattr(asyncio_loop, '_kj_loop', None)
    if kj_loop is None:
        raise RuntimeError(
            "The KJ event-loop is not running (on this thread). Please start it through 'capnp.kj_loop()'")
    elif type(kj_loop) is _EventLoop: return kj_loop
    else: raise RuntimeError("Someone meddled with the KJ event loop!")


cdef class _CallContext:
    cdef CallContext * thisptr

    cdef _init(self, CallContext other):
        helpers.allowCancellation(other)
        self.thisptr = new CallContext(move(other))
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

    cpdef tail_call(self, _Request tailRequest):
        return _voidpromise_to_asyncio(self.thisptr.tailCall(move(deref(tailRequest.thisptr_child))))


cdef _promise_to_asyncio(PyPromise promise):
    C_DEFAULT_EVENT_LOOP_GETTER() # Make sure the event loop is running
    fut = asyncio.get_running_loop().create_future()
    def success(res):   return fut.set_result(res)    if not fut.cancelled() else None
    def exception(err): return fut.set_exception(err) if not fut.cancelled() else None
    def done(fut): return fut.kjpromise.cancel() if fut.cancelled() else None
    # Attach the promise to the future, so that it doesn't get destroyed
    fut.kjpromise = _Promise()._init(helpers.then(
        move(promise),
        capnp.heap[PyRefCounter](<PyObject *>success),
        capnp.heap[PyRefCounter](<PyObject *>exception)))
    fut.add_done_callback(done)
    return fut

cdef _voidpromise_to_asyncio(VoidPromise promise):
    return _promise_to_asyncio(helpers.convert_to_pypromise(move(promise)))

cdef class _Promise:
    cdef Own[PyPromise] thisptr

    cdef _init(self, PyPromise other):
        self.thisptr = capnp.heap[PyPromise](move(other))
        return self

    cpdef cancel(self) except +reraise_kj_exception:
        self.thisptr = Own[PyPromise]()


cdef class _RemotePromise:
    cdef object _parent
    """A pointer to a parent object that needs to be kept alive for this promise to function."""

    cdef Own[RemotePromise] thisptr

    cdef _init(self, RemotePromise other, object parent=None):
        self.thisptr = capnp.heap[RemotePromise](move(other))
        self._parent = parent
        return self

    cdef void _check_consumed(self) except*:
        if self.thisptr.get() == NULL:
            raise KjException(
                "Promise was already used in a consuming operation. You can no longer use this Promise object")

    def __await__(self):
        self._check_consumed()
        cdef Own[RemotePromise] thisptr = move(self.thisptr)
        return _promise_to_asyncio(
            helpers.convert_to_pypromise(move(deref(thisptr)))
            .attach(capnp.heap[PyRefCounter](<PyObject*>self._parent))
            ).__await__()

    cpdef _get(self, field) except +reraise_kj_exception:
        self._check_consumed()
        cdef int type = (<C_DynamicValue.Pipeline>self.thisptr.get().get(field)).getType()
        if type == capnp.TYPE_CAPABILITY:
            return _DynamicCapabilityClient()._init(
                (<C_DynamicValue.Pipeline>self.thisptr.get().get(field)).asCapability(), self._parent)
        elif type == capnp.TYPE_STRUCT:
            return _DynamicStructPipeline()._init(
                new C_DynamicStruct.Pipeline(
                    (<C_DynamicValue.Pipeline>self.thisptr.get().get(field)).asStruct()), self._parent)
        elif type == capnp.TYPE_UNKNOWN:
            raise KjException("Cannot convert type to Python. Type is unknown by capnproto library")
        else:
            raise KjException("Cannot convert type to Python. Type is unhandled by capnproto library")

    def __getattr__(self, field):
        try:
            return self._get(field)
        except KjException as e:
            raise e._to_python() from None

    property schema:
        """A property that returns the _StructSchema object matching this reader"""
        def __get__(self):
            self._check_consumed()
            return _StructSchema()._init_child(self.thisptr.get().getSchema())

    def __dir__(self):
        return list(set(self.schema.fieldnames + tuple(dir(self.__class__))))

    def to_dict(self, verbose=False, ordered=False):
        return _to_dict(self, verbose, ordered)

    cpdef cancel(self) except +reraise_kj_exception:
        self.thisptr = Own[RemotePromise]()
        self._parent = None # We don't need parent anymore. Setting to none allows quicker garbage collection


cdef class _Request(_DynamicStructBuilder):
    cdef Request * thisptr_child
    cdef public bint is_consumed

    cdef _init_child(self, Request other, parent):
        self.thisptr_child = new Request(move(other))
        self._init(<DynamicStruct_Builder>deref(self.thisptr_child), parent)
        self.is_consumed = False
        return self

    def __dealloc__(self):
        del self.thisptr_child

    cpdef send(self):
        C_DEFAULT_EVENT_LOOP_GETTER() # Make sure the event loop is running
        if self.is_consumed:
            raise KjException('Request has already been sent. You can only send a request once.')
        self.is_consumed = True
        return _RemotePromise()._init(self.thisptr_child.send(), self._parent)


cdef class _Response(_DynamicStructReader):
    cdef Response * thisptr_child

    cdef _init_child(self, Response other, parent):
        self.thisptr_child = new Response(move(other))
        self._init(<C_DynamicStruct.Reader>deref(self.thisptr_child), parent)
        return self

    def __dealloc__(self):
        del self.thisptr_child

    cdef _init_childptr(self, Response * other, parent):
        self.thisptr_child = other
        self._init(<C_DynamicStruct.Reader>deref(self.thisptr_child), parent)
        return self

cdef class _DynamicCapabilityServer:
    pass

cdef class _DynamicCapabilityClient:
    cdef C_DynamicCapability.Client thisptr
    cdef public object _parent, _cached_schema

    def __dealloc__(self):
        # Needed to make Python <=3.9 happy, which seems to have trouble deallocating stack objects
        # appropriately
        self.thisptr = C_DynamicCapability.Client()

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

        kj_loop = C_DEFAULT_EVENT_LOOP_GETTER()
        self.thisptr = C_DynamicCapability.Client(
            capnp.heap[PythonInterfaceDynamicImpl](
                s.thisptr,
                capnp.heap[PyRefCounter](<PyObject*>server),
                capnp.heap[PyRefCounter](<PyObject*>kj_loop)))
        self._parent = server
        return self

    cpdef _find_method_args(self, method_name):
        s = self.schema
        meth = s.methods_inherited.get(method_name, None)
        if meth is None:
            raise AttributeError("Method named %s not found." % method_name)

        params = meth.param_type.node
        if params.scopeId != 0:
            raise KjException(
                "Cannot call method `{}` with positional args, since its param struct is not "
                "implicitly defined and thus does not have a set order of arguments".format(method_name))

        return _find_field_order(params.struct)

    cdef _set_fields(self, Request * request, name, args, kwargs):
        if args is not None and len(args) > 0:
            arg_names = self._find_method_args(name)
            if len(args) > len(arg_names):
                raise KjException(
                    "Too many arguments passed to `{}`. Expected {} and got {}"
                    .format(name, len(arg_names), len(args)))
            for arg_name, arg_val in zip(arg_names, args):
                _setDynamicField(<DynamicStruct_Builder>deref(request), arg_name, arg_val, self)

        if kwargs is not None:
            for key, val in kwargs.items():
                _setDynamicField(<DynamicStruct_Builder>deref(request), key, val, self)

    cpdef _send_helper(self, name, word_count, args, kwargs) except +reraise_kj_exception:
        # if word_count is None:
        #     word_count = 0
        C_DEFAULT_EVENT_LOOP_GETTER() # Make sure the event loop is running
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
            raise e._to_python() from None

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
        return list(set(self.schema.method_names_inherited) | set(dir(self.__class__)))


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

    def close(self):
        self.thisptr = Own[C_TwoPartyVatNetwork]()

    cdef _init(self, _AsyncIoStream stream, Side side, schema_cpp.ReaderOptions opts):
        self.stream = stream
        self.thisptr = capnp.heap[C_TwoPartyVatNetwork](deref(stream.thisptr), side, opts)
        return self

    cpdef on_disconnect(self) except +reraise_kj_exception:
        return _voidpromise_to_asyncio(deref(self.thisptr).onDisconnect())


cdef class TwoPartyClient:
    """
    TwoPartyClient for RPC Communication

    :param socket: AsyncIoStream
    :param traversal_limit_in_words: Pointer derefence limit (see https://capnproto.org/cxx.html).
    :param nesting_limit: Recursive limit when reading types (see https://capnproto.org/cxx.html).
    """
    cdef object __weakref__ # Needed to make this class weak-referenceable
    cdef Own[RpcSystem] thisptr
    cdef _TwoPartyVatNetwork _network
    cdef cbool closed

    def __dealloc__(self):
        # Needed to make Python <=3.9 happy, which seems to have trouble deallocating stack objects
        # appropriately
        self.thisptr = Own[RpcSystem]()

    def close(self):
        self.closed = True
        self.thisptr = Own[RpcSystem]()
        self._network.close()

    def __init__(self, socket=None, traversal_limit_in_words=None, nesting_limit=None):
        cdef _EventLoop loop = C_DEFAULT_EVENT_LOOP_GETTER()
        loop.active_rpcs.add(self)
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        if isinstance(socket, _AsyncIoStream):
            self._network = _TwoPartyVatNetwork()._init(socket, capnp.CLIENT, opts)
        else:
            raise ValueError(f"Argument socket should be a AsyncIoStream, was {type(socket)}")

        self.thisptr = capnp.heap[RpcSystem](makeRpcClient(deref(self._network.thisptr)))

    cpdef bootstrap(self) except +reraise_kj_exception:
        if self.closed:
            raise RuntimeError("This client is closed")
        return _CapabilityClient()._init(helpers.bootstrapHelper(deref(self.thisptr)), self)

    cpdef on_disconnect(self) except +reraise_kj_exception:
        if self.closed:
            raise RuntimeError("This client is closed")
        return self._network.on_disconnect()


cdef class TwoPartyServer:
    """
    TwoPartyServer for RPC Communication

    :param socket: AsyncIoStream
    :param bootstrap: Class object defining the implementation of the Cap'n'proto interface.
    :param traversal_limit_in_words: Pointer derefence limit (see https://capnproto.org/cxx.html).
    :param nesting_limit: Recursive limit when reading types (see https://capnproto.org/cxx.html).
    """
    cdef object __weakref__ # Needed to make this class weak-referenceable
    cdef Own[RpcSystem] thisptr
    cdef _TwoPartyVatNetwork _network
    cdef cbool closed

    def __dealloc__(self):
        # Needed to make Python <=3.9 happy, which seems to have trouble deallocating stack objects
        # appropriately
        self.thisptr = Own[RpcSystem]()

    def close(self):
        self.closed = True
        self.thisptr = Own[RpcSystem]()
        self._network.close()

    def __init__(self, socket=None, bootstrap=None, traversal_limit_in_words=None, nesting_limit=None):
        cdef _EventLoop loop = C_DEFAULT_EVENT_LOOP_GETTER()
        loop.active_rpcs.add(self)
        if not bootstrap:
            raise KjException("You must provide a bootstrap interface to a server constructor.")

        opts = make_reader_opts(traversal_limit_in_words, nesting_limit)
        if isinstance(socket, _AsyncIoStream):
            self._network = _TwoPartyVatNetwork()._init(socket, capnp.SERVER, opts)
        else:
            raise ValueError(f"Argument socket should be a AsyncIoStream, was {type(socket)}")

        cdef _InterfaceSchema schema = bootstrap.schema
        self.thisptr = capnp.heap[RpcSystem](makeRpcServer(
            deref(self._network.thisptr),
            C_DynamicCapability.Client(capnp.heap[PythonInterfaceDynamicImpl](
                schema.thisptr,
                capnp.heap[PyRefCounter](<PyObject*>bootstrap),
                capnp.heap[PyRefCounter](<PyObject*>loop)))))

    cpdef bootstrap(self) except +reraise_kj_exception:
        if self.closed:
            raise RuntimeError("This server is closed")
        return _CapabilityClient()._init(helpers.bootstrapHelperServer(deref(self.thisptr)), self)

    cpdef on_disconnect(self) except +reraise_kj_exception:
        if self.closed:
            raise RuntimeError("This server is closed")
        return _voidpromise_to_asyncio(deref(self._network.thisptr).onDisconnect()
                                       .attach(capnp.heap[PyRefCounter](<PyObject*>self)))


cdef class _AsyncIoStream:
    cdef object __weakref__ # Needed to make this class weak-referenceable
    cdef Own[AsyncIoStream] thisptr
    cdef cbool close_called
    cdef object protocol

    def __init__(self):
        cdef _EventLoop loop = C_DEFAULT_EVENT_LOOP_GETTER()
        loop.active_streams.add(self)
        self.close_called = False

    def _post_init(self, protocol):
        if not self.close_called:
            self.thisptr = <Own[AsyncIoStream]>capnp.heap[PyAsyncIoStream](
                capnp.heap[PyRefCounter](<PyObject*>protocol))
            self.protocol = protocol
        else:
            protocol.transport.close()

    def __dealloc__(self):
        # Needed to make Python <=3.9 happy, which seems to have trouble deallocating stack objects
        # appropriately
        self.thisptr = Own[AsyncIoStream]()

    def close(self):
        if self.protocol is None: # _post_init wasn't called yet
            self.close_called = True
        elif self.protocol.transport is not None and hasattr(self.protocol.transport, "close"):
            self.protocol.transport.close()
            # Call connection_lost immediately, instead of waiting for the transport to do it.
            # TODO: This might be a questionable thing to do...
            self.protocol.connection_lost("Stream is closing")

    async def wait_closed(self):
        return await self.protocol.closed_future

    @staticmethod
    async def create_connection(host = None, port = None, **kwargs):
        """Create a TCP connection.

        All parameters given to this function are passed to `asyncio.get_running_loop().create_connection()`.
        See that function for documentation on the possible arguments.
        """
        cdef _AsyncIoStream self = _AsyncIoStream()
        loop = asyncio.get_running_loop()
        transport, protocol = await loop.create_connection(
            lambda: _PyAsyncIoStreamProtocol(), host, port, **kwargs)
        self._post_init(protocol)
        return self

    @staticmethod
    async def create_unix_connection(path = None, **kwargs):
        """Create a Unix socket connection.

        All parameters given to this function are passed to `asyncio.get_running_loop().create_unix_connection()`.
        See that function for documentation on the possible arguments.
        """
        cdef _AsyncIoStream self = _AsyncIoStream()
        loop = asyncio.get_running_loop()
        transport, protocol = await loop.create_unix_connection(
            lambda: _PyAsyncIoStreamProtocol(), path, **kwargs)
        self._post_init(protocol)
        return self

    @staticmethod
    def _connect(callback):
        cdef _AsyncIoStream self = _AsyncIoStream()
        loop = asyncio.get_running_loop()
        protocol = _PyAsyncIoStreamProtocol(callback, self)
        self._post_init(protocol)
        return protocol

    @staticmethod
    async def create_server(callback, host = None, port = None, **kwargs):
        """Create a TCP connection server.

        The `callback` parameter will be called whenever a new connection is made. It receives a `AsyncIoStream`
        instance as its only argument. If the result of `callback` is a coroutine, it will be scheduled as a task.

        This function behaves similarly to `asyncio.get_running_loop().create_server()`. All arguments except
        for `callback` will be passed directly to that function, and the server returned is similar as well.
        See that function for documentation on the possible arguments.
        """
        # Fail early in case the kj loop is not running. Without this, the error is thrown when a connection is made.
        # Unless asyncio is in debug mode, that error is swallowed.
        C_DEFAULT_EVENT_LOOP_GETTER()
        loop = asyncio.get_running_loop()
        return await loop.create_server(lambda: _AsyncIoStream._connect(callback), host, port, **kwargs)

    @staticmethod
    async def create_unix_server(callback, path = None, **kwargs):
        """Create a unix connection server.

        The `callback` parameter will be called whenever a new connection is made. It receives a `AsyncIoStream`
        instance as its only argument. If the result of `callback` is a coroutine, it will be scheduled as a task.

        This function behaves similarly to `asyncio.get_running_loop().create_server()`. All arguments except
        for `callback` will be passed directly to that function, and the server returned is similar as well.
        See that function for documentation on the possible arguments.
        """
        # Fail early in case the kj loop is not running. Without this, the error is thrown when a connection is made.
        # Unless asyncio is in debug mode, that error is swallowed.
        C_DEFAULT_EVENT_LOOP_GETTER()
        loop = asyncio.get_running_loop()
        return await loop.create_unix_server(lambda: _AsyncIoStream._connect(callback), path, **kwargs)

cdef class DummyBaseClass:
    pass

cdef class _PyAsyncIoStreamProtocol(DummyBaseClass, asyncio.BufferedProtocol):
    cdef object _task

    cdef public object transport
    cdef object connected_callback
    cdef object callback_arg

    # State for reading data from the transport
    cdef char* read_buffer
    cdef int32_t read_min_bytes
    cdef size_t read_max_bytes
    cdef size_t read_already_read
    cdef PromiseFulfiller[size_t]* read_fulfiller
    cdef cbool read_eof

    # TODO: Temporary. This is an overflow buffer, which is needed for two blatant violations of the protocol.
    #       The first violation is in the the SSL transport implementation.
    #       See https://github.com/python/cpython/issues/89322, fixed in Python 3.11. This bug causes the
    #       SSL transport to force data upon us even when we've asked it to pause sending us data. Therefore,
    #       we have to store the data in a overflow buffer.
    #
    #       The second violation is that a transport cannot be paused immediately after it is connected.
    #       See https://github.com/python/cpython/issues/103607. This also causes the need to be prepared
    #       for unexpected data.
    #
    #       This extra code can be removed once both bugs are fixed in all supported python versions.
    cdef bytearray read_overflow_buffer
    cdef bytearray read_overflow_buffer_current

    # State for writing data to the transport
    cdef cbool write_paused
    cdef cbool write_in_progress
    cdef ArrayPtr[const ArrayPtr[const uint8_t]] write_pieces
    cdef size_t write_index
    cdef VoidPromiseFulfiller* write_fulfiller

    def __init__(self, connected_callback = None, callback_arg = None):
        self.connected_callback = connected_callback
        self.callback_arg = callback_arg

    def connection_made(self, transport):
        self.transport = transport

        # TODO: BUG. We want to immediately pause reading, but Python's transport implementation does not
        #       allow this. See https://github.com/python/cpython/issues/103607.
        #       To work around this, we also insert pause_reading() in get_buffer() when appropriate.
        transport.pause_reading()

        self.write_paused = False
        self.write_in_progress = False
        self.read_eof = False
        self.read_overflow_buffer = bytearray()
        def done(task):
            if self.transport is not None:
                self.transport.close()
            exc = task.exception()
            if exc is not None:
                context = {
                    'message': "Exception in pycapnp server callback",
                    'exception': exc,
                    'task': task,
                    'protocol': self,
                    'transport': self.transport
                }
                asyncio.get_running_loop().call_exception_handler(context)
        if self.connected_callback is not None:
            callback_res = self.connected_callback(self.callback_arg)
            if asyncio.iscoroutine(callback_res):
                self._task = asyncio.create_task(callback_res)
                self._task.add_done_callback(done)
            self.connected_callback = None
            self.callback_arg = None

    def connection_lost(self, exc):
        if self.read_fulfiller != NULL:
            capnp.rejectDisconnected[size_t](deref(self.read_fulfiller), StringPtr(str(exc)))
            self.read_buffer = NULL
            self.read_fulfiller = NULL
        if self.write_fulfiller != NULL:
            capnp.rejectVoidDisconnected(deref(self.write_fulfiller), StringPtr(str(exc)))
            self.write_reset()
            self.write_paused = True
        self.transport = None
        self._task = None

    def get_buffer(self, size_hint):
        if self.read_buffer == NULL: # Should not happen, but for SSL it does, see comment above

            # TODO: Bug. Workaround for the transport ignoring pause_reading() in connection_made()
            self.transport.pause_reading()

            size = size_hint if size_hint > 0 else 100
            self.read_overflow_buffer_current = bytearray(size)
            return self.read_overflow_buffer_current
        else:
            return memoryview.PyMemoryView_FromMemory(self.read_buffer, self.read_max_bytes, buffer.PyBUF_WRITE)

    def buffer_updated(self, size):
        if self.read_buffer == NULL: # Should not happen, but for SSL it does, see comment above
            self.read_overflow_buffer.extend(self.read_overflow_buffer_current[0:size])
        else:
            self.read_buffer += size
            self.read_min_bytes -= size
            self.read_max_bytes -= size
            self.read_already_read += size
            if self.read_min_bytes <= 0:
                self.read_fulfiller.fulfill(move(self.read_already_read))
                self.read_reset()

    def pause_writing(self):
        self.write_paused = True

    def resume_writing(self):
        self.write_paused = False
        self.write_loop()

    def eof_received(self):
        self.read_eof = True
        if self.read_buffer != NULL:
            self.read_fulfiller.fulfill(move(self.read_already_read))
            self.read_reset()

    cdef write_loop(self):
        if self.write_paused or not self.write_in_progress: return
        cdef const ArrayPtr[const uint8_t]* piece
        for i in range(self.write_index, self.write_pieces.size()):
            piece = &self.write_pieces[i]
            view = memoryview.PyMemoryView_FromMemory(<char*>piece.begin(), piece.size(), buffer.PyBUF_READ)
            self.transport.write(view)
            if self.write_paused:
                self.write_index = i+1
                break
        if not self.write_paused:
            self.write_fulfiller.fulfill()
            self.write_reset()

    cdef read_reset(self):
        self.transport.pause_reading()
        self.read_buffer = NULL
        self.read_fulfiller = NULL

    cdef write_reset(self):
        self.write_in_progress = False
        self.write_fulfiller = NULL


cdef api void _asyncio_stream_write_start(
    object thisptr, ArrayPtr[const ArrayPtr[const uint8_t]] pieces,
    VoidPromiseFulfiller& fulfiller) except*:
    cdef _PyAsyncIoStreamProtocol self = <_PyAsyncIoStreamProtocol>thisptr
    if self.transport is None or self.transport.is_closing():
        capnp.rejectVoidDisconnected(fulfiller, StringPtr("Socket is closing."))
        return
    self.write_pieces = pieces
    self.write_index = 0
    self.write_fulfiller = &fulfiller
    self.write_in_progress = True
    self.write_loop()

cdef api void _asyncio_stream_write_stop(object thisptr):
    (<_PyAsyncIoStreamProtocol>thisptr).write_reset()

cdef api void _asyncio_stream_read_start(
    object thisptr, void* buffer, size_t min_bytes, size_t max_bytes,
    PromiseFulfiller[size_t]& fulfiller) except*:
    cdef _PyAsyncIoStreamProtocol self = <_PyAsyncIoStreamProtocol>thisptr
    if self.transport is None or self.transport.is_closing():
        capnp.rejectDisconnected(fulfiller, StringPtr("Socket is closing"))
        return
    if self.read_eof:
        self.read_fulfiller.fulfill(0)
        return
    self.read_buffer = <char*>buffer
    self.read_min_bytes = min_bytes
    self.read_max_bytes = max_bytes
    self.read_already_read = 0
    self.read_fulfiller = &fulfiller

    # Begin of draining the overflow buffer, which is created because of a bug in SSL, see comment above.
    # Can be removed once Python < 3.11 is not longer supported.
    if self.read_overflow_buffer:
        to_copy = min(len(self.read_overflow_buffer), max_bytes)
        memcpy(buffer, <char*>self.read_overflow_buffer, to_copy)
        del self.read_overflow_buffer[:to_copy]
        self.read_buffer += to_copy
        self.read_min_bytes -= to_copy
        self.read_max_bytes -= to_copy
        self.read_already_read += to_copy
        if self.read_min_bytes <= 0:
            self.read_fulfiller.fulfill(move(self.read_already_read))
            self.read_reset()
            return # resume_reading no longer needed
    # End of draining the overflow buffer.

    self.transport.resume_reading()

cdef api void _asyncio_stream_read_stop(object thisptr):
    cdef _PyAsyncIoStreamProtocol self = <_PyAsyncIoStreamProtocol>thisptr
    if self.transport is not None: self.read_reset()

cdef api void _asyncio_stream_shutdown_write(object thisptr) except*:
    cdef _PyAsyncIoStreamProtocol self = <_PyAsyncIoStreamProtocol>thisptr
    if self.transport is not None and self.transport.can_write_eof():
        self.transport.write_eof()

cdef api void _asyncio_stream_close(object thisptr) except*:
    cdef _PyAsyncIoStreamProtocol self = <_PyAsyncIoStreamProtocol>thisptr
    # Careful, the transport object may have already been partially destroyed here.
    if self.transport is not None and hasattr(self.transport, "close"):
        self.transport.close()


cdef class _Schema:
    cdef _init(self, C_Schema other):
        self.thisptr = other
        return self

    cpdef as_const_value(self):
        return to_python_reader(<C_DynamicValue.Reader>self.thisptr.asConst(), self)

    cpdef as_struct(self):
        return _StructSchema()._init_child(self.thisptr.asStruct())

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


cdef class _StructSchema(_Schema):
    cdef C_StructSchema thisptr_child
    cdef object __fieldnames, __union_fields, __non_union_fields, __fields, __getters
    cdef list __fields_list
    cdef _init_child(self, C_StructSchema other):
        self.thisptr_child = other
        self._init(other)
        self.__fieldnames = None
        self.__union_fields = None
        self.__non_union_fields = None
        self.__fields = None
        self.__fields_list = None
        self.__getters = None
        return self

    cdef C_StructSchema _thisptr(self):
        return self.thisptr_child

    property fieldnames:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__fieldnames is not None:
                return self.__fieldnames
            fieldlist = self._thisptr().getFields()
            nfields = fieldlist.size()
            self.__fieldnames = tuple(<char*>fieldlist[i].getProto().getName().cStr() for i in xrange(nfields))
            return self.__fieldnames

    property union_fields:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__union_fields is not None:
                return self.__union_fields
            fieldlist = self._thisptr().getUnionFields()
            nfields = fieldlist.size()
            self.__union_fields = tuple(
                <char*>fieldlist[i].getProto().getName().cStr() for i in xrange(nfields))
            return self.__union_fields

    property non_union_fields:
        """A tuple of the field names in the struct."""
        def __get__(self):
            if self.__non_union_fields is not None:
                return self.__non_union_fields
            fieldlist = self._thisptr().getNonUnionFields()
            nfields = fieldlist.size()
            self.__non_union_fields = tuple(
                <char*>fieldlist[i].getProto().getName().cStr() for i in xrange(nfields))
            return self.__non_union_fields

    property fields:
        """All of the _StructSchemaField in this schema as a dict"""
        def __get__(self):
            if self.__fields is not None:
                return self.__fields
            fieldlist = self._thisptr().getFields()
            nfields = fieldlist.size()
            self.__fields = {
                <char*>fieldlist[i].getProto().getName().cStr(): _StructSchemaField()._init(fieldlist[i], self)
                for i in xrange(nfields)
            }
            return self.__fields

    property fields_list:
        """All of the _StructSchemaField in this schema as a list"""
        def __get__(self):
            if self.__fields_list is not None:
                return self.__fields_list
            fieldlist = self._thisptr().getFields()
            nfields = fieldlist.size()
            self.__fields_list = [_StructSchemaField()._init(fieldlist[i], self) for i in xrange(nfields)]
            return self.__fields_list

    property node:
        """The raw schema node"""
        def __get__(self):
            return _DynamicStructReader()._init(self._thisptr().getProto(), self)

    def __richcmp__(_StructSchema self, _StructSchema other, mode):
        if mode == 2:
            return self._thisptr() == other._thisptr()
        elif mode == 3:
            return not (self._thisptr() == other._thisptr())
        else:
            raise NotImplementedError()

    def __repr__(self):
        return '<schema for %s>' % self.node.displayName


cdef typeAsSchema(capnp.SchemaType fieldType):
    # TODO(soon): make sure this is memory safe
    if fieldType.isInterface():
        return _InterfaceSchema()._init(fieldType.asInterface())
    elif fieldType.isStruct():
        return _StructSchema()._init_child(fieldType.asStruct())
    elif fieldType.isEnum():
        return _EnumSchema()._init(fieldType.asEnum())
    elif fieldType.isList():
        return _ListSchema()._init(fieldType.asList())
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
            return _StructSchema()._init_child(self.thisptr.getParamType())

    property result_type:
        """The type of this method's result struct"""
        def __get__(self):
            # TODO(soon): make sure this is memory safe
            return _StructSchema()._init_child(self.thisptr.getResultType())


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
            self.__method_names = tuple(
                <char*>fieldlist[i].getProto().getName().cStr() for i in xrange(nfields))
            return self.__method_names

    property method_names_inherited:
        """A set of the function names in the interface, including inherited methods"""
        def __get__(self):
            if self.__method_names_inherited is not None:
                return self.__method_names_inherited

            fieldlist = self.thisptr.getMethods()
            nfields = fieldlist.size()
            self.__method_names_inherited = set(
                <char*>fieldlist[i].getProto().getName().cStr() for i in xrange(nfields))
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
            self.__methods = {
                fieldlist[i].getProto().getName().cStr(): _InterfaceMethod()._init(fieldlist[i])
                for i in xrange(nfields)
            }
            return self.__methods

    property methods_inherited:
        """A mapping of method names to their respective _InterfaceMethod, including inherited methods"""
        def __get__(self):
            if self.__methods_inherited is not None:
                return self.__methods_inherited

            fieldlist = self.thisptr.getMethods()
            nfields = fieldlist.size()
            # TODO(soon): make sure this is memory safe
            self.__methods_inherited = {
                fieldlist[i].getProto().getName().cStr(): _InterfaceMethod()._init(fieldlist[i])
                for i in xrange(nfields)
            }
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


cdef class _ListSchema:
    cdef C_ListSchema thisptr

    def __init__(self, schema=None):
        cdef _StructSchema ss
        cdef _EnumSchema es
        cdef _InterfaceSchema iis
        cdef _ListSchema ls
        cdef _SchemaType st

        if schema is not None:
            if hasattr(schema, 'schema'):
                s = schema.schema
            else:
                s = schema

            typeSchema = type(s)
            if typeSchema is _StructSchema:
                ss = s
                self.thisptr = capnp.listSchemaOfStruct(ss._thisptr())
            elif typeSchema is _EnumSchema:
                es = s
                self.thisptr = capnp.listSchemaOfEnum(es.thisptr)
            elif typeSchema is _InterfaceSchema:
                iis = s
                self.thisptr = capnp.listSchemaOfInterface(iis.thisptr)
            elif typeSchema is _ListSchema:
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


class _StructModuleWhich(_enum.Enum):
    def __eq__(self, other):
        if isinstance(other, int):
            return self.value == other
        else:
            return self.name == other


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
                    mapping = []
                    for union_field in field_schema.fields:
                        mapping.append((union_field.name, union_field.discriminantValue))
                    sub_module = _StructModuleWhich("StructModuleWhich", mapping)
                    setattr(sub_module, 'schema', raw_schema)
                setattr(self, name, sub_module)
        if schema.union_fields and not schema.non_union_fields:
            mapping = []
            for union_field in schema.node.struct.fields:
                name = union_field.name
                name = name[0].upper() + name[1:]
                mapping.append((name, union_field.discriminantValue))
            sub_module = _StructModuleWhich("StructModuleWhich", mapping)
            setattr(self, 'Union', sub_module)

    def read(self, file, traversal_limit_in_words=None, nesting_limit=None):
        """Returns a Reader for the unpacked object read from file.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`"""
        reader = _StreamFdMessageReader(file, traversal_limit_in_words, nesting_limit)
        return reader.get_root(self.schema)

    async def read_async(self, _AsyncIoStream stream, traversal_limit_in_words=None, nesting_limit=None):
        """Async version of read(). Returns either a message, or None in case of EOF.

        :type file: AsyncIoStream
        :param file: A AsyncIoStream

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`"""
        C_DEFAULT_EVENT_LOOP_GETTER() # Make sure the event loop is running
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)
        reader = await _promise_to_asyncio(tryReadMessage(deref(stream.thisptr), opts))
        if reader is None:
            return
        return reader.get_root(self.schema)

    def read_multiple(self, file, traversal_limit_in_words=None, nesting_limit=None, skip_copy=False):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type skip_copy: bool
        :param skip_copy: By default, each message is copied because the file needs to advance, even if the message is
                          never read completely. Skip this only if you know what you're doing.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultipleMessageReader(file, self.schema, traversal_limit_in_words, nesting_limit, skip_copy)
        return reader

    def read_packed(self, file, traversal_limit_in_words=None, nesting_limit=None):
        """Returns a Reader for the packed object read from file.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`"""
        reader = _PackedFdMessageReader(file, traversal_limit_in_words, nesting_limit)
        return reader.get_root(self.schema)

    def read_multiple_packed(self, file, traversal_limit_in_words=None, nesting_limit=None, skip_copy=False):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type skip_copy: bool
        :param skip_copy: By default, each message is copied because the file needs to advance, even if the message is
                          never read completely. Skip this only if you know what you're doing.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultiplePackedMessageReader(file, self.schema, traversal_limit_in_words, nesting_limit, skip_copy)
        return reader

    def read_multiple_bytes(self, buf, traversal_limit_in_words=None, nesting_limit=None):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultipleBytesMessageReader(buf, self.schema, traversal_limit_in_words, nesting_limit)
        return reader

    def read_multiple_bytes_packed(self, buf, traversal_limit_in_words=None, nesting_limit=None):
        """Returns an iterable, that when traversed will return Readers for messages.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`"""
        reader = _MultipleBytesPackedMessageReader(buf, self.schema, traversal_limit_in_words, nesting_limit)
        return reader

    @contextlib.contextmanager
    def from_bytes(self, buf, traversal_limit_in_words=None, nesting_limit=None, builder=False):
        """Returns a Reader for the unpacked object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type builder: bool
        :param builder: If true, return a builder object.

        Enabling `builder` will allow you to change the contents of `buf`, so do this with care.

        :rtype: :class:`_DynamicStructReader` or :class:`_DynamicStructBuilder`
        """
        message = None
        try:
            if builder:
                # message = _FlatMessageBuilder(buf)
                message = _FlatArrayMessageReader(buf, traversal_limit_in_words, nesting_limit)
                yield message.get_root(self.schema).as_builder()
            else:
                message = _FlatArrayMessageReader(buf, traversal_limit_in_words, nesting_limit)
                yield message.get_root(self.schema)
        finally:
            if message:
                message.close()

    def from_segments(self, segments, traversal_limit_in_words=None, nesting_limit=None):
        """Returns a Reader for a list of segment bytes.

        This avoids making copies.

        NB: This is not currently supported on PyPy.

        :rtype: list
        """
        message = _SegmentArrayMessageReader(segments, traversal_limit_in_words, nesting_limit)
        return message.get_root(self.schema)

    def from_bytes_packed(self, buf, traversal_limit_in_words=None, nesting_limit=None):
        """Returns a Reader for the packed object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the readable buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

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
        :param num_first_segment_words: Size of the first segment to allocate (in words ie. 8 byte increments)

        :type kwargs: dict
        :param kwargs: A list of fields and their values to initialize in the struct.

        Note, kwargs is not an actual argument, but refers to Python's ability to pass keyword arguments.
        ie. new_message(my_field=100)

        :rtype: :class:`_DynamicStructBuilder`
        """
        return _new_message(self, kwargs, num_first_segment_words)


class _InterfaceModule(object):
    def __init__(self, schema, name):
        def server_init(server_self):
            pass
        self.schema = schema
        self.Server = type(name + '.Server', (_DynamicCapabilityServer,), {'__init__': server_init, 'schema':schema})

    def _new_client(self, server):
        return _DynamicCapabilityClient()._init_vals(self.schema, server)


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


cdef class SchemaLoader:
    """ Class which can be used to construct Schema objects from schema::Nodes as defined in
    schema.capnp.
    
    This class wraps capnproto/c++/src/capnp/schema-loader.h directly."""
    def __cinit__(self):
        self.thisptr = new C_SchemaLoader()
    
    def __dealloc__(self):
        del self.thisptr

    def load(self, _NodeReader reader):
        """Loads the given schema node.  Validates the node and throws an exception if invalid.  This
        makes a copy of the schema, so the object passed in can be destroyed after this returns.
        
        """
        return _Schema()._init(self.thisptr.load(reader.thisptr))

    def load_dynamic(self, _DynamicStructReader reader):
        """Loads the given schema node with self.load, but converts from a _DynamicStructReader
        first."""
        return _Schema()._init(self.thisptr.load(helpers.toReader(reader.thisptr)))
    
    def get(self, id_):
        """Gets the schema for the given ID, throwing an exception if it isn't present."""
        return _Schema()._init(self.thisptr.get(<uint64_t>id_))


cdef class SchemaParser:
    """A class for loading Cap'n Proto schema files.

    Do not use this class unless you're sure you know what you're doing.
    Use the convenience method :func:`load` instead.
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
        return _DynamicStructBuilder()._init(self.thisptr.initRootDynamicStruct(s._thisptr()), self, True)

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
        return _DynamicStructBuilder()._init(self.thisptr.getRootDynamicStruct(s._thisptr()), self, True)

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

        Don't use this method unless you know what you're doing.
        Orphans are useful for dynamically allocating objects for an unknown sized list, ie::

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

        return _DynamicOrphan()._init(self.thisptr.newOrphan(s._thisptr()), self)


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
        return _DynamicStructReader()._init(self.thisptr.getRootDynamicStruct(s._thisptr()), self)

    cpdef get_root_as_any(self) except +reraise_kj_exception:
        """A method for getting a Cap'n Proto AnyPointer, from an already pre-written buffer

        Don't use this method unless you know what you're doing.

        :rtype: :class:`_DynamicObjectReader`
        :return: An AnyPointer that you can read from
        """
        return _DynamicObjectReader()._init(self.thisptr.getRootAnyPointer(), self)


cdef class _StreamFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor

    You use this class to for reading message(s) from a file. It's analagous to the inverse of
    :func:`_write_message_to_fd` and :class:`_MessageBuilder`, but in one class::

        f = open('out.txt')
        message = _StreamFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, file, traversal_limit_in_words=None, nesting_limit=None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = file
        cdef int fd = file.fileno()
        with nogil:
            self.thisptr = new schema_cpp.StreamFdMessageReader(fd, opts)

    def __dealloc__(self):
        del self.thisptr


cdef class _PackedMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of
    :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self):
        pass

    cdef _init(self, schema_cpp.BufferedInputStream & stream,
               traversal_limit_in_words=None, nesting_limit=None, parent=None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = parent
        with nogil:
            self.thisptr = new schema_cpp.PackedMessageReader(stream, opts)
        return self

    def __dealloc__(self):
        del self.thisptr


cdef class _PackedMessageReaderBytes(_MessageReader):
    cdef schema_cpp.ArrayInputStream * stream
    cdef Py_buffer view

    def __init__(self, buf, traversal_limit_in_words=None, nesting_limit=None):
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

    You use this class to for reading message(s) from a file. It's analagous to the inverse of
    :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self):
        pass

    cdef _init(self, schema_cpp.BufferedInputStream & stream,
               traversal_limit_in_words=None, nesting_limit=None, parent=None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = parent
        with nogil:
            self.thisptr = new schema_cpp.InputStreamMessageReader(stream, opts)
        return self

    def __dealloc__(self):
        del self.thisptr


cdef class _PackedFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of
    :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(self, file, traversal_limit_in_words=None, nesting_limit=None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)

        self._parent = file
        cdef int fd = file.fileno()
        with nogil:
            self.thisptr = new schema_cpp.PackedFdMessageReader(fd, opts)

    def __dealloc__(self):
        del self.thisptr

cdef class _AsyncMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a AsyncIoStream class.

    Do not use directly
    """

    def __init__(self):
        pass

    cdef Own[MessageReader] reader
    cdef _init(self, Own[MessageReader] reader):
        self.reader = move(reader)
        self.thisptr = self.reader.get()
        return self

cdef api object make_async_message_reader(Own[MessageReader] reader):
    return _AsyncMessageReader()._init(move(reader))


cdef class _MultipleMessageReader:
    cdef schema_cpp.FdInputStream * stream
    cdef schema_cpp.BufferedInputStream * buffered_stream
    cdef cbool skip_copy

    cdef public object traversal_limit_in_words, nesting_limit, schema, file

    def __init__(self, file, schema, traversal_limit_in_words=None, nesting_limit=None, skip_copy=False):
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
            reader = _InputMessageReader()._init(
                deref(self.buffered_stream), self.traversal_limit_in_words, self.nesting_limit, self)
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

    def __init__(self, file, schema, traversal_limit_in_words=None, nesting_limit=None, skip_copy=False):
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
            reader = _PackedMessageReader()._init(
                deref(self.buffered_stream), self.traversal_limit_in_words, self.nesting_limit, self)
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

    def __init__(self, buf, schema, traversal_limit_in_words=None, nesting_limit=None):
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
            reader._init(self._object_to_pin, self.ptr + self.offset, self.sz - self.offset,
                         self.traversal_limit_in_words, self.nesting_limit)
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

    def __init__(self, buf, schema, traversal_limit_in_words=None, nesting_limit=None):
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
            reader = _PackedMessageReader()._init(
                deref(self.buffered_stream), self.traversal_limit_in_words, self.nesting_limit, self)
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
    cdef int closed

    def __init__(self, other):
        cdef int ret = PyObject_GetBuffer(other, &self.view, PyBUF_SIMPLE)
        if ret < 0:
            raise ValueError("Invalid buffer passed to BufferView")
        self.buf = <char*>self.view.buf
        self.closed = False

    def close(self):
        if not self.closed:
            PyBuffer_Release(&self.view)
            self.closed = True

    def __dealloc__(self):
        self.close()


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

    cdef _init(self, buf, const char *ptr, Py_ssize_t sz, traversal_limit_in_words=None, nesting_limit=None):
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
    cdef _BufferView _buffer_view

    def __init__(self, buf, traversal_limit_in_words=None, nesting_limit=None):
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
            self._buffer_view = None
        elif PyObject_CheckBuffer(buf):
            view = _BufferView(buf)
            ptr = view.buf
            self._object_to_pin = view
            self._buffer_view = view
        else:
            raise TypeError('expected buffer-like object in FlatArrayMessageReader')

        self.thisptr = new schema_cpp.FlatArrayMessageReader(
            schema_cpp.WordArrayPtr(<schema_cpp.word*>ptr, sz//8),
            opts)

    def close(self):
        if self._buffer_view:
            self._buffer_view.close()

    def __dealloc__(self):
        self.close()
        del self.thisptr


@cython.internal
cdef class _SegmentArrayMessageReader(_MessageReader):

    cdef object _objects_to_pin
    cdef uint num_segments
    cdef schema_cpp.ConstWordArrayPtr* _seg_ptrs
    cdef Py_buffer* views

    def __init__(self, segments, traversal_limit_in_words=None, nesting_limit=None):
        cdef schema_cpp.ReaderOptions opts = make_reader_opts(traversal_limit_in_words, nesting_limit)
        # take a Python array of bytes and constructs a ConstWordArrayArrayPtr
        num_segments = len(segments)
        cdef schema_cpp.ConstWordArrayPtr seg_ptr
        self._seg_ptrs = <schema_cpp.ConstWordArrayPtr*>malloc(num_segments * sizeof(schema_cpp.ConstWordArrayPtr))
        self.views = <Py_buffer*>malloc(num_segments * sizeof(Py_buffer))
        self.num_segments = num_segments
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
        for i in range(0, self.num_segments):
            PyBuffer_Release(&self.views[i])
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
        self.thisptr = new schema_cpp.FlatMessageBuilder(
            schema_cpp.WordArrayPtr(<schema_cpp.word*>self.view.buf, self.view.len // 8))

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
    with nogil:
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
    with nogil:
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


# Automatically include the system and built-in capnp paths
# Highest priority at position 0
_capnp_paths = [
    # Common macOS brew location
    '/usr/local/include',
    # Common posix location
    '/usr/include',
]

class _Loader:
    def __init__(self, fullname, path):
        self.fullname = fullname
        self.path = path

    def load_module(self, fullname):
        assert self.fullname == fullname, (
            "invalid module, expected {}, got {}".format(self.fullname, fullname))

        imports = _capnp_paths + [path if path != '' else '.' for path in _sys.path]
        module = load(self.path, fullname, imports=imports)
        _sys.modules[fullname] = module

        return module


class _Importer:

    def find_spec(self, fullname, package_path, target=None):
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
        capnp_module_name = module_name + '.capnp'

        capnp_module_names = set()
        capnp_module_names.add(capnp_module_name)
        if '_' in capnp_module_name:
            capnp_module_names.add(capnp_module_name.replace('_', '-'))
            capnp_module_names.add(capnp_module_name.replace('_', ' '))

        if package_path:
            paths = list(package_path)
        else:
            paths = _sys.path

        # Special case for the 'capnp' namespace, which can be resolved to system paths
        if fullname.startswith('capnp.'):
            paths += [path + '/capnp' for path in _capnp_paths]

        for path in paths:
            if not path:
                path = _os.getcwd()
            elif not _os.path.isabs(path):
                path = _os.path.abspath(path)

            for capnp_module_name in capnp_module_names:
                if _os.path.isfile(path+_os.path.sep+capnp_module_name):
                    return ModuleSpec(fullname, _Loader(fullname, _os.path.join(path, capnp_module_name)))


_importer = None


def add_import_hook():
    """Add a hook to the python import system, so that Cap'n Proto modules are directly importable

    After calling this function, you can use the python import syntax to directly import capnproto schemas.
    This function is automatically called upon first import of `capnp`,
    so you will typically never need to use this function.::

        import capnp
        capnp.add_import_hook()

        import addressbook_capnp
        # equivalent to capnp.load('addressbook.capnp', 'addressbook', sys.path),
        # except it will search for 'addressbook.capnp' in all directories of sys.path

    """
    global _importer
    if _importer is not None:
        remove_import_hook()

    _importer = _Importer()
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
