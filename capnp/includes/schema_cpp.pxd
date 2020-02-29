# schema.capnp.cpp.pyx
# distutils: language = c++

from libc.stdint cimport *
from capnp.helpers.non_circular cimport reraise_kj_exception

from capnp.includes.types cimport *

cdef extern from "capnp/dynamic.h" namespace " ::capnp":
    cdef cppclass DynamicValue:
        cppclass Reader:
            pass
        cppclass Builder:
            pass
    cdef cppclass DynamicStruct:
        cppclass Reader:
            pass

    cdef cppclass DynamicStruct_Builder" ::capnp::DynamicStruct::Builder":
        pass

cdef extern from "capnp/orphan.h" namespace " ::capnp":
    cdef cppclass DynamicOrphan" ::capnp::Orphan< ::capnp::DynamicValue>":
        DynamicValue.Builder get()
        DynamicValue.Reader getReader()

cdef extern from "capnp/schema.h" namespace " ::capnp":
    cdef cppclass Schema:
        pass
    cdef cppclass StructSchema(Schema):
        pass

cdef extern from "capnp/any.h" namespace " ::capnp":
    cdef cppclass AnyPointer:
        cppclass Reader:
            pass
        cppclass Builder:
            pass

cdef extern from "capnp/blob.h" namespace " ::capnp":
    cdef cppclass Data:
        cppclass Reader:
            char * begin()
            size_t size()
        cppclass Builder:
            char * begin()
            size_t size()
    cdef cppclass Text:
        cppclass Reader:
            char * cStr()
        cppclass Builder:
            char * cStr()
cdef extern from "capnp/message.h" namespace " ::capnp":
    cdef cppclass List[T]:
        cppclass Reader:
            T operator[](uint)
            uint size()
        cppclass Builder:
            T operator[](uint)
            uint size()

