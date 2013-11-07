# schema.capnp.cpp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
from schema_cpp cimport Node, Data, StructNode, EnumNode
from async_cpp cimport PyPromise, VoidPromise, Promise

from cpython.ref cimport PyObject
from libc.stdint cimport *
ctypedef unsigned int uint
from libcpp cimport bool as cbool

cdef extern from "capnp/common.h" namespace " ::capnp":
    enum Void:
        VOID " ::capnp::VOID"

cdef extern from "kj/exception.h" namespace " ::kj":
    cdef cppclass Exception:
        pass

cdef extern from "kj/string.h" namespace " ::kj":
    cdef cppclass StringPtr:
        StringPtr(char *)
    cdef cppclass String:
        char* cStr()

cdef extern from "kj/string-tree.h" namespace " ::kj":
    cdef cppclass StringTree:
        String flatten()

cdef extern from "kj/common.h" namespace " ::kj":
    cdef cppclass Maybe[T]:
        pass
    cdef cppclass ArrayPtr[T]:
        ArrayPtr()
        ArrayPtr(T *, size_t size)
        size_t size()
        T& operator[](size_t index)

cdef extern from "kj/array.h" namespace " ::kj":
    cdef cppclass Array[T]:
        T* begin()
        size_t size()

cdef extern from "capnp/schema.h" namespace " ::capnp":
    cdef cppclass Schema:
        Node.Reader getProto() except +
        StructSchema asStruct() except +
        EnumSchema asEnum() except +
        ConstSchema asConst() except +
        Schema getDependency(uint64_t id) except +
        InterfaceSchema asInterface() except +

    cdef cppclass InterfaceSchema(Schema):
        pass

    cdef cppclass StructSchema(Schema):
        cppclass Field:
            StructNode.Member.Reader getProto()
            StructSchema getContainingStruct()
            uint getIndex()

        cppclass FieldList:
            uint size()
            Field operator[](uint index)

        cppclass FieldSubset:
            uint size()
            Field operator[](uint index)

        FieldList getFields()
        FieldSubset getUnionFields()
        FieldSubset getNonUnionFields()

        Field getFieldByName(char * name)

        cbool operator == (StructSchema)

    cdef cppclass EnumSchema:
        cppclass Enumerant:
            EnumNode.Enumerant.Reader getProto()
            EnumSchema getContainingEnum()
            uint16_t getOrdinal()

        cppclass EnumerantList:
            uint size()
            Enumerant operator[](uint index)

        EnumerantList getEnumerants()
        Enumerant getEnumerantByName(char * name)
        Node.Reader getProto()

    cdef cppclass ConstSchema:
        pass

cdef extern from "capnp/dynamic.h" namespace " ::capnp":
    cdef cppclass DynamicValueForward" ::capnp::DynamicValue":
        cppclass Reader:
            pass
        cppclass Builder:
            pass
        cppclass Pipeline:
            pass

    enum Type:
        TYPE_UNKNOWN " ::capnp::DynamicValue::UNKNOWN"
        TYPE_VOID " ::capnp::DynamicValue::VOID"
        TYPE_BOOL " ::capnp::DynamicValue::BOOL"
        TYPE_INT " ::capnp::DynamicValue::INT"
        TYPE_UINT " ::capnp::DynamicValue::UINT"
        TYPE_FLOAT " ::capnp::DynamicValue::FLOAT"
        TYPE_TEXT " ::capnp::DynamicValue::TEXT"
        TYPE_DATA " ::capnp::DynamicValue::DATA"
        TYPE_LIST " ::capnp::DynamicValue::LIST"
        TYPE_ENUM " ::capnp::DynamicValue::ENUM"
        TYPE_STRUCT " ::capnp::DynamicValue::STRUCT"
        TYPE_CAPABILITY " ::capnp::DynamicValue::CAPABILITY"
        TYPE_OBJECT " ::capnp::DynamicValue::OBJECT"

    cdef cppclass DynamicStruct:
        cppclass Reader:
            DynamicValueForward.Reader get(char *) except +ValueError
            bint has(char *) except +ValueError
            StructSchema getSchema()
            Maybe[StructSchema.Field] which()
        cppclass Builder:
            Builder()
            Builder(Builder &)
            DynamicValueForward.Builder get(char *) except +ValueError
            bint has(char *) except +ValueError
            void set(char *, DynamicValueForward.Reader) except +ValueError
            DynamicValueForward.Builder init(char *, uint size) except +ValueError
            DynamicValueForward.Builder init(char *) except +ValueError
            StructSchema getSchema()
            Maybe[StructSchema.Field] which()
            void adopt(char *, DynamicOrphan) except +ValueError
            DynamicOrphan disown(char *)
            DynamicStruct.Reader asReader()
        cppclass Pipeline:
            Pipeline()
            Pipeline(Pipeline &)
            DynamicValueForward.Pipeline get(char *)
            StructSchema getSchema()

