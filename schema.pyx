# schema.capnp.cpp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnp

cimport schema_cpp as capnp
from schema_cpp cimport CodeGeneratorRequest as C_CodeGeneratorRequest,InterfaceNode as C_InterfaceNode,Value as C_Value,ConstNode as C_ConstNode,Type as C_Type,FileNode as C_FileNode,Node as C_Node,AnnotationNode as C_AnnotationNode,EnumNode as C_EnumNode,StructNode as C_StructNode,Annotation as C_Annotation
from schema_cpp cimport _ElementSize_inlineComposite,_ElementSize_eightBytes,_ElementSize_pointer,_ElementSize_bit,_ElementSize_twoBytes,_ElementSize_fourBytes,_ElementSize_byte,_ElementSize_empty
from schema_cpp cimport _Value_Body_uint32Value,_Value_Body_float64Value,_Value_Body_voidValue,_Value_Body_dataValue,_Value_Body_listValue,_Value_Body_int32Value,_Value_Body_enumValue,_Value_Body_int8Value,_Value_Body_boolValue,_Value_Body_int16Value,_Value_Body_float32Value,_Value_Body_interfaceValue,_Value_Body_uint16Value,_Value_Body_uint8Value,_Value_Body_int64Value,_Value_Body_structValue,_Value_Body_textValue,_Value_Body_uint64Value,_Value_Body_objectValue,_Type_Body_boolType,_Type_Body_structType,_Type_Body_int32Type,_Type_Body_voidType,_Type_Body_uint16Type,_Type_Body_dataType,_Type_Body_objectType,_Type_Body_int64Type,_Type_Body_float64Type,_Type_Body_interfaceType,_Type_Body_uint32Type,_Type_Body_uint8Type,_Type_Body_listType,_Type_Body_int8Type,_Type_Body_float32Type,_Type_Body_enumType,_Type_Body_uint64Type,_Type_Body_textType,_Type_Body_int16Type,_Node_Body_annotationNode,_Node_Body_interfaceNode,_Node_Body_enumNode,_Node_Body_structNode,_Node_Body_constNode,_Node_Body_fileNode,_StructNode_Member_Body_fieldMember,_StructNode_Member_Body_unionMember

# from capnp_schema cimport *
# Not doing this since we want to namespace away the class names

from cython.operator cimport dereference as deref

from libc.stdint cimport *
ctypedef unsigned int uint
ctypedef uint8_t UInt8
ctypedef uint16_t UInt16
ctypedef uint32_t UInt32
ctypedef uint64_t UInt64
ctypedef int8_t Int8
ctypedef int16_t Int16
ctypedef int32_t Int32
ctypedef int64_t Int64

ctypedef char * Data
ctypedef char * Object
ctypedef char * Text
ctypedef bint Bool
ctypedef float Float32
ctypedef double Float64
cdef extern from "capnp/message.h" namespace "::capnp":
    cdef cppclass List[T]:
        cppclass Reader:
            T operator[](uint)
            uint size()
        cppclass Builder:
            T operator[](uint)
            uint size()
def make_enum(enum_name, *sequential, **named):
    enums = dict(zip(sequential, range(len(sequential))), **named)
    reverse = dict((value, key) for key, value in enums.iteritems())
    enums['reverse_mapping'] = reverse
    return type(enum_name, (), enums)
