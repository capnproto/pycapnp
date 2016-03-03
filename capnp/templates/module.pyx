# addressbook_fast.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: include_dirs = {{include_dir}}
# distutils: libraries = capnpc capnp capnp-rpc
# distutils: sources = {{file.filename}}.cpp
# cython: c_string_type = str
# cython: c_string_encoding = default
# cython: embedsignature = True

{% macro getter(field, type) -%}
    {% if 'uint' in field['type'] -%}
uint64_t get{{field.c_name}}() except +reraise_kj_exception
    {% elif 'int' in field['type'] -%}
int64_t get{{field.c_name}}() except +reraise_kj_exception
    {% elif 'void' == field['type'] -%}
void get{{field.c_name}}() except +reraise_kj_exception
    {% elif 'bool' == field['type'] -%}
cbool get{{field.c_name}}() except +reraise_kj_exception
    {% elif 'text' == field['type'] -%}
StringPtr get{{field.c_name}}() except +reraise_kj_exception
    {% elif 'data' == field['type'] -%}
Data.{{type}} get{{field.c_name}}() except +reraise_kj_exception
    {% else -%}
DynamicValue.{{type}} get{{field.c_name}}() except +reraise_kj_exception
    {%- endif %}
{%- endmacro %}
# TODO: add struct/enum/list types

{% macro getfield(field, type) -%}
cpdef _get_{{field.name}}(self):
    {% if 'int' in field['type'] -%}
    return self.thisptr_child.get{{field.c_name}}()
    {% elif 'void' == field['type'] -%}
    self.thisptr_child.get{{field.c_name}}()
    return None
    {% elif 'bool' == field['type'] -%}
    return self.thisptr_child.get{{field.c_name}}()
    {% elif 'text' == field['type'] -%}
    temp = self.thisptr_child.get{{field.c_name}}()
    return (<char*>temp.begin())[:temp.size()]
    {% elif 'data' == field['type'] -%}
    temp = self.thisptr_child.get{{field.c_name}}()
    return <bytes>((<char*>temp.begin())[:temp.size()])
    {% else -%}
    cdef DynamicValue.{{type}} temp = self.thisptr_child.get{{field.c_name}}()
    return to_python_{{type | lower}}(temp, self._parent)
    {% endif -%}
{%- endmacro %}

{% macro setter(field) -%}
    {% if 'int' in field['type'] -%}
void set{{field.c_name}}({{field.type}}_t) except +reraise_kj_exception
    {% elif 'bool' == field['type'] -%}
void set{{field.c_name}}(cbool) except +reraise_kj_exception
    {% elif 'text' == field['type'] -%}
void set{{field.c_name}}(StringPtr) except +reraise_kj_exception
    {% elif 'data' == field['type'] -%}
void set{{field.c_name}}(ArrayPtr[byte]) except +reraise_kj_exception
    {% else -%}
void set{{field.c_name}}(DynamicValue.Reader) except +reraise_kj_exception
    {%- endif %}
{%- endmacro %}

{% macro setfield(field) -%}
    {% if 'int' in field['type'] -%}
cpdef _set_{{field.name}}(self, {{field.type}}_t value):
    self.thisptr_child.set{{field.c_name}}(value)
    {% elif 'void' == field['type'] -%}
cpdef _set_{{field.name}}(self, value=None):
    pass
    {% elif 'bool' == field['type'] -%}
cpdef _set_{{field.name}}(self, bool value):
    self.thisptr_child.set{{field.c_name}}(value)
    {% elif 'list' == field['type'] -%}
cpdef _set_{{field.name}}(self, list value):
    cdef uint i = 0
    self.init("{{field.name}}", len(value))
    cdef _DynamicListBuilder temp =  self._get_{{field.name}}()
    for elem in value:
        {% if 'struct' in field['sub_type'] -%}
        temp._get(i).from_dict(elem)
        {% else -%}
        temp[i] = elem
        {% endif -%}
        i += 1
    {% elif 'text' == field['type'] -%}
cpdef _set_{{field.name}}(self, value):
    cdef StringPtr temp_string
    if type(value) is bytes:
        temp_string = StringPtr(<char*>value, len(value))
    else:
        encoded_value = value.encode('utf-8')
        temp_string = StringPtr(<char*>encoded_value, len(encoded_value))
    self.thisptr_child.set{{field.c_name}}(temp_string)
    {% elif 'data' == field['type'] -%}
cpdef _set_{{field.name}}(self, value):
    cdef StringPtr temp_string
    if type(value) is bytes:
        temp_string = StringPtr(<char*>value, len(value))
    else:
        encoded_value = value.encode('utf-8')
        temp_string = StringPtr(<char*>encoded_value, len(encoded_value))
    self.thisptr_child.set{{field.c_name}}(ArrayPtr[byte](<byte *>temp_string.begin(), temp_string.size()))
    {% else -%}
cpdef _set_{{field.name}}(self, value):
    _setDynamicFieldStatic(self.thisptr, "{{field.name}}", value, self._parent)
    {% endif -%}
{%- endmacro %}

import capnp
import {{file.filename | replace('.', '_')}}

