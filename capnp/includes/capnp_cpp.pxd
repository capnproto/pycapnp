# schema.capnp.cpp.pyx
# distutils: language = c++
cdef extern from "capnp/helpers/checkCompiler.h":
    pass

from libcpp cimport bool
from capnp.helpers.non_circular cimport PythonInterfaceDynamicImpl, reraise_kj_exception, PyRefCounter, PyEventPort, ErrorHandler
from capnp.includes.schema_cpp cimport Node, Data, StructNode, EnumNode, InterfaceNode, MessageBuilder, MessageReader, ReaderOptions
from capnp.includes.types cimport *

cdef extern from "capnp/common.h" namespace " ::capnp":
    enum Void:
        VOID " ::capnp::VOID"
    cdef cppclass MessageSize:
        uint64_t wordCount
        uint capCount

cdef extern from "capnp/common.h":
    int CAPNP_VERSION_MAJOR
    int CAPNP_VERSION_MINOR
    int CAPNP_VERSION_MICRO
    int CAPNP_VERSION

cdef extern from "kj/string.h" namespace " ::kj":
    cdef cppclass StringPtr:
        StringPtr()
        StringPtr(char *)
        StringPtr(char *, size_t)
        char* cStr()
        size_t size()
        char* begin()
    cdef cppclass String:
        char* cStr()
        size_t size()
        char* begin()

cdef extern from "kj/exception.h" namespace " ::kj":
    cdef cppclass Exception:
        Exception(Exception)
        char* getFile()
        int getLine()
        int getType()
        StringPtr getDescription()

cdef extern from "kj/memory.h" namespace " ::kj":
    cdef cppclass Own[T]:
        T& operator*()
        T* get()
    Own[TwoPartyVatNetwork] makeTwoPartyVatNetwork" ::kj::heap< ::capnp::TwoPartyVatNetwork>"(AsyncIoStream& stream, Side, ReaderOptions)
    Own[PromiseFulfillerPair] copyPromiseFulfillerPair" ::kj::heap< ::kj::PromiseFulfillerPair<void> >"(PromiseFulfillerPair&)
    Own[PyRefCounter] makePyRefCounter" ::kj::heap< PyRefCounter >"(PyObject *)

cdef extern from "kj/async.h" namespace " ::kj":
    cdef cppclass Promise[T] nogil:
        Promise()
        Promise(Promise)
        Promise(T)
        T wait(WaitScope)
        bool poll(WaitScope)
        # ForkedPromise<T> fork()
        # Promise<T> exclusiveJoin(Promise<T>&& other)
        # Promise[T] eagerlyEvaluate()
        # void detach(ErrorFunc)
        String trace()
        Promise[T] attach(Own[PyRefCounter] &)
        Promise[T] attach(Own[PyRefCounter] &, Own[PyRefCounter] &)
        Promise[T] attach(Own[PyRefCounter] &, Own[PyRefCounter] &, Own[PyRefCounter] &)
        Promise[T] attach(Own[PyRefCounter] &, Own[PyRefCounter] &, Own[PyRefCounter] &, Own[PyRefCounter] &)

ctypedef Promise[PyObject *] PyPromise
ctypedef Promise[void] VoidPromise

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
        T& operator[](size_t index)
    cdef cppclass ArrayBuilder[T]:
        T* begin()
        size_t size()
        T& operator[](size_t index)
        T& add(T&)
        Array[T] finish()

    ArrayBuilder[PyPromise] heapArrayBuilderPyPromise"::kj::heapArrayBuilder< ::kj::Promise<PyObject *> >"(size_t)

    ctypedef Array[PyObject *] PyArray' ::kj::Array<PyObject *>'

ctypedef Promise[PyArray] PyPromiseArray

cdef extern from "kj/time.h" namespace " ::kj":
    cdef cppclass Duration:
        Duration operator*(int64_t)
    Duration NANOSECONDS
    Duration MICROSECONDS
    Duration MILLISECONDS
    Duration SECONDS
    Duration MINUTES
    Duration HOURS
    Duration DAYS
    # cdef cppclass TimePoint:
    #     TimePoint(Duration)
    cdef cppclass Timer:
        # int64_t now()
        # VoidPromise atTime(TimePoint time)
        VoidPromise afterDelay(Duration delay)

