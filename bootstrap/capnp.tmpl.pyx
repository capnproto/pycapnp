# schema.capnp.cpp.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: libraries = capnp

cimport schema_cpp as capnp
from schema_cpp cimport {% for node_name, node_dict in nodes.items() %}{% if node_dict['body'] != 'enum' %}{{node_name|capitalize}} as C_{{node_name|capitalize}}{{',' if not loop.last}}{%- endif %}{% endfor %}
from schema_cpp cimport {% for node_dict in enum_types %}{%- for member_name, member_dict in node_dict['members'].items() %}{{node_dict['full_name_cython']}}_{{member_name}}{{',' if not loop.last}}{%- endfor %}{{',' if not loop.last}}{%- endfor %}
from schema_cpp cimport {% for node_dict in union_types %}{%- for member_name, member_dict in node_dict['members'].items() %}{{node_dict['full_name_cython']}}_{{member_name}}{{',' if not loop.last}}{%- endfor %}{{',' if not loop.last}}{% endfor %}

# from schema_cpp cimport *
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

ctypedef char * Object
ctypedef bint Bool
ctypedef float Float32
ctypedef double Float64
cdef extern from "capnp/blob.h" namespace "::capnp":
    cdef cppclass Data:
        char * begin()
        size_t size()
    cdef cppclass Text:
        char * cStr()
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

