from .capnp.includes cimport capnp_cpp as capnp
from .capnp.includes cimport schema_cpp
from .capnp.includes.capnp_cpp cimport Schema as C_Schema, StructSchema as C_StructSchema, InterfaceSchema as C_InterfaceSchema, EnumSchema as C_EnumSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue, Type as C_Type, DynamicList as C_DynamicList, SchemaParser as C_SchemaParser, ParsedSchema as C_ParsedSchema, VOID, ArrayPtr, StringPtr, String, StringTree, DynamicOrphan as C_DynamicOrphan, AnyPointer as C_DynamicObject, DynamicCapability as C_DynamicCapability, Request, Response, RemotePromise, PyPromise, VoidPromise, CallContext, PyRestorer, RpcSystem, makeRpcServer, makeRpcClient, Capability as C_Capability, TwoPartyVatNetwork as C_TwoPartyVatNetwork, Side, AsyncIoStream, Own, makeTwoPartyVatNetwork, PromiseFulfillerPair as C_PromiseFulfillerPair, copyPromiseFulfillerPair, newPromiseAndFulfiller, PyArray, DynamicStruct_Builder
from .capnp.includes.schema_cpp cimport Node as C_Node, EnumNode as C_EnumNode
from .capnp.includes.types cimport *
from .capnp.helpers.non_circular cimport reraise_kj_exception
from .capnp.helpers cimport helpers

cdef class _DynamicStructReader:
    cdef C_DynamicStruct.Reader thisptr
    cdef public object _parent
    cdef public bint is_root
    cdef object _obj_to_pin

    cdef _init(self, C_DynamicStruct.Reader other, object parent, bint isRoot=?)

    cpdef _which(self)

    cpdef as_builder(self)