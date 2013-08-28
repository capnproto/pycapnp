# schema.capnp.cpp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnpc
from schema_cpp cimport Node, Data, StructNode, EnumNode

from libc.stdint cimport *
ctypedef unsigned int uint

cdef extern from "capnp/common.h" namespace " ::capnp":
    enum Void:
        VOID " ::capnp::VOID"

cdef extern from "kj/string.h" namespace " ::kj":
    cdef cppclass StringPtr:
        StringPtr(char *)

cdef extern from "kj/common.h" namespace " ::kj":
    cdef cppclass Maybe[T]:
        pass
    cdef cppclass ArrayPtr[T]:
        ArrayPtr()
        ArrayPtr(T *, size_t size)
        size_t size()
        T& operator[](size_t index)

cdef extern from "capnp/schema.h" namespace " ::capnp":
    cdef cppclass Schema:
        Node.Reader getProto() except +
        StructSchema asStruct() except +
        EnumSchema asEnum() except +
        ConstSchema asConst() except +
        Schema getDependency(uint64_t id) except +
        #InterfaceSchema asInterface() const;

    cdef cppclass StructSchema(Schema):
        cppclass Field:
            StructNode.Member.Reader getProto()
            StructSchema getContainingStruct()
            uint getIndex()

        cppclass FieldList:
            uint size()
            Field operator[](uint index)

        FieldList getFields()
        Field getFieldByName(char * name)

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
        TYPE_INTERFACE " ::capnp::DynamicValue::INTERFACE"
        TYPE_OBJECT " ::capnp::DynamicValue::OBJECT"

    cdef cppclass DynamicStruct:
        cppclass Reader:
            DynamicValueForward.Reader get(char *) except +ValueError
            bint has(char *) except +ValueError
            StructSchema getSchema()
            Maybe[StructSchema.Field] which()
        cppclass Builder:
            DynamicValueForward.Builder get(char *)
            bint has(char *) except +ValueError
            void set(char *, DynamicValueForward.Reader&) except +ValueError
            DynamicValueForward.Builder init(char *, uint size)
            DynamicValueForward.Builder init(char *)
            StructSchema getSchema()
            Maybe[StructSchema.Field] which()
            DynamicStruct.Reader asReader()

cdef extern from "fixMaybe.h":
    StructSchema.Field fixMaybe(Maybe[StructSchema.Field]) except+
    EnumSchema.Enumerant fixMaybe(Maybe[EnumSchema.Enumerant]) except+

cdef extern from "capnp/dynamic.h" namespace " ::capnp":
    cdef cppclass DynamicEnum:
        uint16_t getRaw()
        Maybe[EnumSchema.Enumerant] getEnumerant()

    cdef cppclass DynamicList:
        cppclass Reader:
            DynamicValueForward.Reader operator[](uint) except +ValueError
            uint size()
        cppclass Builder:
            DynamicValueForward.Builder operator[](uint)
            uint size()
            void set(uint index, DynamicValueForward.Reader& value) except +ValueError
            DynamicValueForward.Builder init(uint index, uint size) except +ValueError

    cdef cppclass DynamicValue:
        cppclass Reader:
            Reader()
            Reader(Void value)
            Reader(bint value)
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
            Type getType()
            int64_t asInt"as<int64_t>"()
            uint64_t asUint"as<uint64_t>"()
            bint asBool"as<bool>"()
            double asDouble"as<double>"()
            char * asText"as< ::capnp::Text>().cStr"()
            DynamicList.Reader asList"as< ::capnp::DynamicList>"()
            DynamicStruct.Reader asStruct"as< ::capnp::DynamicStruct>"()
            DynamicEnum asEnum"as< ::capnp::DynamicEnum>"()
            Data.Reader asData"as< ::capnp::Data>"()
        cppclass Builder:
            Type getType()
            int64_t asInt"as<int64_t>"()
            uint64_t asUint"as<uint64_t>"()
            bint asBool"as<bool>"()
            double asDouble"as<double>"()
            char * asText"as< ::capnp::Text>().cStr"()
            DynamicList.Builder asList"as< ::capnp::DynamicList>"()
            DynamicStruct.Builder asStruct"as< ::capnp::DynamicStruct>"()
            DynamicEnum asEnum"as< ::capnp::DynamicEnum>"()
            Data.Builder asData"as< ::capnp::Data>"()

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
