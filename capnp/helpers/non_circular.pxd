from cpython.ref cimport PyObject

cdef extern from "../helpers/capabilityHelper.h":
    cppclass PythonInterfaceDynamicImpl:
        PythonInterfaceDynamicImpl(PyObject *)

cdef extern from "../helpers/capabilityHelper.h":
    void reraise_kj_exception()
    cdef cppclass PyRefCounter:
        PyRefCounter(PyObject *)