cdef class _List_InterfaceNode_InterfaceNode_Method_Reader:
    cdef List[C_InterfaceNode.InterfaceNode.Method].Reader thisptr
    cdef init(self, List[C_InterfaceNode.InterfaceNode.Method].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _InterfaceNode_MethodReader().init(<C_InterfaceNode.InterfaceNode.Method.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_InterfaceNode_InterfaceNode_Method_Builder:
    cdef List[C_InterfaceNode.InterfaceNode.Method].Builder thisptr
    cdef init(self, List[C_InterfaceNode.InterfaceNode.Method].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _InterfaceNode_MethodBuilder().init(<C_InterfaceNode.InterfaceNode.Method.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_EnumNode_EnumNode_Enumerant_Reader:
    cdef List[C_EnumNode.EnumNode.Enumerant].Reader thisptr
    cdef init(self, List[C_EnumNode.EnumNode.Enumerant].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _EnumNode_EnumerantReader().init(<C_EnumNode.EnumNode.Enumerant.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_EnumNode_EnumNode_Enumerant_Builder:
    cdef List[C_EnumNode.EnumNode.Enumerant].Builder thisptr
    cdef init(self, List[C_EnumNode.EnumNode.Enumerant].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _EnumNode_EnumerantBuilder().init(<C_EnumNode.EnumNode.Enumerant.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_StructNode_Union_StructNode_Member_Reader:
    cdef List[C_StructNode.Union.StructNode.Member].Reader thisptr
    cdef init(self, List[C_StructNode.Union.StructNode.Member].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _StructNode_MemberReader().init(<C_StructNode.Union.StructNode.Member.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_StructNode_Union_StructNode_Member_Builder:
    cdef List[C_StructNode.Union.StructNode.Member].Builder thisptr
    cdef init(self, List[C_StructNode.Union.StructNode.Member].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _StructNode_MemberBuilder().init(<C_StructNode.Union.StructNode.Member.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_InterfaceNode_Method_InterfaceNode_Method_Param_Reader:
    cdef List[C_InterfaceNode.Method.InterfaceNode.Method.Param].Reader thisptr
    cdef init(self, List[C_InterfaceNode.Method.InterfaceNode.Method.Param].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _InterfaceNode_Method_ParamReader().init(<C_InterfaceNode.Method.InterfaceNode.Method.Param.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_InterfaceNode_Method_InterfaceNode_Method_Param_Builder:
    cdef List[C_InterfaceNode.Method.InterfaceNode.Method.Param].Builder thisptr
    cdef init(self, List[C_InterfaceNode.Method.InterfaceNode.Method.Param].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _InterfaceNode_Method_ParamBuilder().init(<C_InterfaceNode.Method.InterfaceNode.Method.Param.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_InterfaceNode_Method_Param_Annotation_Reader:
    cdef List[C_InterfaceNode.Method.Param.Annotation].Reader thisptr
    cdef init(self, List[C_InterfaceNode.Method.Param.Annotation].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationReader().init(<C_InterfaceNode.Method.Param.Annotation.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_InterfaceNode_Method_Param_Annotation_Builder:
    cdef List[C_InterfaceNode.Method.Param.Annotation].Builder thisptr
    cdef init(self, List[C_InterfaceNode.Method.Param.Annotation].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationBuilder().init(<C_InterfaceNode.Method.Param.Annotation.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_UInt64_Reader:
    cdef List[UInt64].Reader thisptr
    cdef init(self, List[UInt64].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return self.thisptr[index]

    def __len__(self):
        return self.thisptr.size()
cdef class _List_UInt64_Builder:
    cdef List[UInt64].Builder thisptr
    cdef init(self, List[UInt64].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return self.thisptr[index]
    def __len__(self):
        return self.thisptr.size()
cdef class _List_Node_Node_NestedNode_Reader:
    cdef List[C_Node.Node.NestedNode].Reader thisptr
    cdef init(self, List[C_Node.Node.NestedNode].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _Node_NestedNodeReader().init(<C_Node.Node.NestedNode.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_Node_Node_NestedNode_Builder:
    cdef List[C_Node.Node.NestedNode].Builder thisptr
    cdef init(self, List[C_Node.Node.NestedNode].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _Node_NestedNodeBuilder().init(<C_Node.Node.NestedNode.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_StructNode_Member_Annotation_Reader:
    cdef List[C_StructNode.Member.Annotation].Reader thisptr
    cdef init(self, List[C_StructNode.Member.Annotation].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationReader().init(<C_StructNode.Member.Annotation.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_StructNode_Member_Annotation_Builder:
    cdef List[C_StructNode.Member.Annotation].Builder thisptr
    cdef init(self, List[C_StructNode.Member.Annotation].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationBuilder().init(<C_StructNode.Member.Annotation.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_InterfaceNode_Method_Annotation_Reader:
    cdef List[C_InterfaceNode.Method.Annotation].Reader thisptr
    cdef init(self, List[C_InterfaceNode.Method.Annotation].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationReader().init(<C_InterfaceNode.Method.Annotation.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_InterfaceNode_Method_Annotation_Builder:
    cdef List[C_InterfaceNode.Method.Annotation].Builder thisptr
    cdef init(self, List[C_InterfaceNode.Method.Annotation].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationBuilder().init(<C_InterfaceNode.Method.Annotation.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_StructNode_StructNode_Member_Reader:
    cdef List[C_StructNode.StructNode.Member].Reader thisptr
    cdef init(self, List[C_StructNode.StructNode.Member].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _StructNode_MemberReader().init(<C_StructNode.StructNode.Member.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_StructNode_StructNode_Member_Builder:
    cdef List[C_StructNode.StructNode.Member].Builder thisptr
    cdef init(self, List[C_StructNode.StructNode.Member].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _StructNode_MemberBuilder().init(<C_StructNode.StructNode.Member.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_Node_Annotation_Reader:
    cdef List[C_Node.Annotation].Reader thisptr
    cdef init(self, List[C_Node.Annotation].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationReader().init(<C_Node.Annotation.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_Node_Annotation_Builder:
    cdef List[C_Node.Annotation].Builder thisptr
    cdef init(self, List[C_Node.Annotation].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationBuilder().init(<C_Node.Annotation.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_CodeGeneratorRequest_Node_Reader:
    cdef List[C_CodeGeneratorRequest.Node].Reader thisptr
    cdef init(self, List[C_CodeGeneratorRequest.Node].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _NodeReader().init(<C_CodeGeneratorRequest.Node.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_CodeGeneratorRequest_Node_Builder:
    cdef List[C_CodeGeneratorRequest.Node].Builder thisptr
    cdef init(self, List[C_CodeGeneratorRequest.Node].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _NodeBuilder().init(<C_CodeGeneratorRequest.Node.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_FileNode_FileNode_Import_Reader:
    cdef List[C_FileNode.FileNode.Import].Reader thisptr
    cdef init(self, List[C_FileNode.FileNode.Import].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _FileNode_ImportReader().init(<C_FileNode.FileNode.Import.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_FileNode_FileNode_Import_Builder:
    cdef List[C_FileNode.FileNode.Import].Builder thisptr
    cdef init(self, List[C_FileNode.FileNode.Import].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _FileNode_ImportBuilder().init(<C_FileNode.FileNode.Import.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()
cdef class _List_EnumNode_Enumerant_Annotation_Reader:
    cdef List[C_EnumNode.Enumerant.Annotation].Reader thisptr
    cdef init(self, List[C_EnumNode.Enumerant.Annotation].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationReader().init(<C_EnumNode.Enumerant.Annotation.Reader>self.thisptr[index])

    def __len__(self):
        return self.thisptr.size()
cdef class _List_EnumNode_Enumerant_Annotation_Builder:
    cdef List[C_EnumNode.Enumerant.Annotation].Builder thisptr
    cdef init(self, List[C_EnumNode.Enumerant.Annotation].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        return _AnnotationBuilder().init(<C_EnumNode.Enumerant.Annotation.Builder>self.thisptr[index])
    def __len__(self):
        return self.thisptr.size()

cdef class _CodeGeneratorRequestReader:
    cdef C_CodeGeneratorRequest.Reader thisptr
    cdef init(self, C_CodeGeneratorRequest.Reader other):
        self.thisptr = other
        return self
        
    property nodes:
        def __get__(self):
            return _List_CodeGeneratorRequest_Node_Reader().init(self.thisptr.getNodes())
    property requestedFiles:
        def __get__(self):
            return _List_UInt64_Reader().init(self.thisptr.getRequestedFiles())

cdef class _CodeGeneratorRequestBuilder:
    cdef C_CodeGeneratorRequest.Builder thisptr
    cdef init(self, C_CodeGeneratorRequest.Builder other):
        self.thisptr = other
        return self
        
    property nodes:
        def __get__(self):
            return _List_CodeGeneratorRequest_Node_Builder().init(self.thisptr.getNodes())
    cpdef initNodes(self, uint num):
        return _List_CodeGeneratorRequest_Node_Builder().init(self.thisptr.initNodes(num))
    property requestedFiles:
        def __get__(self):
            return _List_UInt64_Builder().init(self.thisptr.getRequestedFiles())
    cpdef initRequestedFiles(self, uint num):
        return _List_UInt64_Builder().init(self.thisptr.initRequestedFiles(num))

_ElementSize = make_enum('_ElementSize',inlineComposite = <int>_ElementSize_inlineComposite,eightBytes = <int>_ElementSize_eightBytes,pointer = <int>_ElementSize_pointer,bit = <int>_ElementSize_bit,twoBytes = <int>_ElementSize_twoBytes,fourBytes = <int>_ElementSize_fourBytes,byte = <int>_ElementSize_byte,empty = <int>_ElementSize_empty,)



cdef class _InterfaceNode_Method_ParamReader:
    cdef C_InterfaceNode.Method.Param.Reader thisptr
    cdef init(self, C_InterfaceNode.Method.Param.Reader other):
        self.thisptr = other
        return self
        
    property defaultValue:
        def __get__(self):
            return _ValueReader().init(<C_Value.Reader>self.thisptr.getDefaultValue())
    property type:
        def __get__(self):
            return _TypeReader().init(<C_Type.Reader>self.thisptr.getType())
    property name:
        def __get__(self):
            return None
    property annotations:
        def __get__(self):
            return _List_InterfaceNode_Method_Param_Annotation_Reader().init(self.thisptr.getAnnotations())

cdef class _InterfaceNode_Method_ParamBuilder:
    cdef C_InterfaceNode.Method.Param.Builder thisptr
    cdef init(self, C_InterfaceNode.Method.Param.Builder other):
        self.thisptr = other
        return self
        
    property defaultValue:
        def __get__(self):
            return _ValueBuilder().init(<C_Value.Builder>self.thisptr.getDefaultValue())
        def __set__(self, val):
            pass
    property type:
        def __get__(self):
            return _TypeBuilder().init(<C_Type.Builder>self.thisptr.getType())
        def __set__(self, val):
            pass
    property name:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property annotations:
        def __get__(self):
            return _List_InterfaceNode_Method_Param_Annotation_Builder().init(self.thisptr.getAnnotations())
    cpdef initAnnotations(self, uint num):
        return _List_InterfaceNode_Method_Param_Annotation_Builder().init(self.thisptr.initAnnotations(num))
cdef class _InterfaceNode_MethodReader:
    cdef C_InterfaceNode.Method.Reader thisptr
    cdef init(self, C_InterfaceNode.Method.Reader other):
        self.thisptr = other
        return self
        
    property codeOrder:
        def __get__(self):
            return self.thisptr.getCodeOrder()
    property name:
        def __get__(self):
            return None
    property params:
        def __get__(self):
            return _List_InterfaceNode_Method_InterfaceNode_Method_Param_Reader().init(self.thisptr.getParams())
    property requiredParamCount:
        def __get__(self):
            return self.thisptr.getRequiredParamCount()
    property returnType:
        def __get__(self):
            return _TypeReader().init(<C_Type.Reader>self.thisptr.getReturnType())
    property annotations:
        def __get__(self):
            return _List_InterfaceNode_Method_Annotation_Reader().init(self.thisptr.getAnnotations())

cdef class _InterfaceNode_MethodBuilder:
    cdef C_InterfaceNode.Method.Builder thisptr
    cdef init(self, C_InterfaceNode.Method.Builder other):
        self.thisptr = other
        return self
        
    property codeOrder:
        def __get__(self):
            return self.thisptr.getCodeOrder()
        def __set__(self, val):
            self.thisptr.setCodeOrder(val)
    property name:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property params:
        def __get__(self):
            return _List_InterfaceNode_Method_InterfaceNode_Method_Param_Builder().init(self.thisptr.getParams())
    cpdef initParams(self, uint num):
        return _List_InterfaceNode_Method_InterfaceNode_Method_Param_Builder().init(self.thisptr.initParams(num))
    property requiredParamCount:
        def __get__(self):
            return self.thisptr.getRequiredParamCount()
        def __set__(self, val):
            self.thisptr.setRequiredParamCount(val)
    property returnType:
        def __get__(self):
            return _TypeBuilder().init(<C_Type.Builder>self.thisptr.getReturnType())
        def __set__(self, val):
            pass
    property annotations:
        def __get__(self):
            return _List_InterfaceNode_Method_Annotation_Builder().init(self.thisptr.getAnnotations())
    cpdef initAnnotations(self, uint num):
        return _List_InterfaceNode_Method_Annotation_Builder().init(self.thisptr.initAnnotations(num))
cdef class _InterfaceNodeReader:
    cdef C_InterfaceNode.Reader thisptr
    cdef init(self, C_InterfaceNode.Reader other):
        self.thisptr = other
        return self
        
    property methods:
        def __get__(self):
            return _List_InterfaceNode_InterfaceNode_Method_Reader().init(self.thisptr.getMethods())

cdef class _InterfaceNodeBuilder:
    cdef C_InterfaceNode.Builder thisptr
    cdef init(self, C_InterfaceNode.Builder other):
        self.thisptr = other
        return self
        
    property methods:
        def __get__(self):
            return _List_InterfaceNode_InterfaceNode_Method_Builder().init(self.thisptr.getMethods())
    cpdef initMethods(self, uint num):
        return _List_InterfaceNode_InterfaceNode_Method_Builder().init(self.thisptr.initMethods(num))


_Value_Body_Which = make_enum('_Value_Body_Which',uint32Value = <int>_Value_Body_uint32Value,float64Value = <int>_Value_Body_float64Value,voidValue = <int>_Value_Body_voidValue,dataValue = <int>_Value_Body_dataValue,listValue = <int>_Value_Body_listValue,int32Value = <int>_Value_Body_int32Value,enumValue = <int>_Value_Body_enumValue,int8Value = <int>_Value_Body_int8Value,boolValue = <int>_Value_Body_boolValue,int16Value = <int>_Value_Body_int16Value,float32Value = <int>_Value_Body_float32Value,interfaceValue = <int>_Value_Body_interfaceValue,uint16Value = <int>_Value_Body_uint16Value,uint8Value = <int>_Value_Body_uint8Value,int64Value = <int>_Value_Body_int64Value,structValue = <int>_Value_Body_structValue,textValue = <int>_Value_Body_textValue,uint64Value = <int>_Value_Body_uint64Value,objectValue = <int>_Value_Body_objectValue,)
cdef class _Value_BodyReader:
    cdef C_Value.Body.Reader thisptr
    cdef init(self, C_Value.Body.Reader other):
        self.thisptr = other
        return self
        
    cpdef int which(self):
        return self.thisptr.which()
    property uint32Value:
        def __get__(self):
            return self.thisptr.getUint32Value()
    property float64Value:
        def __get__(self):
            return self.thisptr.getFloat64Value()
    property voidValue:
        def __get__(self):
            return None
    property dataValue:
        def __get__(self):
            return None
    property listValue:
        def __get__(self):
            return None
    property int32Value:
        def __get__(self):
            return self.thisptr.getInt32Value()
    property enumValue:
        def __get__(self):
            return self.thisptr.getEnumValue()
    property int8Value:
        def __get__(self):
            return self.thisptr.getInt8Value()
    property boolValue:
        def __get__(self):
            return self.thisptr.getBoolValue()
    property int16Value:
        def __get__(self):
            return self.thisptr.getInt16Value()
    property float32Value:
        def __get__(self):
            return self.thisptr.getFloat32Value()
    property interfaceValue:
        def __get__(self):
            return None
    property uint16Value:
        def __get__(self):
            return self.thisptr.getUint16Value()
    property uint8Value:
        def __get__(self):
            return self.thisptr.getUint8Value()
    property int64Value:
        def __get__(self):
            return self.thisptr.getInt64Value()
    property structValue:
        def __get__(self):
            return None
    property textValue:
        def __get__(self):
            return None
    property uint64Value:
        def __get__(self):
            return self.thisptr.getUint64Value()
    property objectValue:
        def __get__(self):
            return None

cdef class _Value_BodyBuilder:
    cdef C_Value.Body.Builder thisptr
    cdef init(self, C_Value.Body.Builder other):
        self.thisptr = other
        return self
        
    cpdef int which(self):
        return self.thisptr.which()
    property uint32Value:
        def __get__(self):
            return self.thisptr.getUint32Value()
        def __set__(self, val):
            self.thisptr.setUint32Value(val)
    property float64Value:
        def __get__(self):
            return self.thisptr.getFloat64Value()
        def __set__(self, val):
            self.thisptr.setFloat64Value(val)
    property voidValue:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property dataValue:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property listValue:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property int32Value:
        def __get__(self):
            return self.thisptr.getInt32Value()
        def __set__(self, val):
            self.thisptr.setInt32Value(val)
    property enumValue:
        def __get__(self):
            return self.thisptr.getEnumValue()
        def __set__(self, val):
            self.thisptr.setEnumValue(val)
    property int8Value:
        def __get__(self):
            return self.thisptr.getInt8Value()
        def __set__(self, val):
            self.thisptr.setInt8Value(val)
    property boolValue:
        def __get__(self):
            return self.thisptr.getBoolValue()
        def __set__(self, val):
            self.thisptr.setBoolValue(val)
    property int16Value:
        def __get__(self):
            return self.thisptr.getInt16Value()
        def __set__(self, val):
            self.thisptr.setInt16Value(val)
    property float32Value:
        def __get__(self):
            return self.thisptr.getFloat32Value()
        def __set__(self, val):
            self.thisptr.setFloat32Value(val)
    property interfaceValue:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property uint16Value:
        def __get__(self):
            return self.thisptr.getUint16Value()
        def __set__(self, val):
            self.thisptr.setUint16Value(val)
    property uint8Value:
        def __get__(self):
            return self.thisptr.getUint8Value()
        def __set__(self, val):
            self.thisptr.setUint8Value(val)
    property int64Value:
        def __get__(self):
            return self.thisptr.getInt64Value()
        def __set__(self, val):
            self.thisptr.setInt64Value(val)
    property structValue:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property textValue:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property uint64Value:
        def __get__(self):
            return self.thisptr.getUint64Value()
        def __set__(self, val):
            self.thisptr.setUint64Value(val)
    property objectValue:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
cdef class _ValueReader:
    cdef C_Value.Reader thisptr
    cdef init(self, C_Value.Reader other):
        self.thisptr = other
        return self
        
    property body:
        def __get__(self):
            return _Value_BodyReader().init(<C_Value.Body.Reader>self.thisptr.getBody())

cdef class _ValueBuilder:
    cdef C_Value.Builder thisptr
    cdef init(self, C_Value.Builder other):
        self.thisptr = other
        return self
        
    property body:
        def __get__(self):
            return _Value_BodyBuilder().init(<C_Value.Body.Builder>self.thisptr.getBody())
        def __set__(self, val):
            pass

cdef class _ConstNodeReader:
    cdef C_ConstNode.Reader thisptr
    cdef init(self, C_ConstNode.Reader other):
        self.thisptr = other
        return self
        
    property type:
        def __get__(self):
            return _TypeReader().init(<C_Type.Reader>self.thisptr.getType())
    property value:
        def __get__(self):
            return _ValueReader().init(<C_Value.Reader>self.thisptr.getValue())

cdef class _ConstNodeBuilder:
    cdef C_ConstNode.Builder thisptr
    cdef init(self, C_ConstNode.Builder other):
        self.thisptr = other
        return self
        
    property type:
        def __get__(self):
            return _TypeBuilder().init(<C_Type.Builder>self.thisptr.getType())
        def __set__(self, val):
            pass
    property value:
        def __get__(self):
            return _ValueBuilder().init(<C_Value.Builder>self.thisptr.getValue())
        def __set__(self, val):
            pass


_Type_Body_Which = make_enum('_Type_Body_Which',boolType = <int>_Type_Body_boolType,structType = <int>_Type_Body_structType,int32Type = <int>_Type_Body_int32Type,voidType = <int>_Type_Body_voidType,uint16Type = <int>_Type_Body_uint16Type,dataType = <int>_Type_Body_dataType,objectType = <int>_Type_Body_objectType,int64Type = <int>_Type_Body_int64Type,float64Type = <int>_Type_Body_float64Type,interfaceType = <int>_Type_Body_interfaceType,uint32Type = <int>_Type_Body_uint32Type,uint8Type = <int>_Type_Body_uint8Type,listType = <int>_Type_Body_listType,int8Type = <int>_Type_Body_int8Type,float32Type = <int>_Type_Body_float32Type,enumType = <int>_Type_Body_enumType,uint64Type = <int>_Type_Body_uint64Type,textType = <int>_Type_Body_textType,int16Type = <int>_Type_Body_int16Type,)
cdef class _Type_BodyReader:
    cdef C_Type.Body.Reader thisptr
    cdef init(self, C_Type.Body.Reader other):
        self.thisptr = other
        return self
        
    cpdef int which(self):
        return self.thisptr.which()
    property boolType:
        def __get__(self):
            return None
    property structType:
        def __get__(self):
            return self.thisptr.getStructType()
    property int32Type:
        def __get__(self):
            return None
    property voidType:
        def __get__(self):
            return None
    property uint16Type:
        def __get__(self):
            return None
    property dataType:
        def __get__(self):
            return None
    property objectType:
        def __get__(self):
            return None
    property int64Type:
        def __get__(self):
            return None
    property float64Type:
        def __get__(self):
            return None
    property interfaceType:
        def __get__(self):
            return self.thisptr.getInterfaceType()
    property uint32Type:
        def __get__(self):
            return None
    property uint8Type:
        def __get__(self):
            return None
    property listType:
        def __get__(self):
            return _TypeReader().init(<C_Type.Reader>self.thisptr.getListType())
    property int8Type:
        def __get__(self):
            return None
    property float32Type:
        def __get__(self):
            return None
    property enumType:
        def __get__(self):
            return self.thisptr.getEnumType()
    property uint64Type:
        def __get__(self):
            return None
    property textType:
        def __get__(self):
            return None
    property int16Type:
        def __get__(self):
            return None

cdef class _Type_BodyBuilder:
    cdef C_Type.Body.Builder thisptr
    cdef init(self, C_Type.Body.Builder other):
        self.thisptr = other
        return self
        
    cpdef int which(self):
        return self.thisptr.which()
    property boolType:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property structType:
        def __get__(self):
            return self.thisptr.getStructType()
        def __set__(self, val):
            self.thisptr.setStructType(val)
    property int32Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property voidType:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property uint16Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property dataType:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property objectType:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property int64Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property float64Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property interfaceType:
        def __get__(self):
            return self.thisptr.getInterfaceType()
        def __set__(self, val):
            self.thisptr.setInterfaceType(val)
    property uint32Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property uint8Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property listType:
        def __get__(self):
            return _TypeBuilder().init(<C_Type.Builder>self.thisptr.getListType())
        def __set__(self, val):
            pass
    property int8Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property float32Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property enumType:
        def __get__(self):
            return self.thisptr.getEnumType()
        def __set__(self, val):
            self.thisptr.setEnumType(val)
    property uint64Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property textType:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property int16Type:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
cdef class _TypeReader:
    cdef C_Type.Reader thisptr
    cdef init(self, C_Type.Reader other):
        self.thisptr = other
        return self
        
    property body:
        def __get__(self):
            return _Type_BodyReader().init(<C_Type.Body.Reader>self.thisptr.getBody())

cdef class _TypeBuilder:
    cdef C_Type.Builder thisptr
    cdef init(self, C_Type.Builder other):
        self.thisptr = other
        return self
        
    property body:
        def __get__(self):
            return _Type_BodyBuilder().init(<C_Type.Body.Builder>self.thisptr.getBody())
        def __set__(self, val):
            pass


cdef class _FileNode_ImportReader:
    cdef C_FileNode.Import.Reader thisptr
    cdef init(self, C_FileNode.Import.Reader other):
        self.thisptr = other
        return self
        
    property id:
        def __get__(self):
            return self.thisptr.getId()
    property name:
        def __get__(self):
            return None

cdef class _FileNode_ImportBuilder:
    cdef C_FileNode.Import.Builder thisptr
    cdef init(self, C_FileNode.Import.Builder other):
        self.thisptr = other
        return self
        
    property id:
        def __get__(self):
            return self.thisptr.getId()
        def __set__(self, val):
            self.thisptr.setId(val)
    property name:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
cdef class _FileNodeReader:
    cdef C_FileNode.Reader thisptr
    cdef init(self, C_FileNode.Reader other):
        self.thisptr = other
        return self
        
    property imports:
        def __get__(self):
            return _List_FileNode_FileNode_Import_Reader().init(self.thisptr.getImports())

cdef class _FileNodeBuilder:
    cdef C_FileNode.Builder thisptr
    cdef init(self, C_FileNode.Builder other):
        self.thisptr = other
        return self
        
    property imports:
        def __get__(self):
            return _List_FileNode_FileNode_Import_Builder().init(self.thisptr.getImports())
    cpdef initImports(self, uint num):
        return _List_FileNode_FileNode_Import_Builder().init(self.thisptr.initImports(num))


_Node_Body_Which = make_enum('_Node_Body_Which',annotationNode = <int>_Node_Body_annotationNode,interfaceNode = <int>_Node_Body_interfaceNode,enumNode = <int>_Node_Body_enumNode,structNode = <int>_Node_Body_structNode,constNode = <int>_Node_Body_constNode,fileNode = <int>_Node_Body_fileNode,)
cdef class _Node_BodyReader:
    cdef C_Node.Body.Reader thisptr
    cdef init(self, C_Node.Body.Reader other):
        self.thisptr = other
        return self
        
    cpdef int which(self):
        return self.thisptr.which()
    property annotationNode:
        def __get__(self):
            return _AnnotationNodeReader().init(<C_AnnotationNode.Reader>self.thisptr.getAnnotationNode())
    property interfaceNode:
        def __get__(self):
            return _InterfaceNodeReader().init(<C_InterfaceNode.Reader>self.thisptr.getInterfaceNode())
    property enumNode:
        def __get__(self):
            return _EnumNodeReader().init(<C_EnumNode.Reader>self.thisptr.getEnumNode())
    property structNode:
        def __get__(self):
            return _StructNodeReader().init(<C_StructNode.Reader>self.thisptr.getStructNode())
    property constNode:
        def __get__(self):
            return _ConstNodeReader().init(<C_ConstNode.Reader>self.thisptr.getConstNode())
    property fileNode:
        def __get__(self):
            return _FileNodeReader().init(<C_FileNode.Reader>self.thisptr.getFileNode())

cdef class _Node_BodyBuilder:
    cdef C_Node.Body.Builder thisptr
    cdef init(self, C_Node.Body.Builder other):
        self.thisptr = other
        return self
        
    cpdef int which(self):
        return self.thisptr.which()
    property annotationNode:
        def __get__(self):
            return _AnnotationNodeBuilder().init(<C_AnnotationNode.Builder>self.thisptr.getAnnotationNode())
        def __set__(self, val):
            pass
    property interfaceNode:
        def __get__(self):
            return _InterfaceNodeBuilder().init(<C_InterfaceNode.Builder>self.thisptr.getInterfaceNode())
        def __set__(self, val):
            pass
    property enumNode:
        def __get__(self):
            return _EnumNodeBuilder().init(<C_EnumNode.Builder>self.thisptr.getEnumNode())
        def __set__(self, val):
            pass
    property structNode:
        def __get__(self):
            return _StructNodeBuilder().init(<C_StructNode.Builder>self.thisptr.getStructNode())
        def __set__(self, val):
            pass
    property constNode:
        def __get__(self):
            return _ConstNodeBuilder().init(<C_ConstNode.Builder>self.thisptr.getConstNode())
        def __set__(self, val):
            pass
    property fileNode:
        def __get__(self):
            return _FileNodeBuilder().init(<C_FileNode.Builder>self.thisptr.getFileNode())
        def __set__(self, val):
            pass

cdef class _Node_NestedNodeReader:
    cdef C_Node.NestedNode.Reader thisptr
    cdef init(self, C_Node.NestedNode.Reader other):
        self.thisptr = other
        return self
        
    property name:
        def __get__(self):
            return None
    property id:
        def __get__(self):
            return self.thisptr.getId()

cdef class _Node_NestedNodeBuilder:
    cdef C_Node.NestedNode.Builder thisptr
    cdef init(self, C_Node.NestedNode.Builder other):
        self.thisptr = other
        return self
        
    property name:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property id:
        def __get__(self):
            return self.thisptr.getId()
        def __set__(self, val):
            self.thisptr.setId(val)
cdef class _NodeReader:
    cdef C_Node.Reader thisptr
    cdef init(self, C_Node.Reader other):
        self.thisptr = other
        return self
        
    property body:
        def __get__(self):
            return _Node_BodyReader().init(<C_Node.Body.Reader>self.thisptr.getBody())
    property displayName:
        def __get__(self):
            return None
    property annotations:
        def __get__(self):
            return _List_Node_Annotation_Reader().init(self.thisptr.getAnnotations())
    property scopeId:
        def __get__(self):
            return self.thisptr.getScopeId()
    property nestedNodes:
        def __get__(self):
            return _List_Node_Node_NestedNode_Reader().init(self.thisptr.getNestedNodes())
    property id:
        def __get__(self):
            return self.thisptr.getId()

cdef class _NodeBuilder:
    cdef C_Node.Builder thisptr
    cdef init(self, C_Node.Builder other):
        self.thisptr = other
        return self
        
    property body:
        def __get__(self):
            return _Node_BodyBuilder().init(<C_Node.Body.Builder>self.thisptr.getBody())
        def __set__(self, val):
            pass
    property displayName:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property annotations:
        def __get__(self):
            return _List_Node_Annotation_Builder().init(self.thisptr.getAnnotations())
    cpdef initAnnotations(self, uint num):
        return _List_Node_Annotation_Builder().init(self.thisptr.initAnnotations(num))
    property scopeId:
        def __get__(self):
            return self.thisptr.getScopeId()
        def __set__(self, val):
            self.thisptr.setScopeId(val)
    property nestedNodes:
        def __get__(self):
            return _List_Node_Node_NestedNode_Builder().init(self.thisptr.getNestedNodes())
    cpdef initNestedNodes(self, uint num):
        return _List_Node_Node_NestedNode_Builder().init(self.thisptr.initNestedNodes(num))
    property id:
        def __get__(self):
            return self.thisptr.getId()
        def __set__(self, val):
            self.thisptr.setId(val)

cdef class _AnnotationNodeReader:
    cdef C_AnnotationNode.Reader thisptr
    cdef init(self, C_AnnotationNode.Reader other):
        self.thisptr = other
        return self
        
    property targetsField:
        def __get__(self):
            return self.thisptr.getTargetsField()
    property targetsConst:
        def __get__(self):
            return self.thisptr.getTargetsConst()
    property targetsFile:
        def __get__(self):
            return self.thisptr.getTargetsFile()
    property targetsStruct:
        def __get__(self):
            return self.thisptr.getTargetsStruct()
    property targetsParam:
        def __get__(self):
            return self.thisptr.getTargetsParam()
    property targetsUnion:
        def __get__(self):
            return self.thisptr.getTargetsUnion()
    property targetsAnnotation:
        def __get__(self):
            return self.thisptr.getTargetsAnnotation()
    property targetsEnumerant:
        def __get__(self):
            return self.thisptr.getTargetsEnumerant()
    property type:
        def __get__(self):
            return _TypeReader().init(<C_Type.Reader>self.thisptr.getType())
    property targetsEnum:
        def __get__(self):
            return self.thisptr.getTargetsEnum()
    property targetsInterface:
        def __get__(self):
            return self.thisptr.getTargetsInterface()
    property targetsMethod:
        def __get__(self):
            return self.thisptr.getTargetsMethod()

cdef class _AnnotationNodeBuilder:
    cdef C_AnnotationNode.Builder thisptr
    cdef init(self, C_AnnotationNode.Builder other):
        self.thisptr = other
        return self
        
    property targetsField:
        def __get__(self):
            return self.thisptr.getTargetsField()
        def __set__(self, val):
            self.thisptr.setTargetsField(val)
    property targetsConst:
        def __get__(self):
            return self.thisptr.getTargetsConst()
        def __set__(self, val):
            self.thisptr.setTargetsConst(val)
    property targetsFile:
        def __get__(self):
            return self.thisptr.getTargetsFile()
        def __set__(self, val):
            self.thisptr.setTargetsFile(val)
    property targetsStruct:
        def __get__(self):
            return self.thisptr.getTargetsStruct()
        def __set__(self, val):
            self.thisptr.setTargetsStruct(val)
    property targetsParam:
        def __get__(self):
            return self.thisptr.getTargetsParam()
        def __set__(self, val):
            self.thisptr.setTargetsParam(val)
    property targetsUnion:
        def __get__(self):
            return self.thisptr.getTargetsUnion()
        def __set__(self, val):
            self.thisptr.setTargetsUnion(val)
    property targetsAnnotation:
        def __get__(self):
            return self.thisptr.getTargetsAnnotation()
        def __set__(self, val):
            self.thisptr.setTargetsAnnotation(val)
    property targetsEnumerant:
        def __get__(self):
            return self.thisptr.getTargetsEnumerant()
        def __set__(self, val):
            self.thisptr.setTargetsEnumerant(val)
    property type:
        def __get__(self):
            return _TypeBuilder().init(<C_Type.Builder>self.thisptr.getType())
        def __set__(self, val):
            pass
    property targetsEnum:
        def __get__(self):
            return self.thisptr.getTargetsEnum()
        def __set__(self, val):
            self.thisptr.setTargetsEnum(val)
    property targetsInterface:
        def __get__(self):
            return self.thisptr.getTargetsInterface()
        def __set__(self, val):
            self.thisptr.setTargetsInterface(val)
    property targetsMethod:
        def __get__(self):
            return self.thisptr.getTargetsMethod()
        def __set__(self, val):
            self.thisptr.setTargetsMethod(val)


cdef class _EnumNode_EnumerantReader:
    cdef C_EnumNode.Enumerant.Reader thisptr
    cdef init(self, C_EnumNode.Enumerant.Reader other):
        self.thisptr = other
        return self
        
    property codeOrder:
        def __get__(self):
            return self.thisptr.getCodeOrder()
    property name:
        def __get__(self):
            return None
    property annotations:
        def __get__(self):
            return _List_EnumNode_Enumerant_Annotation_Reader().init(self.thisptr.getAnnotations())

cdef class _EnumNode_EnumerantBuilder:
    cdef C_EnumNode.Enumerant.Builder thisptr
    cdef init(self, C_EnumNode.Enumerant.Builder other):
        self.thisptr = other
        return self
        
    property codeOrder:
        def __get__(self):
            return self.thisptr.getCodeOrder()
        def __set__(self, val):
            self.thisptr.setCodeOrder(val)
    property name:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property annotations:
        def __get__(self):
            return _List_EnumNode_Enumerant_Annotation_Builder().init(self.thisptr.getAnnotations())
    cpdef initAnnotations(self, uint num):
        return _List_EnumNode_Enumerant_Annotation_Builder().init(self.thisptr.initAnnotations(num))
cdef class _EnumNodeReader:
    cdef C_EnumNode.Reader thisptr
    cdef init(self, C_EnumNode.Reader other):
        self.thisptr = other
        return self
        
    property enumerants:
        def __get__(self):
            return _List_EnumNode_EnumNode_Enumerant_Reader().init(self.thisptr.getEnumerants())

cdef class _EnumNodeBuilder:
    cdef C_EnumNode.Builder thisptr
    cdef init(self, C_EnumNode.Builder other):
        self.thisptr = other
        return self
        
    property enumerants:
        def __get__(self):
            return _List_EnumNode_EnumNode_Enumerant_Builder().init(self.thisptr.getEnumerants())
    cpdef initEnumerants(self, uint num):
        return _List_EnumNode_EnumNode_Enumerant_Builder().init(self.thisptr.initEnumerants(num))


cdef class _StructNode_UnionReader:
    cdef C_StructNode.Union.Reader thisptr
    cdef init(self, C_StructNode.Union.Reader other):
        self.thisptr = other
        return self
        
    property discriminantOffset:
        def __get__(self):
            return self.thisptr.getDiscriminantOffset()
    property members:
        def __get__(self):
            return _List_StructNode_Union_StructNode_Member_Reader().init(self.thisptr.getMembers())

cdef class _StructNode_UnionBuilder:
    cdef C_StructNode.Union.Builder thisptr
    cdef init(self, C_StructNode.Union.Builder other):
        self.thisptr = other
        return self
        
    property discriminantOffset:
        def __get__(self):
            return self.thisptr.getDiscriminantOffset()
        def __set__(self, val):
            self.thisptr.setDiscriminantOffset(val)
    property members:
        def __get__(self):
            return _List_StructNode_Union_StructNode_Member_Builder().init(self.thisptr.getMembers())
    cpdef initMembers(self, uint num):
        return _List_StructNode_Union_StructNode_Member_Builder().init(self.thisptr.initMembers(num))


_StructNode_Member_Body_Which = make_enum('_StructNode_Member_Body_Which',fieldMember = <int>_StructNode_Member_Body_fieldMember,unionMember = <int>_StructNode_Member_Body_unionMember,)
cdef class _StructNode_Member_BodyReader:
    cdef C_StructNode.Member.Body.Reader thisptr
    cdef init(self, C_StructNode.Member.Body.Reader other):
        self.thisptr = other
        return self
        
    cpdef int which(self):
        return self.thisptr.which()
    property fieldMember:
        def __get__(self):
            return _StructNode_FieldReader().init(<C_StructNode.Field.Reader>self.thisptr.getFieldMember())
    property unionMember:
        def __get__(self):
            return _StructNode_UnionReader().init(<C_StructNode.Union.Reader>self.thisptr.getUnionMember())

cdef class _StructNode_Member_BodyBuilder:
    cdef C_StructNode.Member.Body.Builder thisptr
    cdef init(self, C_StructNode.Member.Body.Builder other):
        self.thisptr = other
        return self
        
    cpdef int which(self):
        return self.thisptr.which()
    property fieldMember:
        def __get__(self):
            return _StructNode_FieldBuilder().init(<C_StructNode.Field.Builder>self.thisptr.getFieldMember())
        def __set__(self, val):
            pass
    property unionMember:
        def __get__(self):
            return _StructNode_UnionBuilder().init(<C_StructNode.Union.Builder>self.thisptr.getUnionMember())
        def __set__(self, val):
            pass
cdef class _StructNode_MemberReader:
    cdef C_StructNode.Member.Reader thisptr
    cdef init(self, C_StructNode.Member.Reader other):
        self.thisptr = other
        return self
        
    property ordinal:
        def __get__(self):
            return self.thisptr.getOrdinal()
    property body:
        def __get__(self):
            return _StructNode_Member_BodyReader().init(<C_StructNode.Member.Body.Reader>self.thisptr.getBody())
    property codeOrder:
        def __get__(self):
            return self.thisptr.getCodeOrder()
    property name:
        def __get__(self):
            return None
    property annotations:
        def __get__(self):
            return _List_StructNode_Member_Annotation_Reader().init(self.thisptr.getAnnotations())

cdef class _StructNode_MemberBuilder:
    cdef C_StructNode.Member.Builder thisptr
    cdef init(self, C_StructNode.Member.Builder other):
        self.thisptr = other
        return self
        
    property ordinal:
        def __get__(self):
            return self.thisptr.getOrdinal()
        def __set__(self, val):
            self.thisptr.setOrdinal(val)
    property body:
        def __get__(self):
            return _StructNode_Member_BodyBuilder().init(<C_StructNode.Member.Body.Builder>self.thisptr.getBody())
        def __set__(self, val):
            pass
    property codeOrder:
        def __get__(self):
            return self.thisptr.getCodeOrder()
        def __set__(self, val):
            self.thisptr.setCodeOrder(val)
    property name:
        def __get__(self):
            return None
        def __set__(self, val):
            pass
    property annotations:
        def __get__(self):
            return _List_StructNode_Member_Annotation_Builder().init(self.thisptr.getAnnotations())
    cpdef initAnnotations(self, uint num):
        return _List_StructNode_Member_Annotation_Builder().init(self.thisptr.initAnnotations(num))

cdef class _StructNode_FieldReader:
    cdef C_StructNode.Field.Reader thisptr
    cdef init(self, C_StructNode.Field.Reader other):
        self.thisptr = other
        return self
        
    property defaultValue:
        def __get__(self):
            return _ValueReader().init(<C_Value.Reader>self.thisptr.getDefaultValue())
    property type:
        def __get__(self):
            return _TypeReader().init(<C_Type.Reader>self.thisptr.getType())
    property offset:
        def __get__(self):
            return self.thisptr.getOffset()

cdef class _StructNode_FieldBuilder:
    cdef C_StructNode.Field.Builder thisptr
    cdef init(self, C_StructNode.Field.Builder other):
        self.thisptr = other
        return self
        
    property defaultValue:
        def __get__(self):
            return _ValueBuilder().init(<C_Value.Builder>self.thisptr.getDefaultValue())
        def __set__(self, val):
            pass
    property type:
        def __get__(self):
            return _TypeBuilder().init(<C_Type.Builder>self.thisptr.getType())
        def __set__(self, val):
            pass
    property offset:
        def __get__(self):
            return self.thisptr.getOffset()
        def __set__(self, val):
            self.thisptr.setOffset(val)
cdef class _StructNodeReader:
    cdef C_StructNode.Reader thisptr
    cdef init(self, C_StructNode.Reader other):
        self.thisptr = other
        return self
        
    property dataSectionWordSize:
        def __get__(self):
            return self.thisptr.getDataSectionWordSize()
    property members:
        def __get__(self):
            return _List_StructNode_StructNode_Member_Reader().init(self.thisptr.getMembers())
    property pointerSectionSize:
        def __get__(self):
            return self.thisptr.getPointerSectionSize()

cdef class _StructNodeBuilder:
    cdef C_StructNode.Builder thisptr
    cdef init(self, C_StructNode.Builder other):
        self.thisptr = other
        return self
        
    property dataSectionWordSize:
        def __get__(self):
            return self.thisptr.getDataSectionWordSize()
        def __set__(self, val):
            self.thisptr.setDataSectionWordSize(val)
    property members:
        def __get__(self):
            return _List_StructNode_StructNode_Member_Builder().init(self.thisptr.getMembers())
    cpdef initMembers(self, uint num):
        return _List_StructNode_StructNode_Member_Builder().init(self.thisptr.initMembers(num))
    property pointerSectionSize:
        def __get__(self):
            return self.thisptr.getPointerSectionSize()
        def __set__(self, val):
            self.thisptr.setPointerSectionSize(val)

cdef class _AnnotationReader:
    cdef C_Annotation.Reader thisptr
    cdef init(self, C_Annotation.Reader other):
        self.thisptr = other
        return self
        
    property id:
        def __get__(self):
            return self.thisptr.getId()
    property value:
        def __get__(self):
            return _ValueReader().init(<C_Value.Reader>self.thisptr.getValue())

cdef class _AnnotationBuilder:
    cdef C_Annotation.Builder thisptr
    cdef init(self, C_Annotation.Builder other):
        self.thisptr = other
        return self
        
    property id:
        def __get__(self):
            return self.thisptr.getId()
        def __set__(self, val):
            self.thisptr.setId(val)
    property value:
        def __get__(self):
            return _ValueBuilder().init(<C_Value.Builder>self.thisptr.getValue())
        def __set__(self, val):
            pass

cdef class MessageBuilder:
    cdef capnp.MessageBuilder * thisptr
    def __dealloc__(self):
        del self.thisptr
    cpdef getRootCodeGeneratorRequest(self):
        return _CodeGeneratorRequestBuilder().init(self.thisptr.getRootCodeGeneratorRequest())
    cpdef initRootCodeGeneratorRequest(self):
        return _CodeGeneratorRequestBuilder().init(self.thisptr.initRootCodeGeneratorRequest())
    cpdef getRootInterfaceNode(self):
        return _InterfaceNodeBuilder().init(self.thisptr.getRootInterfaceNode())
    cpdef initRootInterfaceNode(self):
        return _InterfaceNodeBuilder().init(self.thisptr.initRootInterfaceNode())
    cpdef getRootValue(self):
        return _ValueBuilder().init(self.thisptr.getRootValue())
    cpdef initRootValue(self):
        return _ValueBuilder().init(self.thisptr.initRootValue())
    cpdef getRootConstNode(self):
        return _ConstNodeBuilder().init(self.thisptr.getRootConstNode())
    cpdef initRootConstNode(self):
        return _ConstNodeBuilder().init(self.thisptr.initRootConstNode())
    cpdef getRootType(self):
        return _TypeBuilder().init(self.thisptr.getRootType())
    cpdef initRootType(self):
        return _TypeBuilder().init(self.thisptr.initRootType())
    cpdef getRootFileNode(self):
        return _FileNodeBuilder().init(self.thisptr.getRootFileNode())
    cpdef initRootFileNode(self):
        return _FileNodeBuilder().init(self.thisptr.initRootFileNode())
    cpdef getRootNode(self):
        return _NodeBuilder().init(self.thisptr.getRootNode())
    cpdef initRootNode(self):
        return _NodeBuilder().init(self.thisptr.initRootNode())
    cpdef getRootAnnotationNode(self):
        return _AnnotationNodeBuilder().init(self.thisptr.getRootAnnotationNode())
    cpdef initRootAnnotationNode(self):
        return _AnnotationNodeBuilder().init(self.thisptr.initRootAnnotationNode())
    cpdef getRootEnumNode(self):
        return _EnumNodeBuilder().init(self.thisptr.getRootEnumNode())
    cpdef initRootEnumNode(self):
        return _EnumNodeBuilder().init(self.thisptr.initRootEnumNode())
    cpdef getRootStructNode(self):
        return _StructNodeBuilder().init(self.thisptr.getRootStructNode())
    cpdef initRootStructNode(self):
        return _StructNodeBuilder().init(self.thisptr.initRootStructNode())
    cpdef getRootAnnotation(self):
        return _AnnotationBuilder().init(self.thisptr.getRootAnnotation())
    cpdef initRootAnnotation(self):
        return _AnnotationBuilder().init(self.thisptr.initRootAnnotation())
cdef class MallocMessageBuilder(MessageBuilder):
    def __cinit__(self):
        self.thisptr = new capnp.MallocMessageBuilder()


cdef class MessageReader:
    cdef capnp.MessageReader * thisptr
    def __dealloc__(self):
        del self.thisptr
    cpdef getRootCodeGeneratorRequest(self):
        return _CodeGeneratorRequestReader().init(self.thisptr.getRootCodeGeneratorRequest())
    cpdef getRootInterfaceNode(self):
        return _InterfaceNodeReader().init(self.thisptr.getRootInterfaceNode())
    cpdef getRootValue(self):
        return _ValueReader().init(self.thisptr.getRootValue())
    cpdef getRootConstNode(self):
        return _ConstNodeReader().init(self.thisptr.getRootConstNode())
    cpdef getRootType(self):
        return _TypeReader().init(self.thisptr.getRootType())
    cpdef getRootFileNode(self):
        return _FileNodeReader().init(self.thisptr.getRootFileNode())
    cpdef getRootNode(self):
        return _NodeReader().init(self.thisptr.getRootNode())
    cpdef getRootAnnotationNode(self):
        return _AnnotationNodeReader().init(self.thisptr.getRootAnnotationNode())
    cpdef getRootEnumNode(self):
        return _EnumNodeReader().init(self.thisptr.getRootEnumNode())
    cpdef getRootStructNode(self):
        return _StructNodeReader().init(self.thisptr.getRootStructNode())
    cpdef getRootAnnotation(self):
        return _AnnotationReader().init(self.thisptr.getRootAnnotation())

cdef class StreamFdMessageReader(MessageReader):
    def __cinit__(self, int fd):
        self.thisptr = new capnp.StreamFdMessageReader(int)

cdef class PackedFdMessageReader(MessageReader):
    def __cinit__(self, int fd):
        self.thisptr = new capnp.PackedFdMessageReader(int)

def writeMessageToFd(int fd, MessageBuilder m):
    capnp.writeMessageToFd(fd, deref(m.thisptr))
def writePackedMessageToFd(int fd, MessageBuilder m):
    capnp.writePackedMessageToFd(fd, deref(m.thisptr))

# Make the namespace human usable
from types import ModuleType
temp = CodeGeneratorRequest = ModuleType('CodeGeneratorRequest')
temp.Reader = _CodeGeneratorRequestReader
temp.Builder = _CodeGeneratorRequestBuilder

temp = ElementSize = ModuleType('ElementSize')
ElementSize = _ElementSize

temp = InterfaceNode = ModuleType('InterfaceNode')
temp.Reader = _InterfaceNodeReader
temp.Builder = _InterfaceNodeBuilder

temp = InterfaceNode.Method = ModuleType('InterfaceNode.Method')
temp.Reader = _InterfaceNode_MethodReader
temp.Builder = _InterfaceNode_MethodBuilder

temp = InterfaceNode.Method.Param = ModuleType('InterfaceNode.Method.Param')
temp.Reader = _InterfaceNode_Method_ParamReader
temp.Builder = _InterfaceNode_Method_ParamBuilder

temp = Value = ModuleType('Value')
temp.Reader = _ValueReader
temp.Builder = _ValueBuilder

temp = Value.Body = ModuleType('Value.Body')
temp.Reader = _Value_BodyReader
temp.Builder = _Value_BodyBuilder

temp = ConstNode = ModuleType('ConstNode')
temp.Reader = _ConstNodeReader
temp.Builder = _ConstNodeBuilder

temp = Type = ModuleType('Type')
temp.Reader = _TypeReader
temp.Builder = _TypeBuilder

temp = Type.Body = ModuleType('Type.Body')
temp.Reader = _Type_BodyReader
temp.Builder = _Type_BodyBuilder

temp = FileNode = ModuleType('FileNode')
temp.Reader = _FileNodeReader
temp.Builder = _FileNodeBuilder

temp = FileNode.Import = ModuleType('FileNode.Import')
temp.Reader = _FileNode_ImportReader
temp.Builder = _FileNode_ImportBuilder

temp = Node = ModuleType('Node')
temp.Reader = _NodeReader
temp.Builder = _NodeBuilder

temp = Node.Body = ModuleType('Node.Body')
temp.Reader = _Node_BodyReader
temp.Builder = _Node_BodyBuilder

temp = Node.NestedNode = ModuleType('Node.NestedNode')
temp.Reader = _Node_NestedNodeReader
temp.Builder = _Node_NestedNodeBuilder

temp = AnnotationNode = ModuleType('AnnotationNode')
temp.Reader = _AnnotationNodeReader
temp.Builder = _AnnotationNodeBuilder

temp = EnumNode = ModuleType('EnumNode')
temp.Reader = _EnumNodeReader
temp.Builder = _EnumNodeBuilder

temp = EnumNode.Enumerant = ModuleType('EnumNode.Enumerant')
temp.Reader = _EnumNode_EnumerantReader
temp.Builder = _EnumNode_EnumerantBuilder

temp = StructNode = ModuleType('StructNode')
temp.Reader = _StructNodeReader
temp.Builder = _StructNodeBuilder

temp = StructNode.Union = ModuleType('StructNode.Union')
temp.Reader = _StructNode_UnionReader
temp.Builder = _StructNode_UnionBuilder

temp = StructNode.Member = ModuleType('StructNode.Member')
temp.Reader = _StructNode_MemberReader
temp.Builder = _StructNode_MemberBuilder

temp = StructNode.Member.Body = ModuleType('StructNode.Member.Body')
temp.Reader = _StructNode_Member_BodyReader
temp.Builder = _StructNode_Member_BodyBuilder

temp = StructNode.Field = ModuleType('StructNode.Field')
temp.Reader = _StructNode_FieldReader
temp.Builder = _StructNode_FieldBuilder

temp = Annotation = ModuleType('Annotation')
temp.Reader = _AnnotationReader
temp.Builder = _AnnotationBuilder