cdef extern from "capnp/schema.capnp.h" namespace " ::capnp::schema":
    enum :
        _ElementSize_inlineComposite " ::capnp::schema::ElementSize::INLINE_COMPOSITE"
        _ElementSize_eightBytes " ::capnp::schema::ElementSize::EIGHT_BYTES"
        _ElementSize_pointer " ::capnp::schema::ElementSize::POINTER"
        _ElementSize_bit " ::capnp::schema::ElementSize::BIT"
        _ElementSize_twoBytes " ::capnp::schema::ElementSize::TWO_BYTES"
        _ElementSize_fourBytes " ::capnp::schema::ElementSize::FOUR_BYTES"
        _ElementSize_byte " ::capnp::schema::ElementSize::BYTE"
        _ElementSize_empty " ::capnp::schema::ElementSize::EMPTY"
    enum _Value_Body_Which:
        _Value_Body_uint32Value " ::capnp::schema::Value::Body::Which::UINT32_VALUE"
        _Value_Body_float64Value " ::capnp::schema::Value::Body::Which::FLOAT64_VALUE"
        _Value_Body_voidValue " ::capnp::schema::Value::Body::Which::VOID_VALUE"
        _Value_Body_dataValue " ::capnp::schema::Value::Body::Which::DATA_VALUE"
        _Value_Body_listValue " ::capnp::schema::Value::Body::Which::LIST_VALUE"
        _Value_Body_int32Value " ::capnp::schema::Value::Body::Which::INT32_VALUE"
        _Value_Body_enumValue " ::capnp::schema::Value::Body::Which::ENUM_VALUE"
        _Value_Body_int8Value " ::capnp::schema::Value::Body::Which::INT8_VALUE"
        _Value_Body_boolValue " ::capnp::schema::Value::Body::Which::BOOL_VALUE"
        _Value_Body_int16Value " ::capnp::schema::Value::Body::Which::INT16_VALUE"
        _Value_Body_float32Value " ::capnp::schema::Value::Body::Which::FLOAT32_VALUE"
        _Value_Body_interfaceValue " ::capnp::schema::Value::Body::Which::INTERFACE_VALUE"
        _Value_Body_uint16Value " ::capnp::schema::Value::Body::Which::UINT16_VALUE"
        _Value_Body_uint8Value " ::capnp::schema::Value::Body::Which::UINT8_VALUE"
        _Value_Body_int64Value " ::capnp::schema::Value::Body::Which::INT64_VALUE"
        _Value_Body_structValue " ::capnp::schema::Value::Body::Which::STRUCT_VALUE"
        _Value_Body_textValue " ::capnp::schema::Value::Body::Which::TEXT_VALUE"
        _Value_Body_uint64Value " ::capnp::schema::Value::Body::Which::UINT64_VALUE"
        _Value_Body_objectValue " ::capnp::schema::Value::Body::Which::OBJECT_VALUE"
    enum _Type_Body_Which:
        _Type_Body_boolType " ::capnp::schema::Type::Body::Which::BOOL_TYPE"
        _Type_Body_structType " ::capnp::schema::Type::Body::Which::STRUCT_TYPE"
        _Type_Body_int32Type " ::capnp::schema::Type::Body::Which::INT32_TYPE"
        _Type_Body_voidType " ::capnp::schema::Type::Body::Which::VOID_TYPE"
        _Type_Body_uint16Type " ::capnp::schema::Type::Body::Which::UINT16_TYPE"
        _Type_Body_dataType " ::capnp::schema::Type::Body::Which::DATA_TYPE"
        _Type_Body_objectType " ::capnp::schema::Type::Body::Which::OBJECT_TYPE"
        _Type_Body_int64Type " ::capnp::schema::Type::Body::Which::INT64_TYPE"
        _Type_Body_float64Type " ::capnp::schema::Type::Body::Which::FLOAT64_TYPE"
        _Type_Body_interfaceType " ::capnp::schema::Type::Body::Which::INTERFACE_TYPE"
        _Type_Body_uint32Type " ::capnp::schema::Type::Body::Which::UINT32_TYPE"
        _Type_Body_uint8Type " ::capnp::schema::Type::Body::Which::UINT8_TYPE"
        _Type_Body_listType " ::capnp::schema::Type::Body::Which::LIST_TYPE"
        _Type_Body_int8Type " ::capnp::schema::Type::Body::Which::INT8_TYPE"
        _Type_Body_float32Type " ::capnp::schema::Type::Body::Which::FLOAT32_TYPE"
        _Type_Body_enumType " ::capnp::schema::Type::Body::Which::ENUM_TYPE"
        _Type_Body_uint64Type " ::capnp::schema::Type::Body::Which::UINT64_TYPE"
        _Type_Body_textType " ::capnp::schema::Type::Body::Which::TEXT_TYPE"
        _Type_Body_int16Type " ::capnp::schema::Type::Body::Which::INT16_TYPE"
    enum _Node_Body_Which:
        _Node_Body_annotationNode " ::capnp::schema::Node::Body::Which::ANNOTATION_NODE"
        _Node_Body_interfaceNode " ::capnp::schema::Node::Body::Which::INTERFACE_NODE"
        _Node_Body_enumNode " ::capnp::schema::Node::Body::Which::ENUM_NODE"
        _Node_Body_structNode " ::capnp::schema::Node::Body::Which::STRUCT_NODE"
        _Node_Body_constNode " ::capnp::schema::Node::Body::Which::CONST_NODE"
        _Node_Body_fileNode " ::capnp::schema::Node::Body::Which::FILE_NODE"
    enum _StructNode_Member_Body_Which:
        _StructNode_Member_Body_fieldMember " ::capnp::schema::StructNode::Member::Body::Which::FIELD_MEMBER"
        _StructNode_Member_Body_unionMember " ::capnp::schema::StructNode::Member::Body::Which::UNION_MEMBER"
    cdef cppclass CodeGeneratorRequest

    cdef cppclass InterfaceNode
    cdef cppclass Value
    cdef cppclass ConstNode
    cdef cppclass Type
    cdef cppclass FileNode
    cdef cppclass Node
    cdef cppclass AnnotationNode
    cdef cppclass EnumNode
    cdef cppclass StructNode
    cdef cppclass Annotation
    cdef cppclass CodeGeneratorRequest:


        cppclass Reader:

            List[CodeGeneratorRequest.Node].Reader getNodes()
            List[UInt64].Reader getRequestedFiles()
        cppclass Builder:

            List[CodeGeneratorRequest.Node].Builder getNodes()
            List[CodeGeneratorRequest.Node].Builder initNodes(int)
            List[UInt64].Builder getRequestedFiles()
            List[UInt64].Builder initRequestedFiles(int)
    cdef cppclass InterfaceNode:
        cppclass Method


        cppclass Method:
            cppclass Param


            cppclass Param:


                cppclass Reader:

                    Value getDefaultValue()
                    Type getType()
                    Text.Reader getName()
                    List[InterfaceNode.Method.Param.Annotation].Reader getAnnotations()
                cppclass Builder:

                    Value getDefaultValue()
                    void setDefaultValue(Value)
                    Type getType()
                    void setType(Type)
                    Text.Builder getName()
                    void setName(Text)
                    List[InterfaceNode.Method.Param.Annotation].Builder getAnnotations()
                    List[InterfaceNode.Method.Param.Annotation].Builder initAnnotations(int)
            cppclass Reader:

                UInt16 getCodeOrder()
                Text.Reader getName()
                List[InterfaceNode.Method.InterfaceNode.Method.Param].Reader getParams()
                UInt16 getRequiredParamCount()
                Type getReturnType()
                List[InterfaceNode.Method.Annotation].Reader getAnnotations()
            cppclass Builder:

                UInt16 getCodeOrder()
                void setCodeOrder(UInt16)
                Text.Builder getName()
                void setName(Text)
                List[InterfaceNode.Method.InterfaceNode.Method.Param].Builder getParams()
                List[InterfaceNode.Method.InterfaceNode.Method.Param].Builder initParams(int)
                UInt16 getRequiredParamCount()
                void setRequiredParamCount(UInt16)
                Type getReturnType()
                void setReturnType(Type)
                List[InterfaceNode.Method.Annotation].Builder getAnnotations()
                List[InterfaceNode.Method.Annotation].Builder initAnnotations(int)
        cppclass Reader:

            List[InterfaceNode.InterfaceNode.Method].Reader getMethods()
        cppclass Builder:

            List[InterfaceNode.InterfaceNode.Method].Builder getMethods()
            List[InterfaceNode.InterfaceNode.Method].Builder initMethods(int)
    cdef cppclass Value:
        cppclass Body


        cppclass Body:


            cppclass Reader:
                int which()
                UInt32 getUint32Value()
                Float64 getFloat64Value()
                Void getVoidValue()
                Data.Reader getDataValue()
                Object getListValue()
                Int32 getInt32Value()
                UInt16 getEnumValue()
                Int8 getInt8Value()
                Bool getBoolValue()
                Int16 getInt16Value()
                Float32 getFloat32Value()
                Void getInterfaceValue()
                UInt16 getUint16Value()
                UInt8 getUint8Value()
                Int64 getInt64Value()
                Object getStructValue()
                Text.Reader getTextValue()
                UInt64 getUint64Value()
                Object getObjectValue()
            cppclass Builder:
                int which()
                UInt32 getUint32Value()
                void setUint32Value(UInt32)
                Float64 getFloat64Value()
                void setFloat64Value(Float64)
                Void getVoidValue()
                void setVoidValue(Void)
                Data.Builder getDataValue()
                void setDataValue(Data)
                Object getListValue()
                void setListValue(Object)
                Int32 getInt32Value()
                void setInt32Value(Int32)
                UInt16 getEnumValue()
                void setEnumValue(UInt16)
                Int8 getInt8Value()
                void setInt8Value(Int8)
                Bool getBoolValue()
                void setBoolValue(Bool)
                Int16 getInt16Value()
                void setInt16Value(Int16)
                Float32 getFloat32Value()
                void setFloat32Value(Float32)
                Void getInterfaceValue()
                void setInterfaceValue(Void)
                UInt16 getUint16Value()
                void setUint16Value(UInt16)
                UInt8 getUint8Value()
                void setUint8Value(UInt8)
                Int64 getInt64Value()
                void setInt64Value(Int64)
                Object getStructValue()
                void setStructValue(Object)
                Text.Builder getTextValue()
                void setTextValue(Text)
                UInt64 getUint64Value()
                void setUint64Value(UInt64)
                Object getObjectValue()
                void setObjectValue(Object)
        cppclass Reader:

            Value.Body getBody()
        cppclass Builder:

            Value.Body getBody()
            void setBody(Value.Body)
    cdef cppclass ConstNode:


        cppclass Reader:

            Type getType()
            Value getValue()
        cppclass Builder:

            Type getType()
            void setType(Type)
            Value getValue()
            void setValue(Value)
    cdef cppclass Type:
        cppclass Body


        cppclass Body:


            cppclass Reader:
                int which()
                Void getBoolType()
                UInt64 getStructType()
                Void getInt32Type()
                Void getVoidType()
                Void getUint16Type()
                Void getDataType()
                Void getObjectType()
                Void getInt64Type()
                Void getFloat64Type()
                UInt64 getInterfaceType()
                Void getUint32Type()
                Void getUint8Type()
                Type getListType()
                Void getInt8Type()
                Void getFloat32Type()
                UInt64 getEnumType()
                Void getUint64Type()
                Void getTextType()
                Void getInt16Type()
            cppclass Builder:
                int which()
                Void getBoolType()
                void setBoolType(Void)
                UInt64 getStructType()
                void setStructType(UInt64)
                Void getInt32Type()
                void setInt32Type(Void)
                Void getVoidType()
                void setVoidType(Void)
                Void getUint16Type()
                void setUint16Type(Void)
                Void getDataType()
                void setDataType(Void)
                Void getObjectType()
                void setObjectType(Void)
                Void getInt64Type()
                void setInt64Type(Void)
                Void getFloat64Type()
                void setFloat64Type(Void)
                UInt64 getInterfaceType()
                void setInterfaceType(UInt64)
                Void getUint32Type()
                void setUint32Type(Void)
                Void getUint8Type()
                void setUint8Type(Void)
                Type getListType()
                void setListType(Type)
                Void getInt8Type()
                void setInt8Type(Void)
                Void getFloat32Type()
                void setFloat32Type(Void)
                UInt64 getEnumType()
                void setEnumType(UInt64)
                Void getUint64Type()
                void setUint64Type(Void)
                Void getTextType()
                void setTextType(Void)
                Void getInt16Type()
                void setInt16Type(Void)
        cppclass Reader:

            Type.Body getBody()
        cppclass Builder:

            Type.Body getBody()
            void setBody(Type.Body)
    cdef cppclass FileNode:
        cppclass Import


        cppclass Import:


            cppclass Reader:

                UInt64 getId()
                Text.Reader getName()
            cppclass Builder:

                UInt64 getId()
                void setId(UInt64)
                Text.Builder getName()
                void setName(Text)
        cppclass Reader:

            List[FileNode.FileNode.Import].Reader getImports()
        cppclass Builder:

            List[FileNode.FileNode.Import].Builder getImports()
            List[FileNode.FileNode.Import].Builder initImports(int)
    cdef cppclass Node:
        cppclass Body
        cppclass NestedNode


        cppclass Body:


            cppclass Reader:
                int which()
                AnnotationNode getAnnotationNode()
                InterfaceNode getInterfaceNode()
                EnumNode getEnumNode()
                StructNode getStructNode()
                ConstNode getConstNode()
                FileNode getFileNode()
            cppclass Builder:
                int which()
                AnnotationNode getAnnotationNode()
                void setAnnotationNode(AnnotationNode)
                InterfaceNode getInterfaceNode()
                void setInterfaceNode(InterfaceNode)
                EnumNode getEnumNode()
                void setEnumNode(EnumNode)
                StructNode getStructNode()
                void setStructNode(StructNode)
                ConstNode getConstNode()
                void setConstNode(ConstNode)
                FileNode getFileNode()
                void setFileNode(FileNode)
        cppclass NestedNode:


            cppclass Reader:

                Text.Reader getName()
                UInt64 getId()
            cppclass Builder:

                Text.Builder getName()
                void setName(Text)
                UInt64 getId()
                void setId(UInt64)
        cppclass Reader:

            Node.Body getBody()
            Text.Reader getDisplayName()
            List[Node.Annotation].Reader getAnnotations()
            UInt64 getScopeId()
            List[Node.Node.NestedNode].Reader getNestedNodes()
            UInt64 getId()
            bint isFile()
            bint isStruct()
            bint isEnum()
            bint isInterface()
            bint isConst()
            bint isAnnotation()
        cppclass Builder:

            Node.Body getBody()
            void setBody(Node.Body)
            Text.Builder getDisplayName()
            void setDisplayName(Text)
            List[Node.Annotation].Builder getAnnotations()
            List[Node.Annotation].Builder initAnnotations(int)
            UInt64 getScopeId()
            void setScopeId(UInt64)
            List[Node.Node.NestedNode].Builder getNestedNodes()
            List[Node.Node.NestedNode].Builder initNestedNodes(int)
            UInt64 getId()
            void setId(UInt64)
            bint isFile()
            bint isStruct()
            bint isEnum()
            bint isInterface()
            bint isConst()
            bint isAnnotation()
    cdef cppclass AnnotationNode:


        cppclass Reader:

            Bool getTargetsField()
            Bool getTargetsConst()
            Bool getTargetsFile()
            Bool getTargetsStruct()
            Bool getTargetsParam()
            Bool getTargetsUnion()
            Bool getTargetsAnnotation()
            Bool getTargetsEnumerant()
            Type getType()
            Bool getTargetsEnum()
            Bool getTargetsInterface()
            Bool getTargetsMethod()
        cppclass Builder:

            Bool getTargetsField()
            void setTargetsField(Bool)
            Bool getTargetsConst()
            void setTargetsConst(Bool)
            Bool getTargetsFile()
            void setTargetsFile(Bool)
            Bool getTargetsStruct()
            void setTargetsStruct(Bool)
            Bool getTargetsParam()
            void setTargetsParam(Bool)
            Bool getTargetsUnion()
            void setTargetsUnion(Bool)
            Bool getTargetsAnnotation()
            void setTargetsAnnotation(Bool)
            Bool getTargetsEnumerant()
            void setTargetsEnumerant(Bool)
            Type getType()
            void setType(Type)
            Bool getTargetsEnum()
            void setTargetsEnum(Bool)
            Bool getTargetsInterface()
            void setTargetsInterface(Bool)
            Bool getTargetsMethod()
            void setTargetsMethod(Bool)
    cdef cppclass EnumNode:
        cppclass Enumerant


        cppclass Enumerant:


            cppclass Reader:

                UInt16 getCodeOrder()
                Text.Reader getName()
                List[EnumNode.Enumerant.Annotation].Reader getAnnotations()
            cppclass Builder:

                UInt16 getCodeOrder()
                void setCodeOrder(UInt16)
                Text.Builder getName()
                void setName(Text)
                List[EnumNode.Enumerant.Annotation].Builder getAnnotations()
                List[EnumNode.Enumerant.Annotation].Builder initAnnotations(int)
        cppclass Reader:

            List[EnumNode.EnumNode.Enumerant].Reader getEnumerants()
        cppclass Builder:

            List[EnumNode.EnumNode.Enumerant].Builder getEnumerants()
            List[EnumNode.EnumNode.Enumerant].Builder initEnumerants(int)
    cdef cppclass StructNode:
        cppclass Union
        cppclass Member
        cppclass Field


        cppclass Union:


            cppclass Reader:

                UInt32 getDiscriminantOffset()
                List[StructNode.Union.StructNode.Member].Reader getMembers()
            cppclass Builder:

                UInt32 getDiscriminantOffset()
                void setDiscriminantOffset(UInt32)
                List[StructNode.Union.StructNode.Member].Builder getMembers()
                List[StructNode.Union.StructNode.Member].Builder initMembers(int)
        cppclass Member:
            cppclass Body


            cppclass Body:


                cppclass Reader:
                    int which()
                    Field getFieldMember()
                    Union getUnionMember()
                cppclass Builder:
                    int which()
                    Field getFieldMember()
                    void setFieldMember(Field)
                    Union getUnionMember()
                    void setUnionMember(Union)
            cppclass Reader:

                UInt16 getOrdinal()
                StructNode.Member.Body getBody()
                UInt16 getCodeOrder()
                Text.Reader getName()
                List[StructNode.Member.Annotation].Reader getAnnotations()
            cppclass Builder:

                UInt16 getOrdinal()
                void setOrdinal(UInt16)
                StructNode.Member.Body getBody()
                void setBody(StructNode.Member.Body)
                UInt16 getCodeOrder()
                void setCodeOrder(UInt16)
                Text.Builder getName()
                void setName(Text)
                List[StructNode.Member.Annotation].Builder getAnnotations()
                List[StructNode.Member.Annotation].Builder initAnnotations(int)
        cppclass Field:


            cppclass Reader:

                Value getDefaultValue()
                Type getType()
                UInt32 getOffset()
            cppclass Builder:

                Value getDefaultValue()
                void setDefaultValue(Value)
                Type getType()
                void setType(Type)
                UInt32 getOffset()
                void setOffset(UInt32)
        cppclass Reader:

            UInt16 getDataSectionWordSize()
            List[StructNode.StructNode.Member].Reader getMembers()
            UInt16 getPointerSectionSize()
        cppclass Builder:

            UInt16 getDataSectionWordSize()
            void setDataSectionWordSize(UInt16)
            List[StructNode.StructNode.Member].Builder getMembers()
            List[StructNode.StructNode.Member].Builder initMembers(int)
            UInt16 getPointerSectionSize()
            void setPointerSectionSize(UInt16)
    cdef cppclass Annotation:


        cppclass Reader:

            UInt64 getId()
            Value getValue()
        cppclass Builder:

            UInt64 getId()
            void setId(UInt64)
            Value getValue()
            void setValue(Value)
    cdef cppclass ListNestedNodeReader"capnp::List<capnp::schema::Node::NestedNode>::Reader":
       ListNestedNodeReader()
       ListNestedNodeReader(ListNestedNodeReader)
       Node.NestedNode.Reader operator[](uint)
       uint size()

