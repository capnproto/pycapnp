# schema.capnp.cpp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnp

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

cdef extern from "schema.capnp.h" namespace "::capnp::schema":
{%- for node_name, node_dict in nodes.items() %}
    cdef cppclass {{node_name|capitalize}}
{%- endfor %}

{%- for node_name, node_dict in nodes.items() recursive %}
    {{ 'cdef ' if loop.depth == 1 }}cppclass {{node_name|capitalize}}:

    {%- for node_name, node_dict in node_dict['nestedNodes'].items() %}
        cppclass {{node_name|capitalize}}
    {%- endfor %}

    {{ loop(node_dict['nestedNodes'].items()) | indent }}
        cppclass Reader:
    {%- for member_name, member_dict in node_dict['members'].items() %}
            {{member_dict['type']}}{{'.Reader' if member_dict.get('type', '').startswith('List') }} get{{member_name|capitalize}}()
    {%- endfor %}
        cppclass Builder:
    {%- for member_name, member_dict in node_dict['members'].items() %}
            {{member_dict['type']}}{{'.Builder' if member_dict.get('type', '').startswith('List') }} get{{member_name|capitalize}}()
        {%- if member_dict.get('type', '').startswith('List') %}
            {{member_dict['type']}}.Builder init{{member_name|capitalize}}(int)
        {%- else %}
            {{' ' if not member_dict['type']}}void set{{member_name|capitalize}}({{member_dict['type']}})
        {%- endif %}
    {%- endfor %}
{%- endfor %}

cdef extern from "capnp/message.h" namespace "::capnp":
    cdef cppclass ReaderOptions:
        uint64_t traversalLimitInWords
        uint nestingLimit

    cdef cppclass MessageBuilder:
{%- for name, values in nodes.items() %}
        {{name}}.Builder getRoot{{name}}'getRoot<{{namespace}}::{{name}}>'()
        {{name}}.Builder initRoot{{name}}'initRoot<{{namespace}}::{{name}}>'()
{%- endfor %}

    cdef cppclass MessageReader:
{%- for name, values in nodes.items() %}
        {{name}}.Reader getRoot{{name}}'getRoot<{{namespace}}::{{name}}>'()
{%- endfor %}
    
    cdef cppclass MallocMessageBuilder(MessageBuilder):
        MallocMessageBuilder()
        MallocMessageBuilder(int)

    enum Void:
        VOID

cdef extern from "capnp/serialize.h" namespace "::capnp":
    cdef cppclass StreamFdMessageReader(MessageReader):
        StreamFdMessageReader(int)
        StreamFdMessageReader(int, ReaderOptions)

    void writeMessageToFd(int, MessageBuilder&)

cdef extern from "capnp/serialize-packed.h" namespace "::capnp":
    cdef cppclass PackedFdMessageReader(MessageReader):
        PackedFdMessageReader(int)
        StreamFdMessageReader(int, ReaderOptions)

    void writePackedMessageToFd(int, MessageBuilder&)
