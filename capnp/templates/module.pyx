# addressbook_fast.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: include_dirs = {{include_dir}}
# distutils: libraries = capnpc capnp capnp-rpc
# distutils: sources = {{file.filename}}.cpp
# cython: c_string_type = str
# cython: c_string_encoding = default
# cython: embedsignature = True

import capnp
import {{file.filename | replace('.', '_')}}

from libcpp cimport bool as cbool
from capnp cimport helpers
from capnp.includes.capnp_cpp cimport DynamicValue, Schema, VOID, StringPtr
from capnp.lib.capnp cimport _DynamicStructReader, _DynamicStructBuilder, _DynamicListBuilder, _DynamicEnum, _StructSchemaField, to_python_builder, to_python_reader, _to_dict, _setDynamicFieldStatic, _Schema, _InterfaceSchema

from capnp.helpers.non_circular cimport reraise_kj_exception

cdef DynamicValue.Reader _extract_dynamic_struct_builder(_DynamicStructBuilder value):
    return DynamicValue.Reader(value.thisptr.asReader())

cdef DynamicValue.Reader _extract_dynamic_struct_reader(_DynamicStructReader value):
    return DynamicValue.Reader(value.thisptr)

cdef DynamicValue.Reader _extract_dynamic_enum(_DynamicEnum value):
    return DynamicValue.Reader(value.thisptr)

cdef _from_dict(_DynamicStructBuilder msg, dict d):
    for key, val in d.iteritems():
        if key != 'which':
            try:
                msg._set(key, val)
            except Exception as e:
                if 'expected isSetInUnion(field)' in str(e):
                    msg.init(key)
                    msg._set(key, val)

cdef _from_list(_DynamicListBuilder msg, list d):
    cdef size_t count = 0
    for val in d:
        msg._set(count, val)
        count += 1

cdef DynamicValue.Reader to_dynamic_value(value):
    cdef DynamicValue.Reader temp
    cdef StringPtr temp_string
    value_type = type(value)

    if value_type is int or value_type is long:
        if value < 0:
           temp = DynamicValue.Reader(<long long>value)
        else:
           temp = DynamicValue.Reader(<unsigned long long>value)
    elif value_type is float:
        temp = DynamicValue.Reader(<double>value)
    elif value_type is bool:
        temp = DynamicValue.Reader(<cbool>value)
    elif value_type is bytes:
        temp_string = StringPtr(<char*>value, len(value))
        temp = DynamicValue.Reader(temp_string)
    elif isinstance(value, basestring):
        encoded_value = value.encode()
        temp_string = StringPtr(<char*>encoded_value, len(encoded_value))
        temp = DynamicValue.Reader(temp_string)
    elif value is None:
        temp = DynamicValue.Reader(VOID)
    elif value_type is _DynamicStructBuilder:
        temp = _extract_dynamic_struct_builder(value)
    elif value_type is _DynamicStructReader:
        temp = _extract_dynamic_struct_reader(value)
    elif value_type is _DynamicEnum:
        temp = _extract_dynamic_enum(value)
    else:
        raise ValueError("Tried to convert value of: '{}' which is an unsupported type: '{}'".format(str(value), str(type(value))))

    return temp


cdef extern from "{{file.filename}}.h":
    {%- for node in code.nodes %}
    Schema get{{node.module_name}}Schema"capnp::Schema::from<{{node.c_module_path}}>"()

    cdef cppclass {{node.module_name}}"{{node.c_module_path}}":
        cppclass Reader:
        {%- for field in node.struct.fields %}
            DynamicValue.Reader get{{field.c_name}}()
        {%- endfor %}
        cppclass Builder:
        {%- for field in node.struct.fields %}
            DynamicValue.Builder get{{field.c_name}}()
            set{{field.c_name}}(DynamicValue.Reader)
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
    cpdef _get_{{field.name}}(self) except +reraise_kj_exception:
        cdef DynamicValue.Reader temp = self.thisptr_child.get{{field.c_name}}()
        return to_python_reader(temp, self._parent)
    property {{field.name}}:
        def __get__(self):
            return self._get_{{field.name}}()
    {%- endfor %}

    def to_dict(self, verbose=False):
        ret = {
        {% for field in node.struct.fields %}
        {% if field.discriminantValue == 65535 %}
        '{{field.name}}': _to_dict(self.{{field.name}}, verbose),
        {% endif %}
        {%- endfor %}
        }

        {% if node.is_union %}
        which = self.which()
        ret[which] = getattr(self, which)
        {% endif %}

        return ret

cdef class {{node.module_name}}_Builder(_DynamicStructBuilder):
    cdef {{node.module_name}}.Builder thisptr_child
    def __init__(self, _DynamicStructBuilder struct):
        self._init(struct.thisptr, struct._parent, struct.is_root, False)
        self.thisptr_child = (<C_DynamicStruct_Builder>struct.thisptr).as{{node.module_name}}()
    {% for field in node.struct.fields %}
    cpdef _get_{{field.name}}(self) except +reraise_kj_exception:
        cdef DynamicValue.Builder temp = self.thisptr_child.get{{field.c_name}}()
        return to_python_builder(temp, self._parent)
    cpdef _set_{{field.name}}(self, value) except +reraise_kj_exception:
        _setDynamicFieldStatic(self.thisptr, "{{field.name}}", value, self._parent)
        # cdef DynamicValue.Builder temp
        # value_type = type(value)
        # if value_type is list:
        #     builder = to_python_builder(self.thisptr_child.get{{field.c_name}}(), self._parent)
        #     _from_list(builder, value)
        # elif value_type is dict:
        #     builder = to_python_builder(self.thisptr_child.get{{field.c_name}}(), self._parent)
        #     _from_dict(builder, value)
        # else:
        #     self.thisptr_child.set{{field.c_name}}(to_dynamic_value(value))

    property {{field.name}}:
        def __get__(self):
            return self._get_{{field.name}}()
        def __set__(self, value):
            self._set_{{field.name}}(value)
    {%- endfor %}

    def to_dict(self, verbose=False):
        ret = {
        {% for field in node.struct.fields %}
        {% if field.discriminantValue == 65535 %}
        '{{field.name}}': _to_dict(self.{{field.name}}, verbose),
        {% endif %}
        {%- endfor %}
        }

        {% if node.is_union %}
        which = self.which()
        ret[which] = getattr(self, which)
        {% endif %}

        return ret

capnp.register_type({{node.id}}, ({{node.module_name}}_Reader, {{node.module_name}}_Builder))
{% endfor %}