cdef extern from "capnp/message.h" namespace " ::capnp":
    cdef cppclass ReaderOptions:
        uint64_t traversalLimitInWords
        uint nestingLimit

    cdef cppclass MessageBuilder:
        CodeGeneratorRequest.Builder getRootCodeGeneratorRequest'getRoot< ::capnp::schema::CodeGeneratorRequest>'()
        CodeGeneratorRequest.Builder initRootCodeGeneratorRequest'initRoot< ::capnp::schema::CodeGeneratorRequest>'()
        InterfaceNode.Builder getRootInterfaceNode'getRoot< ::capnp::schema::InterfaceNode>'()
        InterfaceNode.Builder initRootInterfaceNode'initRoot< ::capnp::schema::InterfaceNode>'()
        Value.Builder getRootValue'getRoot< ::capnp::schema::Value>'()
        Value.Builder initRootValue'initRoot< ::capnp::schema::Value>'()
        ConstNode.Builder getRootConstNode'getRoot< ::capnp::schema::ConstNode>'()
        ConstNode.Builder initRootConstNode'initRoot< ::capnp::schema::ConstNode>'()
        Type.Builder getRootType'getRoot< ::capnp::schema::Type>'()
        Type.Builder initRootType'initRoot< ::capnp::schema::Type>'()
        FileNode.Builder getRootFileNode'getRoot< ::capnp::schema::FileNode>'()
        FileNode.Builder initRootFileNode'initRoot< ::capnp::schema::FileNode>'()
        Node.Builder getRootNode'getRoot< ::capnp::schema::Node>'()
        Node.Builder initRootNode'initRoot< ::capnp::schema::Node>'()
        AnnotationNode.Builder getRootAnnotationNode'getRoot< ::capnp::schema::AnnotationNode>'()
        AnnotationNode.Builder initRootAnnotationNode'initRoot< ::capnp::schema::AnnotationNode>'()
        EnumNode.Builder getRootEnumNode'getRoot< ::capnp::schema::EnumNode>'()
        EnumNode.Builder initRootEnumNode'initRoot< ::capnp::schema::EnumNode>'()
        StructNode.Builder getRootStructNode'getRoot< ::capnp::schema::StructNode>'()
        StructNode.Builder initRootStructNode'initRoot< ::capnp::schema::StructNode>'()
        Annotation.Builder getRootAnnotation'getRoot< ::capnp::schema::Annotation>'()
        Annotation.Builder initRootAnnotation'initRoot< ::capnp::schema::Annotation>'()

        DynamicStruct_Builder getRootDynamicStruct'getRoot< ::capnp::DynamicStruct>'(StructSchema)
        DynamicStruct_Builder initRootDynamicStruct'initRoot< ::capnp::DynamicStruct>'(StructSchema)
        void setRootDynamicStruct'setRoot< ::capnp::DynamicStruct::Reader>'(DynamicStruct.Reader)

        ConstWordArrayArrayPtr getSegmentsForOutput'getSegmentsForOutput'()

        AnyPointer.Builder getRootAnyPointer'getRoot< ::capnp::AnyPointer>'()

        DynamicOrphan newOrphan'getOrphanage().newOrphan'(StructSchema)

    cdef cppclass MessageReader:
        CodeGeneratorRequest.Reader getRootCodeGeneratorRequest'getRoot< ::capnp::schema::CodeGeneratorRequest>'()
        InterfaceNode.Reader getRootInterfaceNode'getRoot< ::capnp::schema::InterfaceNode>'()
        Value.Reader getRootValue'getRoot< ::capnp::schema::Value>'()
        ConstNode.Reader getRootConstNode'getRoot< ::capnp::schema::ConstNode>'()
        Type.Reader getRootType'getRoot< ::capnp::schema::Type>'()
        FileNode.Reader getRootFileNode'getRoot< ::capnp::schema::FileNode>'()
        Node.Reader getRootNode'getRoot< ::capnp::schema::Node>'()
        AnnotationNode.Reader getRootAnnotationNode'getRoot< ::capnp::schema::AnnotationNode>'()
        EnumNode.Reader getRootEnumNode'getRoot< ::capnp::schema::EnumNode>'()
        StructNode.Reader getRootStructNode'getRoot< ::capnp::schema::StructNode>'()
        Annotation.Reader getRootAnnotation'getRoot< ::capnp::schema::Annotation>'()

        DynamicStruct.Reader getRootDynamicStruct'getRoot< ::capnp::DynamicStruct>'(StructSchema)
        AnyPointer.Reader getRootAnyPointer'getRoot< ::capnp::AnyPointer>'()

    cdef cppclass MallocMessageBuilder(MessageBuilder):
        MallocMessageBuilder()
        MallocMessageBuilder(int)

    cdef cppclass SegmentArrayMessageReader(MessageReader):
        SegmentArrayMessageReader(ConstWordArrayArrayPtr array) except +reraise_kj_exception
        SegmentArrayMessageReader(ConstWordArrayArrayPtr array, ReaderOptions) except +reraise_kj_exception

    cdef cppclass FlatMessageBuilder(MessageBuilder):
        FlatMessageBuilder(WordArrayPtr array)
        FlatMessageBuilder(WordArrayPtr array, ReaderOptions)

    enum Void:
        VOID

