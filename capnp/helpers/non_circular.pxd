from cpython.ref cimport PyObject
from libcpp cimport bool

cdef extern from "capnp/helpers/capabilityHelper.h":
    void c_reraise_kj_exception()
    cdef cppclass PyRefCounter:
        PyRefCounter(PyObject *)
        PyObject * obj
