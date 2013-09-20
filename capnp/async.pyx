# capnp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11 -fpermissive
# distutils: libraries = kj
# cython: c_string_type = str
# cython: c_string_encoding = default
# cython: embedsignature = True

cimport cython
cimport async_cpp as async
from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from cython.operator cimport dereference as deref

cdef extern from "<utility>" namespace "std":
    async.PyPromise movePromise"std::move"(async.PyPromise)

# By making it public, we'll be able to call it from asyncHelper.h
cdef public object wrap_kj_exception(async.Exception & exception):
    return None # TODO

cdef class EventLoop:
    cdef async.SimpleEventLoop thisptr

    cpdef evalLater(self, func):
        Py_INCREF(func)
        return Promise()._init(async.evalLater(self.thisptr, <PyObject *>func))

    cpdef wait(self, Promise promise) except+:
        if promise.is_consumed:
            raise RuntimeError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = self.thisptr.wait(movePromise(deref(promise.thisptr)))
        promise.is_consumed = True

        return ret

    cpdef there(self, Promise promise, object func, object error_func=None):
        if promise.is_consumed:
            raise RuntimeError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        Py_INCREF(func)
        Py_INCREF(error_func)
        return Promise()._init(async.there(self.thisptr, deref(promise.thisptr), <PyObject *>func, <PyObject *>error_func))

cdef class Promise:
    cdef async.PyPromise * thisptr
    cdef public bint is_consumed

    def __init__(self):
        self.is_consumed = True

    cdef _init(self, async.PyPromise other):
        self.is_consumed = False
        self.thisptr = new async.PyPromise(movePromise(other))
        return self

    def __dealloc__(self):
        del self.thisptr

    cpdef wait(self) except+:
        if self.is_consumed:
            raise RuntimeError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        ret = <object>self.thisptr.wait()
        self.is_consumed = True

        return ret

    cpdef then(self, func, error_func=None) except+:
        if self.is_consumed:
            raise RuntimeError('Promise was already used in a consuming operation. You can no longer use this Promise object')

        Py_INCREF(func)
        Py_INCREF(error_func)

        return Promise()._init(async.then(deref(self.thisptr), <PyObject *>func, <PyObject *>error_func))

# from gevent.event import Event, AsyncResult
# import gevent

# cdef object _event = Event()
# cdef object _start_loop = AsyncResult()

# def _start_event_loop():
#     loop = EventLoop()
#     _start_loop.set(loop)
#     _event.wait()
#     _event.clear()

# _event_loop_greenlet = gevent.spawn(_start_event_loop)

# event_loop = _start_loop.get()
# _event.set()

# cdef public void _gevent_eventloop_prepare_to_sleep():
#     _event.clear()

# cdef public void _gevent_eventloop_sleep():
#     _event.wait()

# cdef public void _gevent_eventloop_wake():
#     _event.set()
