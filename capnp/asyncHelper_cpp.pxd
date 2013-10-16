# schema.capnp.cpp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11

from cpython.ref cimport PyObject
from capnp_cpp cimport PyPromise, EventLoop

cdef extern from "asyncHelper.h":
    PyPromise evalLater(EventLoop &, PyObject * func)
    PyPromise there(EventLoop & loop, PyPromise & promise, PyObject * func, PyObject * error_func)
    PyPromise then(PyPromise & promise, PyObject * func, PyObject * error_func)

    # cdef cppclass PyEventLoop(EventLoop):
    #     pass