from capnp.includes.types cimport *
from capnp cimport helpers
from capnp.includes.capnp_cpp cimport DynamicValue, Schema, VOID, StringPtr, ArrayPtr, Data
from capnp.lib.capnp cimport _DynamicStructReader, _DynamicStructBuilder, _DynamicListBuilder, _DynamicEnum, _StructSchemaField, to_python_builder, to_python_reader, _to_dict, _setDynamicFieldStatic, _Schema, _InterfaceSchema

from capnp.helpers.non_circular cimport reraise_kj_exception

cdef DynamicValue.Reader _extract_dynamic_struct_builder(_DynamicStructBuilder value):
    return DynamicValue.Reader(value.thisptr.asReader())

cdef DynamicValue.Reader _extract_dynamic_struct_reader(_DynamicStructReader value):
    return DynamicValue.Reader(value.thisptr)

cdef DynamicValue.Reader _extract_dynamic_enum(_DynamicEnum value):
    return DynamicValue.Reader(value.thisptr)

cdef _from_list(_DynamicListBuilder msg, list d):
    cdef size_t count = 0
    for val in d:
        msg._set(count, val)
        count += 1


cdef extern from "{{file.filename}}.h":
    {%- for node in code.nodes %}
    Schema get{{node.module_name}}Schema"capnp::Schema::from<{{node.c_module_path}}>"()

    cdef cppclass {{node.module_name}}"{{node.c_module_path}}":
        cppclass Reader:
        {%- for field in node.struct.fields %}
            {{ getter(field, "Reader")|indent(12)}}
        {%- endfor %}
        cppclass Builder:
        {%- for field in node.struct.fields %}
            {{ getter(field, "Builder")|indent(12)}}
            {{ setter(field)|indent(12)}}
        {%- endfor %}
    {%- endfor %}

    cdef cppclass C_DynamicStruct_Reader" ::capnp::DynamicStruct::Reader":
    {%- for node in code.nodes %}
        {{node.module_name}}.Reader as{{node.module_name}}"as<{{node.c_module_path}}>"()
    {%- endfor %}

    cdef cppclass C_DynamicStruct_Builder" ::capnp::DynamicStruct::Builder":
    {%- for node in code.nodes %}
        {{node.module_name}}.Builder as{{node.module_name}}"as<{{node.c_module_path}}>"()
    {%- endfor %}

{%- for node in code.nodes %}

{{node.schema}} = _Schema()._init(get{{node.module_name}}Schema()).as_struct()
{{node.module_path}}.schema = {{node.schema}}

cdef class {{node.module_name}}_Reader(_DynamicStructReader):
    cdef {{node.module_name}}.Reader thisptr_child
    def __init__(self, _DynamicStructReader struct):
        self._init(struct.thisptr, struct._parent, struct.is_root, False)
        self.thisptr_child = (<C_DynamicStruct_Reader>struct.thisptr).as{{node.module_name}}()
    {% for field in node.struct.fields %}

    {{ getfield(field, "Reader")|indent(4) }}

    property {{field.name}}:
        def __get__(self):
            return self._get_{{field.name}}()
    {%- endfor %}

    def to_dict(self, verbose=False, ordered=False):
        ret = {
        {% for field in node.struct.fields %}
        {% if field.discriminantValue == 65535 %}
        '{{field.name}}': _to_dict(self.{{field.name}}, verbose, ordered),
        {% endif %}
        {%- endfor %}
        }

        {% if node.is_union %}
        which = self._which_str()
        ret[which] = getattr(self, which)
        {% endif %}

        return ret

cdef class {{node.module_name}}_Builder(_DynamicStructBuilder):
    cdef {{node.module_name}}.Builder thisptr_child
    def __init__(self, _DynamicStructBuilder struct):
        self._init(struct.thisptr, struct._parent, struct.is_root, False)
        self.thisptr_child = (<C_DynamicStruct_Builder>struct.thisptr).as{{node.module_name}}()
    {% for field in node.struct.fields %}
    {{ getfield(field, "Builder")|indent(4) }}
    {{ setfield(field)|indent(4) }}

    property {{field.name}}:
        def __get__(self):
            return self._get_{{field.name}}()
        def __set__(self, value):
            self._set_{{field.name}}(value)
    {%- endfor %}

    def to_dict(self, verbose=False, ordered=False):
        ret = {
        {% for field in node.struct.fields %}
        {% if field.discriminantValue == 65535 %}
        '{{field.name}}': _to_dict(self.{{field.name}}, verbose, ordered),
        {% endif %}
        {%- endfor %}
        }

        {% if node.is_union %}
        which = self._which_str()
        ret[which] = getattr(self, which)
        {% endif %}

        return ret

    def from_dict(self, dict d):
        cdef str key
        for key, val in d.iteritems():
            if False: pass
        {% for field in node.struct.fields %}
            elif key == "{{field.name}}":
                try:
                    self._set_{{field.name}}(val)
                except Exception as e:
                    if 'expected isSetInUnion(field)' in str(e):
                        self.init(key)
                        self._set_{{field.name}}(val)
                    else:
                        raise
        {%- endfor %}
            else:
                raise ValueError('Key not found in struct: ' + key)


capnp.register_type({{node.id}}, ({{node.module_name}}_Reader, {{node.module_name}}_Builder))
{% endfor %}
