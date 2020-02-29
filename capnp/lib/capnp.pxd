# cython: language_level = 2

from capnp.includes cimport capnp_cpp as capnp
from capnp.includes cimport schema_cpp
from capnp.includes.capnp_cpp cimport Schema as C_Schema, StructSchema as C_StructSchema, InterfaceSchema as C_InterfaceSchema, EnumSchema as C_EnumSchema, ListSchema as C_ListSchema, DynamicStruct as C_DynamicStruct, DynamicValue as C_DynamicValue, Type as C_Type, DynamicList as C_DynamicList, SchemaParser as C_SchemaParser, ParsedSchema as C_ParsedSchema, VOID, ArrayPtr, StringPtr, String, StringTree, DynamicOrphan as C_DynamicOrphan, AnyPointer as C_DynamicObject, DynamicCapability as C_DynamicCapability, Request, Response, RemotePromise, Promise, CallContext, RpcSystem, makeRpcServerBootstrap, makeRpcClient, Capability as C_Capability, TwoPartyVatNetwork as C_TwoPartyVatNetwork, Side, AsyncIoStream, Own, makeTwoPartyVatNetwork, PromiseFulfillerPair as C_PromiseFulfillerPair, copyPromiseFulfillerPair, newPromiseAndFulfiller, PyArray, DynamicStruct_Builder, TwoWayPipe
from capnp.includes.schema_cpp cimport Node as C_Node, EnumNode as C_EnumNode
from capnp.includes.types cimport *
from capnp.helpers.non_circular cimport reraise_kj_exception
from capnp.helpers cimport helpers


cdef class _StructSchemaField:
    cdef C_StructSchema.Field thisptr
    cdef object _parent
    cdef _init(self, C_StructSchema.Field other, parent=?)

cdef class _StringArrayPtr:
    cdef StringPtr * thisptr
    cdef object parent
    cdef size_t size
    cdef ArrayPtr[StringPtr] asArrayPtr(self) except +reraise_kj_exception

cdef class SchemaParser:
    cdef C_SchemaParser * thisptr
    cdef public dict modules_by_id
    cdef list _all_imports
    cdef _StringArrayPtr _last_import_array
    cpdef _parse_disk_file(self, displayName, diskPath, imports) except +reraise_kj_exception

cdef class _DynamicOrphan:
    cdef C_DynamicOrphan thisptr
    cdef public object _parent

    cdef _init(self, C_DynamicOrphan other, object parent)

    cdef C_DynamicOrphan move(self)
    cpdef get(self)


cdef class _DynamicStructReader:
    cdef C_DynamicStruct.Reader thisptr
    cdef public object _parent
    cdef public bint is_root
    cdef object _obj_to_pin
    cdef object _schema

    cdef _init(self, C_DynamicStruct.Reader other, object parent, bint isRoot=?, bint tryRegistry=?)

    cpdef _get(self, field)
    cpdef _has(self, field)
    cpdef _DynamicEnumField _which(self)
    cpdef _which_str(self)
    cpdef _get_by_field(self, _StructSchemaField field)
    cpdef _has_by_field(self, _StructSchemaField field)

    cpdef as_builder(self, num_first_segment_words=?)


cdef class _DynamicStructBuilder:
    cdef DynamicStruct_Builder thisptr
    cdef public object _parent
    cdef public bint is_root
    cdef public bint _is_written
    cdef object _schema

    cdef _init(self, DynamicStruct_Builder other, object parent, bint isRoot=?, bint tryRegistry=?)

    cdef _check_write(self)
    cpdef to_bytes(_DynamicStructBuilder self) except +reraise_kj_exception
    cpdef to_segments(_DynamicStructBuilder self) except +reraise_kj_exception
    cpdef _to_bytes_packed_helper(_DynamicStructBuilder self, word_count) except +reraise_kj_exception
    cpdef to_bytes_packed(_DynamicStructBuilder self) except +reraise_kj_exception

    cpdef _get(self, field)
    cpdef _set(self, field, value)
    cpdef _has(self, field)
    cpdef init(self, field, size=?)
    cpdef _get_by_field(self, _StructSchemaField field)
    cpdef _set_by_field(self, _StructSchemaField field, value)
    cpdef _has_by_field(self, _StructSchemaField field)
    cpdef _init_by_field(self, _StructSchemaField field, size=?)
    cpdef init_resizable_list(self, field)
    cpdef _DynamicEnumField _which(self)
    cpdef _which_str(self)
    cpdef adopt(self, field, _DynamicOrphan orphan)
    cpdef disown(self, field)

    cpdef as_reader(self)
    cpdef copy(self, num_first_segment_words=?)

cdef class _DynamicEnumField:
    cdef object thisptr

    cdef _init(self, proto)
    cpdef _str(self)

cdef class _Schema:
    cdef C_Schema thisptr

    cdef _init(self, C_Schema other)

    cpdef as_const_value(self)
    cpdef as_struct(self)
    cpdef as_interface(self)
    cpdef as_enum(self)
    cpdef get_proto(self)

cdef class _InterfaceSchema:
    cdef C_InterfaceSchema thisptr
    cdef object __method_names, __method_names_inherited, __methods, __methods_inherited
    cdef _init(self, C_InterfaceSchema other)

cdef class _DynamicEnum:
    cdef capnp.DynamicEnum thisptr
    cdef public object _parent

    cdef _init(self, capnp.DynamicEnum other, object parent)
    cpdef _as_str(self) except +reraise_kj_exception

cdef class _DynamicListBuilder:
    cdef C_DynamicList.Builder thisptr
    cdef public object _parent
    cdef _init(self, C_DynamicList.Builder other, object parent)

    cpdef _get(self, int64_t index)
    cpdef _set(self, index, value)

    cpdef adopt(self, index, _DynamicOrphan orphan)
    cpdef disown(self, index)

    cpdef init(self, index, size)

cdef class _MessageBuilder:
    cdef schema_cpp.MessageBuilder * thisptr
    cpdef init_root(self, schema)
    cpdef get_root(self, schema) except +reraise_kj_exception
    cpdef get_root_as_any(self) except +reraise_kj_exception
    cpdef set_root(self, value) except +reraise_kj_exception
    cpdef get_segments_for_output(self) except +reraise_kj_exception
    cpdef new_orphan(self, schema) except +reraise_kj_exception

cdef to_python_reader(C_DynamicValue.Reader self, object parent)
cdef to_python_builder(C_DynamicValue.Builder self, object parent)
cdef _to_dict(msg, bint verbose, bint ordered)
cdef _from_list(_DynamicListBuilder msg, list d)
cdef _from_tuple(_DynamicListBuilder msg, tuple d)
cdef _setDynamicFieldWithField(DynamicStruct_Builder thisptr, _StructSchemaField field, value, parent)
cdef _setDynamicFieldStatic(DynamicStruct_Builder thisptr, field, value, parent)

cdef api object wrap_dynamic_struct_reader(Response & r) with gil
cdef api PyObject * wrap_remote_call(PyObject * func, Response & r) except * with gil
cdef api Promise[void] * call_server_method(PyObject * _server, char * _method_name, CallContext & _context) except * with gil
cdef api convert_array_pyobject(PyArray & arr) with gil
cdef api Promise[PyObject*] * extract_promise(object obj) with gil
cdef api RemotePromise * extract_remote_promise(object obj) with gil
cdef api object wrap_kj_exception(capnp.Exception & exception) with gil
cdef api object wrap_kj_exception_for_reraise(capnp.Exception & exception) with gil
cdef api object get_exception_info(object exc_type, object exc_obj, object exc_tb) with gil