cdef extern from "capnp/capability.h" namespace " ::capnp":
    cdef cppclass Response" ::capnp::Response< ::capnp::DynamicStruct>"(DynamicStruct.Reader):
        Response(Response)
    cdef cppclass RemotePromise" ::capnp::RemotePromise< ::capnp::DynamicStruct>"(Promise[Response], DynamicStruct.Pipeline):
        RemotePromise(RemotePromise)

cdef extern from "capnp/dynamic.h" namespace " ::capnp":
    cdef cppclass Request" ::capnp::Request< ::capnp::DynamicStruct, ::capnp::DynamicStruct>":
        Request()
        Request(Request &)
        DynamicValueForward.Builder get(char *) except +ValueError
        bint has(char *) except +ValueError
        void set(char *, DynamicValueForward.Reader) except +ValueError
        DynamicValueForward.Builder init(char *, uint size) except +ValueError
        DynamicValueForward.Builder init(char *) except +ValueError
        StructSchema getSchema()
        Maybe[StructSchema.Field] which()
        RemotePromise send()

    cdef cppclass DynamicCapability:
        cppclass Client:
            Client upcast(InterfaceSchema requestedSchema)
            InterfaceSchema getSchema()
            Request newRequest(char * methodName, uint firstSegmentWordSize)

cdef extern from "capnp/object.h" namespace " ::capnp":
    cdef cppclass ObjectPointer:
        cppclass Reader:
            DynamicStruct.Reader getAs"getAs< ::capnp::DynamicStruct>"(StructSchema)
        cppclass Builder:
            Builder(Builder)
            DynamicStruct.Builder getAs"getAs< ::capnp::DynamicStruct>"(StructSchema)

cdef extern from "fixMaybe.h":
    EnumSchema.Enumerant fixMaybe(Maybe[EnumSchema.Enumerant]) except +ValueError
    char * getEnumString(DynamicStruct.Reader val)
    char * getEnumString(DynamicStruct.Builder val)
    char * getEnumString(Request val)

cdef extern from "capabilityHelper.h":
    PyPromise evalLater(EventLoop &, PyObject * func)
    PyPromise there(EventLoop & loop, PyPromise & promise, PyObject * func, PyObject * error_func)
    PyPromise then(PyPromise & promise, PyObject * func, PyObject * error_func)
    VoidPromise then(RemotePromise & promise, PyObject * func, PyObject * error_func)
    cppclass PythonInterfaceDynamicImpl:
        PythonInterfaceDynamicImpl(PyObject *)
    DynamicCapability.Client new_client(InterfaceSchema&, PyObject *, EventLoop&)
    DynamicValueForward.Reader new_server(InterfaceSchema&, PyObject *)
    PyPromise convert_to_pypromise(RemotePromise&)

