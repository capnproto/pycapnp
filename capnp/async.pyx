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

    cdef wait(self, async.PyPromise * promise):
        return self.thisptr.wait(movePromise(deref(promise)))

    cdef there(self, async.PyPromise * promise, object func, object error_func):
        Py_INCREF(func)
        Py_INCREF(error_func)
        return Promise()._init(async.there(self.thisptr, deref(promise), <PyObject *>func, <PyObject *>error_func))


cdef EventLoop c_event_loop = EventLoop()
event_loop = c_event_loop

cdef class Promise:
    cdef async.PyPromise * thisptr
    cdef _init(self, async.PyPromise other):
        self.thisptr = new async.PyPromise(movePromise(other))
        return self

    def __dealloc__(self):
        del self.thisptr

    def wait(self):
        return c_event_loop.wait(self.thisptr)

    def then(self, func, error_func=None):
        return c_event_loop.there(self.thisptr, func, error_func)

