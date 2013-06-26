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

ctypedef char * Object
ctypedef bint Bool
ctypedef float Float32
ctypedef double Float64
        
cdef extern from "capnp/blob.h" namespace "::capnp":
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
cdef extern from "capnp/message.h" namespace "::capnp":
    cdef cppclass List[T]:
        cppclass Reader:
            T operator[](uint)
            uint size()
        cppclass Builder:
            T operator[](uint)
            uint size()

cdef extern from "schema.capnp.h" namespace "::capnp::schema":
{%- for node_dict in enum_types %}
    enum {{node_name|capitalize}}:
    {%- for member_name, member_dict in node_dict['members'].items() %}
        {{node_dict['full_name_cython']}}_{{member_name}} "::capnp::schema::{{node_dict['full_name']}}::{{member_name|upper_and_under}}"
    {%- endfor %}
{%- endfor %}
{%- for node_dict in union_types %}
    enum {{node_dict['full_name_cython']}}_Which:
    {%- for member_name, member_dict in node_dict['members'].items() %}
        {{node_dict['full_name_cython']}}_{{member_name}} "::capnp::schema::{{node_dict['full_name']|replace('.', '::')}}::Which::{{member_name|upper_and_under}}"
    {%- endfor %}
{%- endfor %}
{%- for node_name, node_dict in nodes.items() %}
    {% if node_dict['body'] != 'enum' %}cdef cppclass {{node_name|capitalize}}{%- endif %}
{%- endfor %}

{%- for node_name, node_dict in nodes.items() recursive %}

  {%- if node_dict['body'] != 'enum' %}
    {{ 'cdef ' if loop.depth == 1 }}cppclass {{node_name|capitalize}}:

    {%- for node_name, node_dict in node_dict['nestedNodes'].items() %}
        cppclass {{node_name|capitalize}}
    {%- endfor %}

    {{ loop(node_dict['nestedNodes'].items()) | indent }}
        cppclass Reader:
            {{'int which()' if node_dict['body'] == 'union'}}
    {%- for member_name, member_dict in node_dict['members'].items() %}
            {{member_dict['type']}}{{'.Reader' if member_dict.get('type', '').startswith('List') or member_dict.get('type', '') in ['Text', 'Data'] }} get{{member_name|capitalize}}()
    {%- endfor %}
        cppclass Builder:
            {{'int which()' if node_dict['body'] == 'union'}}
    {%- for member_name, member_dict in node_dict['members'].items() %}
            {{member_dict['type']}}{{'.Builder' if member_dict.get('type', '').startswith('List') or member_dict.get('type', '') in ['Text', 'Data'] }} get{{member_name|capitalize}}()
        {%- if member_dict.get('type', '').startswith('List') %}
            {{member_dict['type']}}.Builder init{{member_name|capitalize}}(int)
        {%- else %}
            {{' ' if not member_dict['type']}}void set{{member_name|capitalize}}({{member_dict['type']}})
        {%- endif %}
    {%- endfor %}
  {%- endif %}
{%- endfor %}

cdef extern from "capnp/message.h" namespace "::capnp":
    cdef cppclass ReaderOptions:
        uint64_t traversalLimitInWords
        uint nestingLimit

    cdef cppclass MessageBuilder:
{%- for name, values in nodes.items() %}
  {%- if values['body'] != 'enum' %}
        {{name}}.Builder getRoot{{name}}'getRoot<{{namespace}}::{{name}}>'()
        {{name}}.Builder initRoot{{name}}'initRoot<{{namespace}}::{{name}}>'()
  {%- endif %}
{%- endfor %}

    cdef cppclass MessageReader:
{%- for name, values in nodes.items() %}
  {%- if values['body'] != 'enum' %}
        {{name}}.Reader getRoot{{name}}'getRoot<{{namespace}}::{{name}}>'()
  {%- endif %}
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