cdef extern from "capnp/dynamic.h" namespace " ::capnp":
    cdef cppclass DynamicEnum:
        uint16_t getRaw()
        Maybe[EnumSchema.Enumerant] getEnumerant()

    cdef cppclass DynamicList:
        cppclass Reader:
            DynamicValueForward.Reader operator[](uint) except +ValueError
            uint size()
        cppclass Builder:
            Builder()
            Builder(Builder &)
            DynamicValueForward.Builder operator[](uint) except +ValueError
            uint size()
            void set(uint index, DynamicValueForward.Reader value) except +ValueError
            DynamicValueForward.Builder init(uint index, uint size) except +ValueError
            void adopt(uint, DynamicOrphan) except +ValueError
            DynamicOrphan disown(uint)
            StructSchema getStructElementType'getSchema().getStructElementType'()

    cdef cppclass DynamicValue:
        cppclass Reader:
            Reader()
            Reader(Void value)
            Reader(cbool value)
            Reader(char value)
            Reader(short value)
            Reader(int value)
            Reader(long value)
            Reader(long long value)
            Reader(unsigned char value)
            Reader(unsigned short value)
            Reader(unsigned int value)
            Reader(unsigned long value)
            Reader(unsigned long long value)
            Reader(float value)
            Reader(double value)
            Reader(char* value)
            Reader(DynamicList.Reader& value)
            Reader(DynamicEnum value)
            Reader(DynamicStruct.Reader& value)
            Reader(DynamicCapability.Client& value)
            Reader(PythonInterfaceDynamicImpl& value)
            Type getType()
            int64_t asInt"as<int64_t>"()
            uint64_t asUint"as<uint64_t>"()
            bint asBool"as<bool>"()
            double asDouble"as<double>"()
            String asText"as< ::capnp::Text>"()
            DynamicList.Reader asList"as< ::capnp::DynamicList>"()
            DynamicStruct.Reader asStruct"as< ::capnp::DynamicStruct>"()
            ObjectPointer.Reader asObject"as< ::capnp::ObjectPointer>"()
            DynamicCapability.Client asCapability"as< ::capnp::DynamicCapability>"()
            DynamicEnum asEnum"as< ::capnp::DynamicEnum>"()
            Data.Reader asData"as< ::capnp::Data>"()

        cppclass Builder:
            Type getType()
            int64_t asInt"as<int64_t>"()
            uint64_t asUint"as<uint64_t>"()
            bint asBool"as<bool>"()
            double asDouble"as<double>"()
            String asText"as< ::capnp::Text>"()
            DynamicList.Builder asList"as< ::capnp::DynamicList>"()
            DynamicStruct.Builder asStruct"as< ::capnp::DynamicStruct>"()
            ObjectPointer.Builder asObject"as< ::capnp::ObjectPointer>"()
            DynamicCapability.Client asCapability"as< ::capnp::DynamicCapability>"()
            DynamicEnum asEnum"as< ::capnp::DynamicEnum>"()
            Data.Builder asData"as< ::capnp::Data>"()

        cppclass Pipeline:
            Pipeline(Pipeline)
            DynamicCapability.Client asCapability"releaseAs< ::capnp::DynamicCapability>"()
            DynamicStruct.Pipeline asStruct"releaseAs< ::capnp::DynamicStruct>"()
            Type getType()

cdef extern from "capnp/schema-parser.h" namespace " ::capnp":
    cdef cppclass ParsedSchema(Schema):
        ParsedSchema getNested(char * name) except +
    cdef cppclass SchemaParser:
        SchemaParser()
        ParsedSchema parseDiskFile(char * displayName, char * diskPath, ArrayPtr[StringPtr] importPath) except +

cdef extern from "capnp/orphan.h" namespace " ::capnp":
    cdef cppclass DynamicOrphan" ::capnp::Orphan< ::capnp::DynamicValue>":
        DynamicValue.Builder get()
        DynamicValue.Reader getReader()

cdef extern from "capnp/capability.h" namespace " ::capnp":
    cdef cppclass CallContext' ::capnp::CallContext< ::capnp::DynamicStruct, ::capnp::DynamicStruct>':
        CallContext(CallContext&)
        DynamicStruct.Reader getParams() except +
        void releaseParams()

        DynamicStruct.Builder getResults(uint firstSegmentWordSize)
        DynamicStruct.Builder initResults(uint firstSegmentWordSize)
        void setResults(DynamicStruct.Reader value)
        # void adoptResults(Orphan<Results>&& value);
        # Orphanage getResultsOrphanage(uint firstSegmentWordSize = 0);
        void allowAsyncCancellation(bint allow = true)
        bint isCanceled()

cdef extern from "kj/async.h" namespace " ::kj":
    cdef cppclass EventLoop:
        EventLoop()
        # Promise[void] yield_end'yield'()
        object wait(PyPromise) except+
        Response wait_remote'wait'(RemotePromise)
        object there(PyPromise) except+
        PyPromise evalLater(PyObject * func)
        PyPromise there(PyPromise, PyObject * func)
    cdef cppclass SimpleEventLoop(EventLoop):
        pass