cdef inline Duration Nanoseconds(int64_t nanos):
    return NANOSECONDS * nanos

cdef extern from "kj/async-io.h" namespace " ::kj":
    cdef cppclass AsyncIoStream:
        Promise[size_t] read(void*, size_t, size_t)
        Promise[void] write(const void*, size_t)

    cdef cppclass LowLevelAsyncIoProvider:
        # Own[AsyncInputStream] wrapInputFd(int)
        # Own[AsyncOutputStream] wrapOutputFd(int)
        Own[AsyncIoStream] wrapSocketFd(int)
        Timer& getTimer() except +reraise_kj_exception

    cdef cppclass AsyncIoProvider:
        TwoWayPipe newTwoWayPipe()

    cdef cppclass WaitScope:
        pass

    cdef cppclass AsyncIoContext:
        AsyncIoContext(AsyncIoContext&)
        Own[LowLevelAsyncIoProvider] lowLevelProvider
        Own[AsyncIoProvider] provider
        WaitScope waitScope

    cdef cppclass TaskSet:
        TaskSet(ErrorHandler &)

    cdef cppclass TwoWayPipe:
        Own[AsyncIoStream] ends[2]

    AsyncIoContext setupAsyncIo()

cdef extern from "capnp/schema.capnp.h" namespace " ::capnp":
    enum TypeWhich" ::capnp::schema::Type::Which":
        TypeWhichVOID " ::capnp::schema::Type::Which::VOID"
        TypeWhichBOOL " ::capnp::schema::Type::Which::BOOL"
        TypeWhichINT8 " ::capnp::schema::Type::Which::INT8"
        TypeWhichINT16 " ::capnp::schema::Type::Which::INT16"
        TypeWhichINT32 " ::capnp::schema::Type::Which::INT32"
        TypeWhichINT64 " ::capnp::schema::Type::Which::INT64"
        TypeWhichUINT8 " ::capnp::schema::Type::Which::UINT8"
        TypeWhichUINT16 " ::capnp::schema::Type::Which::UINT16"
        TypeWhichUINT32 " ::capnp::schema::Type::Which::UINT32"
        TypeWhichUINT64 " ::capnp::schema::Type::Which::UINT64"
        TypeWhichFLOAT32 " ::capnp::schema::Type::Which::FLOAT32"
        TypeWhichFLOAT64 " ::capnp::schema::Type::Which::FLOAT64"
        TypeWhichTEXT " ::capnp::schema::Type::Which::TEXT"
        TypeWhichDATA " ::capnp::schema::Type::Which::DATA"
        TypeWhichLIST " ::capnp::schema::Type::Which::LIST"
        TypeWhichENUM " ::capnp::schema::Type::Which::ENUM"
        TypeWhichSTRUCT " ::capnp::schema::Type::Which::STRUCT"
        TypeWhichINTERFACE " ::capnp::schema::Type::Which::INTERFACE"
        TypeWhichANY_POINTER " ::capnp::schema::Type::Which::ANY_POINTER"