cdef extern from "capnp/common.h" namespace " ::capnp":
    cdef cppclass word:
        pass

cdef extern from "kj/common.h" namespace " ::kj":
    # Cython can't handle ArrayPtr[word] as a function argument
    cdef cppclass WordArrayPtr " ::kj::ArrayPtr< ::capnp::word>":
        WordArrayPtr()
        WordArrayPtr(word *, size_t size)
        size_t size()
        word& operator[](size_t index)
    cdef cppclass ByteArrayPtr " ::kj::ArrayPtr< ::capnp::byte>":
        ByteArrayPtr()
        ByteArrayPtr(byte *, size_t size)
        size_t size()
        byte& operator[](size_t index)
    cdef cppclass ConstWordArrayPtr " ::kj::ArrayPtr< const ::capnp::word>":
        ConstWordArrayPtr()
        ConstWordArrayPtr(word *, size_t size)
        size_t size()
        const word* begin()
    cdef cppclass ConstWordArrayArrayPtr " ::kj::ArrayPtr< const ::kj::ArrayPtr< const ::capnp::word>>":
        ConstWordArrayArrayPtr()
        ConstWordArrayArrayPtr(ConstWordArrayPtr*, size_t size)
        size_t size()
        ConstWordArrayPtr& operator[](size_t index)