{%- for list_name, list_dict in list_types.items() %}
cdef class _{{ list_name |replace('[', '_')|replace(']','_')|replace('.','_')}}Reader:
    cdef List[{{ list_dict['elem_type_cython'] }}].Reader thisptr
    cdef init(self, List[{{ list_dict['elem_type_cython'] }}].Reader other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        {%- if list_dict['elem_type'] in built_in_types %}
        return self.thisptr[index]
        {%- else %}
        return _{{ list_dict['elem_type']|replace('.','_') }}Reader().init(<{{ list_dict['elem_type_cython'] }}.Reader>self.thisptr[index])
        {%- endif %}

    def __len__(self):
        return self.thisptr.size()
cdef class _{{ list_name |replace('[', '_')|replace(']','_')|replace('.','_')}}Builder:
    cdef List[{{ list_dict['elem_type_cython'] }}].Builder thisptr
    cdef init(self, List[{{ list_dict['elem_type_cython'] }}].Builder other):
        self.thisptr = other
        return self
    def __getitem__(self, index):
        size = self.thisptr.size()
        if index >= size:
            raise IndexError('Out of bounds')
        index = index % size
        {%- if list_dict['elem_type'] in built_in_types %}
        return self.thisptr[index]
        {%- else %}
        return _{{ list_dict['elem_type']|replace('.','_') }}Builder().init(<{{ list_dict['elem_type_cython'] }}.Builder>self.thisptr[index])
        {%- endif %}
    def __len__(self):
        return self.thisptr.size()
{%- endfor %}
{%- for node_name, node_dict in nodes.items() recursive %}
{{ loop(node_dict['nestedNodes'].items()) }}

    {%- if node_dict['body'] != 'enum' %}
      {%- if node_dict['body'] == 'union' %}
{{ node_dict['full_name_cython'] }}_Which = make_enum('{{ node_dict['full_name_cython'] }}_Which', {%- for member_name, member_dict in node_dict['members'].items() %}{{member_name}} = <int>{{node_dict['full_name_cython']}}_{{member_name}},{%- endfor %})
      {%- endif %}
cdef class {{ node_dict['full_name_cython'] }}Reader:
    cdef C_{{ node_dict['full_name'] }}.Reader thisptr
    cdef init(self, C_{{ node_dict['full_name'] }}.Reader other):
        self.thisptr = other
        return self
        {% if node_dict['body'] == 'union' %}
    cpdef int which(self):
        return self.thisptr.which()
        {%- endif %}
        {%- for member_name, member_dict in node_dict['members'].items() %}
    property {{member_name}}:
        def __get__(self):
            {%- if member_dict['type'] in primitive_types %}
            return self.thisptr.get{{member_name|capitalize}}()
            {%- elif member_dict['type'].startswith('List[') %}
            return _{{ member_dict['type'] |replace('[', '_')|replace(']','_')|replace('.','_')}}Reader().init(self.thisptr.get{{member_name|capitalize}}())
            {%- elif member_dict['type'] == 'Text' %}
            return self.thisptr.get{{member_name|capitalize}}().cStr()
            {%- elif member_dict['type'] == 'Data' %}
            temp = self.thisptr.get{{member_name|capitalize}}()
            return (<char*>temp.begin())[:temp.size()]
            {%- elif member_dict['type'] in built_in_types %}
            return None
            {%- else %}
            return _{{ member_dict['full_type']|replace('.','_') }}Reader().init(<C_{{ member_dict['full_type'] }}.Reader>self.thisptr.get{{member_name|capitalize}}())
            {%- endif %}
        {%- endfor %}

cdef class {{ node_dict['full_name_cython'] }}Builder:
    cdef C_{{ node_dict['full_name'] }}.Builder thisptr
    cdef init(self, C_{{ node_dict['full_name'] }}.Builder other):
        self.thisptr = other
        return self
        {% if node_dict['body'] == 'union' %}
    cpdef int which(self):
        return self.thisptr.which()
        {%- endif %}
        {%- for member_name, member_dict in node_dict['members'].items() %}
    property {{member_name}}:
        def __get__(self):
            {%- if member_dict['type'] in primitive_types %}
            return self.thisptr.get{{member_name|capitalize}}()
            {%- elif member_dict['type'].startswith('List[') %}
            return _{{ member_dict['type'] |replace('[', '_')|replace(']','_')|replace('.','_')}}Builder().init(self.thisptr.get{{member_name|capitalize}}())
            {%- elif member_dict['type'] == 'Text' %}
            return self.thisptr.get{{member_name|capitalize}}().cStr()
            {%- elif member_dict['type'] == 'Data' %}
            temp = self.thisptr.get{{member_name|capitalize}}()
            return (<char*>temp.begin())[:temp.size()]
            {%- elif member_dict['type'] in built_in_types %}
            return None
            {%- else %}
            return _{{ member_dict['full_type']|replace('.','_') }}Builder().init(<C_{{ member_dict['full_type'] }}.Builder>self.thisptr.get{{member_name|capitalize}}())
            {%- endif %}
            {%- if member_dict['type'] in primitive_types %}
        def __set__(self, val):
            self.thisptr.set{{member_name|capitalize}}(val)
            {%- elif member_dict['type'].startswith('List[') %}
    cpdef init{{member_name|capitalize}}(self, uint num):
        return _{{ member_dict['type'] |replace('[', '_')|replace(']','_')|replace('.','_')}}Builder().init(self.thisptr.init{{member_name|capitalize}}(num))
            {%- else %}
        def __set__(self, val):
            pass
            {%- endif %}
        {%- endfor %}
    {%- else %}
{{ node_dict['full_name_cython'] }} = make_enum('{{ node_dict['full_name_cython'] }}', {%- for member_name, member_dict in node_dict['members'].items() %}{{member_name}} = <int>{{node_dict['full_name_cython']}}_{{member_name}},{%- endfor %})
    {%- endif %}
{%- endfor %}

cdef class MessageBuilder:
    cdef capnp.MessageBuilder * thisptr
    def __dealloc__(self):
        del self.thisptr
{%- for name, node_dict in nodes.items() %}
    {%- if node_dict['body'] != 'enum' %}
    cpdef getRoot{{name}}(self):
        return {{ node_dict['full_name_cython'] }}Builder().init(self.thisptr.getRoot{{name}}())
    cpdef initRoot{{name}}(self):
        return {{ node_dict['full_name_cython'] }}Builder().init(self.thisptr.initRoot{{name}}())
    {%- endif %}
{%- endfor %}
cdef class MallocMessageBuilder(MessageBuilder):
    def __cinit__(self):
        self.thisptr = new capnp.MallocMessageBuilder()


cdef class MessageReader:
    cdef capnp.MessageReader * thisptr
    def __dealloc__(self):
        del self.thisptr
{%- for name, node_dict in nodes.items() %}
    {%- if node_dict['body'] != 'enum' %}
    cpdef getRoot{{name}}(self):
        return {{ node_dict['full_name_cython'] }}Reader().init(self.thisptr.getRoot{{name}}())
    {%- endif %}
{%- endfor %}

cdef class StreamFdMessageReader(MessageReader):
    def __cinit__(self, int fd):
        self.thisptr = new capnp.StreamFdMessageReader(fd)

cdef class PackedFdMessageReader(MessageReader):
    def __cinit__(self, int fd):
        self.thisptr = new capnp.PackedFdMessageReader(fd)

def writeMessageToFd(int fd, MessageBuilder m):
    capnp.writeMessageToFd(fd, deref(m.thisptr))
def writePackedMessageToFd(int fd, MessageBuilder m):
    capnp.writePackedMessageToFd(fd, deref(m.thisptr))

# Make the namespace human usable
from types import ModuleType

{%- for node_name, node_dict in nodes.items() recursive %}
temp = {{ node_dict['full_name'] }} = ModuleType('{{ node_dict['full_name'] }}')
{%- if node_dict['body'] != 'enum' %}
temp.Reader = {{ node_dict['full_name_cython'] }}Reader
temp.Builder = {{ node_dict['full_name_cython'] }}Builder
{%- elif node_dict['body'] == 'union' %}
temp.Which = {{ node_dict['full_name_cython'] }}_Which
{%- else %}
{{ node_dict['full_name'] }} = {{ node_dict['full_name_cython'] }}
{%- endif %}
{{ loop(node_dict['nestedNodes'].items()) }}
{%- endfor %}

