# schema.capnp.cpp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11

from cpython.ref cimport PyObject

cdef extern from "kj/exception.h" namespace " ::kj":
    cdef cppclass Exception:
        pass
        
cdef extern from "kj/async.h" namespace " ::kj":
    cdef cppclass Promise[T]:
        Promise(Promise)
        T wait()

ctypedef Promise[PyObject *] PyPromise

cdef extern from "kj/async.h" namespace " ::kj":
    cdef cppclass EventLoop:
        EventLoop()
        # Promise[void] yield_end'yield'()
        object wait(PyPromise) except+
        object there(PyPromise) except+
        PyPromise evalLater(PyObject * func)
        PyPromise there(PyPromise, PyObject * func)
    cdef cppclass SimpleEventLoop(EventLoop):
        pass

cdef extern from "asyncHelper.h":
    PyPromise evalLater(EventLoop &, PyObject * func)
    PyPromise there(EventLoop & loop, PyPromise & promise, PyObject * func, PyObject * error_func)
    PyPromise then(PyPromise & promise, PyObject * func, PyObject * error_func)
    PyPromise yield_end(EventLoop & loop)

    # cdef cppclass PyEventLoop(EventLoop):
    #     pass