cdef extern from "kj/array.h" namespace " ::kj":
    # Cython can't handle Array[word] as a function argument
    cdef cppclass WordArray " ::kj::Array< ::capnp::word>":
        word* begin()
        size_t size()
    cdef cppclass ByteArray " ::kj::Array< ::capnp::byte>":
        char* begin()
        size_t size()

cdef extern from "kj/array.h" namespace " ::kj":
    cdef cppclass InputStream:
        void read(void* buffer, size_t bytes) except +reraise_kj_exception
        size_t read(void* buffer, size_t minBytes, size_t maxBytes) except +reraise_kj_exception
        size_t tryRead(void* buffer, size_t minBytes, size_t maxBytes) except +reraise_kj_exception
        void skip(size_t bytes) except +reraise_kj_exception

    cdef cppclass OutputStream:
        void write(const void* buffer, size_t size) except +reraise_kj_exception
        # void write(ArrayPtr<const ArrayPtr<const byte>> pieces);

    cdef cppclass BufferedInputStream(InputStream):
        pass
    cdef cppclass BufferedOutputStream(OutputStream):
        pass

    cdef cppclass BufferedInputStreamWrapper(BufferedInputStream):
        BufferedInputStreamWrapper(InputStream&)
    cdef cppclass BufferedOutputStreamWrapper(BufferedOutputStream):
        BufferedOutputStreamWrapper(OutputStream&)

    cdef cppclass ArrayInputStream(BufferedInputStream):
        ArrayInputStream(ByteArrayPtr)
        ByteArrayPtr getArray()
        # ByteArrayPtr tryGetReadBuffer() except +reraise_kj_exception
    cdef cppclass ArrayOutputStream(BufferedOutputStream):
        ArrayOutputStream(ByteArrayPtr)
        ByteArrayPtr getArray()
        ByteArrayPtr getWriteBuffer()

    cdef cppclass FdInputStream(InputStream):
        FdInputStream(int)
    cdef cppclass FdOutputStream(OutputStream):
        FdOutputStream(int)