cdef extern from "capnp/schema.h" namespace " ::capnp":
    cdef cppclass SchemaType" ::capnp::Type":
        SchemaType()
        SchemaType(TypeWhich)
        cbool isList()
        cbool isEnum()
        cbool isStruct()
        cbool isInterface()

        StructSchema asStruct() except +reraise_kj_exception
        EnumSchema asEnum() except +reraise_kj_exception
        InterfaceSchema asInterface() except +reraise_kj_exception
        ListSchema asList() except +reraise_kj_exception

    cdef cppclass Schema:
        Node.Reader getProto() except +reraise_kj_exception
        StructSchema asStruct() except +reraise_kj_exception
        EnumSchema asEnum() except +reraise_kj_exception
        ConstSchema asConst() except +reraise_kj_exception
        Schema getDependency(uint64_t id) except +reraise_kj_exception
        InterfaceSchema asInterface() except +reraise_kj_exception

    cdef cppclass InterfaceSchema(Schema):
        cppclass SuperclassList:
            uint size()
            InterfaceSchema operator[](uint index)

        cppclass Method:
            InterfaceNode.Method.Reader getProto()
            InterfaceSchema getContainingInterface()
            uint16_t getOrdinal()
            uint getIndex()
            StructSchema getParamType()
            StructSchema getResultType()

        cppclass MethodList:
            uint size()
            Method operator[](uint index)

        MethodList getMethods()
        Maybe[Method] findMethodByName(StringPtr name)
        Method getMethodByName(StringPtr name)
        bint extends(InterfaceSchema other)
        SuperclassList getSuperclasses()
        # kj::Maybe<InterfaceSchema> findSuperclass(uint64_t typeId) const;

    cdef cppclass StructSchema(Schema):
        cppclass Field:
            StructNode.Member.Reader getProto()
            StructSchema getContainingStruct()
            uint getIndex()
            SchemaType getType()

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

    cdef cppclass ListSchema:
        SchemaType getElementType()

    ListSchema listSchemaOfStruct" ::capnp::ListSchema::of"(StructSchema)
    ListSchema listSchemaOfEnum" ::capnp::ListSchema::of"(EnumSchema)
    ListSchema listSchemaOfInterface" ::capnp::ListSchema::of"(InterfaceSchema)
    ListSchema listSchemaOfList" ::capnp::ListSchema::of"(ListSchema)
    ListSchema listSchemaOfType" ::capnp::ListSchema::of"(SchemaType)

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
        TYPE_ANY_POINTER " ::capnp::DynamicValue::ANY_POINTER"

    cdef cppclass DynamicStruct:
        cppclass Reader:
            DynamicValueForward.Reader get(char *) except +reraise_kj_exception
            DynamicValueForward.Reader getByField"get"(StructSchema.Field) except +reraise_kj_exception
            bint has(char *) except +reraise_kj_exception
            bint hasByField"has"(StructSchema.Field) except +reraise_kj_exception
            StructSchema getSchema()
            uint64_t getId"getSchema().getProto().getId"()
            Maybe[StructSchema.Field] which()
            MessageSize totalSize()
        cppclass Pipeline:
            Pipeline()
            Pipeline(Pipeline &)
            DynamicValueForward.Pipeline get(char *)
            StructSchema getSchema()

    cdef cppclass DynamicStruct_Builder" ::capnp::DynamicStruct::Builder": # Need to flatten this class out, since nested C++ classes cause havoc with cython fused types
        DynamicStruct_Builder()
        DynamicStruct_Builder(DynamicStruct_Builder &)
        DynamicValueForward.Builder get(char *) except +reraise_kj_exception
        DynamicValueForward.Builder getByField"get"(StructSchema.Field) except +reraise_kj_exception
        bint has(char *) except +reraise_kj_exception
        bint hasByField"has"(StructSchema.Field) except +reraise_kj_exception
        void set(char *, DynamicValueForward.Reader) except +reraise_kj_exception
        void setByField"set"(StructSchema.Field, DynamicValueForward.Reader) except +reraise_kj_exception
        DynamicValueForward.Builder init(char *, uint size) except +reraise_kj_exception
        DynamicValueForward.Builder init(char *) except +reraise_kj_exception
        DynamicValueForward.Builder initByField"init"(StructSchema.Field, uint size) except +reraise_kj_exception
        DynamicValueForward.Builder initByField"init"(StructSchema.Field) except +reraise_kj_exception
        StructSchema getSchema()
        uint64_t getId"getSchema().getProto().getId"()
        Maybe[StructSchema.Field] which()
        void adopt(char *, DynamicOrphan) except +reraise_kj_exception
        DynamicOrphan disown(char *)
        DynamicStruct.Reader asReader()
        MessageSize totalSize()

cdef extern from "capnp/dynamic.h" namespace " ::capnp":
    cdef cppclass DynamicCapability:
        cppclass Client:
            Client()
            Client(Client&)
            Client upcast(InterfaceSchema requestedSchema)
            DynamicCapability.Client castAs"castAs< ::capnp::DynamicCapability>"(InterfaceSchema)
            InterfaceSchema getSchema()
            Request newRequest(char * methodName)
            # Request newRequest(char * methodName, MessageSize)

