from cpython.ref cimport PyObject
from libcpp cimport bool

cdef extern from "capnp/helpers/capabilityHelper.h":
    cppclass PythonInterfaceDynamicImpl:
        PythonInterfaceDynamicImpl(PyObject *)
    void reraise_kj_exception()
    cdef cppclass PyRefCounter:
        PyRefCounter(PyObject *)
        PyObject * obj