cdef extern from "capnp/serialize.h" namespace " ::capnp":
    cdef cppclass InputStreamMessageReader(MessageReader):
        InputStreamMessageReader(InputStream&) except +reraise_kj_exception
        InputStreamMessageReader(InputStream&, ReaderOptions) except +reraise_kj_exception
    cdef cppclass StreamFdMessageReader(MessageReader):
        StreamFdMessageReader(int) except +reraise_kj_exception
        StreamFdMessageReader(int, ReaderOptions) except +reraise_kj_exception

    cdef cppclass FlatArrayMessageReader(MessageReader):
        FlatArrayMessageReader(WordArrayPtr array) except +reraise_kj_exception
        FlatArrayMessageReader(WordArrayPtr array, ReaderOptions) except +reraise_kj_exception
        const word* getEnd() const

    void writeMessageToFd(int, MessageBuilder&) except +reraise_kj_exception

    WordArray messageToFlatArray(MessageBuilder &)

cdef extern from "capnp/serialize-packed.h" namespace " ::capnp":
    cdef cppclass PackedInputStream(InputStream):
        PackedInputStream(BufferedInputStream&) except +reraise_kj_exception
    cdef cppclass PackedOutputStream(OutputStream):
        PackedOutputStream(BufferedOutputStream&) except +reraise_kj_exception

    cdef cppclass PackedMessageReader(MessageReader):
        PackedMessageReader(BufferedInputStream&) except +reraise_kj_exception
        PackedMessageReader(BufferedInputStream&, ReaderOptions) except +reraise_kj_exception

    cdef cppclass PackedFdMessageReader(MessageReader):
        PackedFdMessageReader(int) except +reraise_kj_exception
        PackedFdMessageReader(int, ReaderOptions) except +reraise_kj_exception

    void writePackedMessage(BufferedOutputStream&, MessageBuilder&) except +reraise_kj_exception
    void writePackedMessage(OutputStream&, MessageBuilder&) except +reraise_kj_exception
    void writePackedMessageToFd(int, MessageBuilder&) except +reraise_kj_exception