cdef extern from "capnp/capability.h" namespace " ::capnp":
    cdef cppclass Response" ::capnp::Response< ::capnp::DynamicStruct>"(DynamicStruct.Reader):
        Response(Response)
    cdef cppclass RemotePromise" ::capnp::RemotePromise< ::capnp::DynamicStruct>"(Promise[Response], DynamicStruct.Pipeline):
        RemotePromise(RemotePromise)
    cdef cppclass Capability:
        cppclass Client:
            Client(Client&)
            DynamicCapability.Client castAs"castAs< ::capnp::DynamicCapability>"(InterfaceSchema)

cdef extern from "capnp/rpc-twoparty.h" namespace " ::capnp":
    cdef cppclass RpcSystem" ::capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>":
        RpcSystem(RpcSystem&&)

    cdef cppclass Side" ::capnp::rpc::twoparty::Side":
        pass
    cdef Side CLIENT" ::capnp::rpc::twoparty::Side::CLIENT"
    cdef Side SERVER" ::capnp::rpc::twoparty::Side::SERVER"

    cdef cppclass TwoPartyVatNetwork:
        TwoPartyVatNetwork(EventLoop &, AsyncIoStream& stream, Side, ReaderOptions)
        VoidPromise onDisconnect()
        VoidPromise onDrained()
    RpcSystem makeRpcServerBootstrap"makeRpcServer"(TwoPartyVatNetwork&, Capability.Client)
    RpcSystem makeRpcClient(TwoPartyVatNetwork&)

cdef extern from "capnp/dynamic.h" namespace " ::capnp":
    cdef cppclass Request" ::capnp::Request< ::capnp::DynamicStruct, ::capnp::DynamicStruct>":
        Request()
        Request(Request &)
        DynamicValueForward.Builder get(char *) except +reraise_kj_exception
        bint has(char *) except +reraise_kj_exception
        void set(char *, DynamicValueForward.Reader) except +reraise_kj_exception
        DynamicValueForward.Builder init(char *, uint size) except +reraise_kj_exception
        DynamicValueForward.Builder init(char *) except +reraise_kj_exception
        StructSchema getSchema()
        Maybe[StructSchema.Field] which()
        RemotePromise send()

cdef extern from "capnp/dynamic.h" namespace " ::capnp":
    cdef cppclass DynamicEnum:
        uint16_t getRaw()
        Maybe[EnumSchema.Enumerant] getEnumerant()

    cdef cppclass DynamicList:
        cppclass Reader:
            DynamicValueForward.Reader operator[](uint) except +reraise_kj_exception
            uint size()
        cppclass Builder:
            Builder()
            Builder(Builder &)
            DynamicValueForward.Builder operator[](uint) except +reraise_kj_exception
            uint size()
            void set(uint index, DynamicValueForward.Reader value) except +reraise_kj_exception
            DynamicValueForward.Builder init(uint index, uint size) except +reraise_kj_exception
            void adopt(uint, DynamicOrphan) except +reraise_kj_exception
            DynamicOrphan disown(uint)
            StructSchema getStructElementType'getSchema().getStructElementType'()

cdef extern from "capnp/any.h" namespace " ::capnp":
    cdef cppclass AnyPointer:
        cppclass Reader:
            DynamicStruct.Reader getAs"getAs< ::capnp::DynamicStruct>"(StructSchema) except +reraise_kj_exception
            DynamicCapability.Client getAsCapability"getAs< ::capnp::DynamicCapability>"(InterfaceSchema) except +reraise_kj_exception
            DynamicList.Reader getAsList"getAs< ::capnp::DynamicList>"(ListSchema) except +reraise_kj_exception
            StringPtr getAsText"getAs< ::capnp::Text>"() except +reraise_kj_exception
        cppclass Builder:
            Builder(Builder)
            DynamicStruct_Builder getAs"getAs< ::capnp::DynamicStruct>"(StructSchema) except +reraise_kj_exception
            DynamicCapability.Client getAsCapability"getAs< ::capnp::DynamicCapability>"(InterfaceSchema) except +reraise_kj_exception
            DynamicList.Builder getAsList"getAs< ::capnp::DynamicList>"(ListSchema) except +reraise_kj_exception
            StringPtr getAsText"getAs< ::capnp::Text>"() except +reraise_kj_exception
            void setAsStruct"setAs< ::capnp::DynamicStruct>"(DynamicStruct.Reader&) except +reraise_kj_exception
            void setAsText"setAs< ::capnp::Text>"(char*) except +reraise_kj_exception
            AnyPointer.Reader asReader() except +reraise_kj_exception
            void set(AnyPointer.Reader) except +reraise_kj_exception
            DynamicStruct_Builder initAsStruct"initAs< ::capnp::DynamicStruct>"(StructSchema) except +reraise_kj_exception
            DynamicList.Builder initAsList"initAs< ::capnp::DynamicList>"(ListSchema, uint) except +reraise_kj_exception


