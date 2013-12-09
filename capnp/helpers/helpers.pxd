from .capnp.includes.capnp_cpp cimport Maybe, DynamicStruct, Request, PyPromise, VoidPromise, RemotePromise, DynamicCapability, InterfaceSchema, EnumSchema, StructSchema, DynamicValue, Capability, RpcSystem, MessageBuilder, MessageReader, TwoPartyVatNetwork

from non_circular cimport reraise_kj_exception

from cpython.ref cimport PyObject

cdef extern from "../helpers/fixMaybe.h":
    EnumSchema.Enumerant fixMaybe(Maybe[EnumSchema.Enumerant]) except +reraise_kj_exception
    char * getEnumString(DynamicStruct.Reader val)
    char * getEnumString(DynamicStruct.Builder val)
    char * getEnumString(Request val)

cdef extern from "../helpers/capabilityHelper.h":
    # PyPromise evalLater(EventLoop &, PyObject * func)
    # PyPromise there(EventLoop & loop, PyPromise & promise, PyObject * func, PyObject * error_func)
    PyPromise then(PyPromise & promise, PyObject * func, PyObject * error_func)
    VoidPromise then(RemotePromise & promise, PyObject * func, PyObject * error_func)
    PyPromise then(VoidPromise & promise, PyObject * func, PyObject * error_func)
    DynamicCapability.Client new_client(InterfaceSchema&, PyObject *)
    DynamicValue.Reader new_server(InterfaceSchema&, PyObject *)
    Capability.Client server_to_client(InterfaceSchema&, PyObject *)
    PyPromise convert_to_pypromise(RemotePromise&)

cdef extern from "../helpers/rpcHelper.h":
    cdef cppclass PyRestorer:
        PyRestorer(PyObject *, StructSchema&)
    Capability.Client restoreHelper(RpcSystem&, MessageBuilder&)
    Capability.Client restoreHelper(RpcSystem&, MessageReader&)
    RpcSystem makeRpcClientWithRestorer(TwoPartyVatNetwork&, PyRestorer&)
