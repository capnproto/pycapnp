# addressbook_fast.pyx
# distutils: language = c++
# distutils: extra_compile_args = --std=c++11
# distutils: include_dirs = /usr/local/lib/python2.7/site-packages
# cython: c_string_type = str
# cython: c_string_encoding = default
# cython: embedsignature = True

import capnp
{%- for file in code.requestedFiles %}
import {{file.filename | replace('.', '_')}}
{% endfor %}
from capnp.includes.capnp_cpp cimport DynamicValue
from capnp.lib.capnp cimport _DynamicStructReader, _DynamicStructBuilder, _StructSchemaField, to_python_builder, to_python_reader, _to_dict, _setDynamicFieldWithField

{%- for node in code.nodes %}
{{node.schema}} = {{node.module_path}}.schema
    {%- for field in node.struct.fields %}
cdef _StructSchemaField {{node.module_name}}_{{field.name}} = {{node.schema}}.fields['{{field.name}}']
    {%- endfor %}

cdef class {{node.module_name}}_Reader(_DynamicStructReader):
    def __init__(self, _DynamicStructReader struct):
        self._init(struct.thisptr, struct._parent, struct.is_root, False)
    {% for field in node.struct.fields %}
    cpdef _get_{{field.name}}(self):
        cdef DynamicValue.Reader temp = self.thisptr.getByField({{node.module_name}}_{{field.name}}.thisptr)
        return to_python_reader(temp, self._parent)
    property {{field.name}}:
        def __get__(self):
            return self._get_{{field.name}}()
    {%- endfor %}

    def to_dict(self, verbose=False):
        return {
        {% for field in node.struct.fields %}
        '{{field.name}}': _to_dict(self.{{field.name}}, verbose),
        {%- endfor %}
        }

cdef class {{node.module_name}}_Builder(_DynamicStructBuilder):
    def __init__(self, _DynamicStructBuilder struct):
        self._init(struct.thisptr, struct._parent, struct.is_root, False)
    {% for field in node.struct.fields %}
    cpdef _get_{{field.name}}(self):
        cdef DynamicValue.Builder temp = self.thisptr.getByField({{node.module_name}}_{{field.name}}.thisptr)
        return to_python_builder(temp, self._parent)
    cpdef _set_{{field.name}}(self, value):
        _setDynamicFieldWithField(self.thisptr, {{node.module_name}}_{{field.name}}, value, self._parent)
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