cdef extern from "capnp/dynamic.h" namespace " ::capnp":
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
            Reader(StringPtr value)
            Reader(DynamicList.Reader& value)
            Reader(DynamicEnum value)
            Reader(DynamicStruct.Reader& value)
            Reader(DynamicCapability.Client& value)
            Reader(PythonInterfaceDynamicImpl& value)
            Reader(AnyPointer.Reader& value)
            Type getType()
            int64_t asInt"as<int64_t>"()
            uint64_t asUint"as<uint64_t>"()
            bint asBool"as<bool>"()
            double asDouble"as<double>"()
            StringPtr asText"as< ::capnp::Text>"()
            DynamicList.Reader asList"as< ::capnp::DynamicList>"()
            DynamicStruct.Reader asStruct"as< ::capnp::DynamicStruct>"()
            AnyPointer.Reader asObject"as< ::capnp::AnyPointer>"()
            DynamicCapability.Client asCapability"as< ::capnp::DynamicCapability>"()
            DynamicEnum asEnum"as< ::capnp::DynamicEnum>"()
            Data.Reader asData"as< ::capnp::Data>"()

        cppclass Builder:
            Type getType()
            int64_t asInt"as<int64_t>"()
            uint64_t asUint"as<uint64_t>"()
            bint asBool"as<bool>"()
            double asDouble"as<double>"()
            StringPtr asText"as< ::capnp::Text>"()
            DynamicList.Builder asList"as< ::capnp::DynamicList>"()
            DynamicStruct_Builder asStruct"as< ::capnp::DynamicStruct>"()
            AnyPointer.Builder asObject"as< ::capnp::AnyPointer>"()
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
        ParsedSchema getNested(char * name) except +reraise_kj_exception
    cdef cppclass SchemaParser:
        SchemaParser()
        ParsedSchema parseDiskFile(char * displayName, char * diskPath, ArrayPtr[StringPtr] importPath)

cdef extern from "capnp/orphan.h" namespace " ::capnp":
    cdef cppclass DynamicOrphan" ::capnp::Orphan< ::capnp::DynamicValue>":
        DynamicValue.Builder get()
        DynamicValue.Reader getReader()

cdef extern from "capnp/capability.h" namespace " ::capnp":
    cdef cppclass CallContext' ::capnp::CallContext< ::capnp::DynamicStruct, ::capnp::DynamicStruct>':
        CallContext(CallContext&)
        DynamicStruct.Reader getParams() except +reraise_kj_exception
        void releaseParams() except +reraise_kj_exception

        DynamicStruct_Builder getResults()
        DynamicStruct_Builder initResults()
        void setResults(DynamicStruct.Reader value)
        # void adoptResults(Orphan<Results>&& value);
        # Orphanage getResultsOrphanage(uint firstSegmentWordSize = 0);
        VoidPromise tailCall(Request & tailRequest)
        void allowCancellation() except +reraise_kj_exception

cdef extern from "kj/async.h" namespace " ::kj":
    cdef cppclass EventLoop:
        EventLoop()
        EventLoop(PyEventPort &)
    cdef cppclass PromiseFulfiller:
        void fulfill()
    cdef cppclass PromiseFulfillerPair" ::kj::PromiseFulfillerPair<void>":
        VoidPromise promise
        Own[PromiseFulfiller] fulfiller
    PromiseFulfillerPair newPromiseAndFulfiller" ::kj::newPromiseAndFulfiller<void>"()
    PyPromiseArray joinPromises(Array[PyPromise])

cdef extern from "capnp/helpers/asyncIoHelper.h":
    cdef cppclass AsyncIoStreamReadHelper:
        AsyncIoStreamReadHelper(AsyncIoStream *, WaitScope *, size_t)
        bool poll()
        size_t read_size()
        void* read_buffer()
