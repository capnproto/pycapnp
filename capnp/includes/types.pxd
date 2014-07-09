from cpython.ref cimport PyObject, Py_INCREF, Py_DECREF
from libc.stdint cimport *
ctypedef unsigned int uint
ctypedef uint8_t byte
ctypedef uint8_t UInt8
ctypedef uint16_t UInt16
ctypedef uint32_t UInt32
ctypedef uint64_t UInt64
ctypedef int8_t Int8
ctypedef int16_t Int16
ctypedef int32_t Int32
ctypedef int64_t Int64

ctypedef char * Object
ctypedef bint Bool
ctypedef float Float32
ctypedef double Float64
from libcpp cimport bool as cbool