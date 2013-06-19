#!/usr/bin/env python
from distutils.core import setup
from Cython.Build import cythonize
from jinja2 import Environment, FileSystemLoader
import os

curr_dir = os.path.abspath(os.path.dirname(__file__))
env = Environment(loader=FileSystemLoader(curr_dir))

nodes = {

'Node' : {'body' : 'struct',
'members' : {
  'id' : {'type' : 'UInt64'},
  'displayName' : {'type' : 'Text'},
  'scopeId' : {'type' : 'UInt64'},
  'nestedNodes' : {'type' : 'List[Node.NestedNode]'},
'NestedNode' : {'body' : 'struct', 'is_not_field' : True,
'members' : {
  'name' : {'type' : 'Text'},
  'id' : {'type' : 'UInt64'},
}},
  'annotations' : {'type' : 'List[Annotation]'},
'body' : {'body' : 'union',
'members' : {
  'fileNode' : {'type' : 'FileNode'},
  'structNode' : {'type' : 'StructNode'},
  'enumNode' : {'type' : 'EnumNode'},
  'interfaceNode' : {'type' : 'InterfaceNode'},
  'constNode' : {'type' : 'ConstNode'},
  'annotationNode' : {'type' : 'AnnotationNode'},
}},
}},
'Type' : {'body' : 'struct',
'members' : {
'body' : {'body' : 'union',
'members' : {
  'voidType' : {'type' : 'Void'},
  'boolType' : {'type' : 'Void'},
  'int8Type' : {'type' : 'Void'},
  'int16Type' : {'type' : 'Void'},
  'int32Type' : {'type' : 'Void'},
  'int64Type' : {'type' : 'Void'},
  'uint8Type' : {'type' : 'Void'},
  'uint16Type' : {'type' : 'Void'},
  'uint32Type' : {'type' : 'Void'},
  'uint64Type' : {'type' : 'Void'},
  'float32Type' : {'type' : 'Void'},
  'float64Type' : {'type' : 'Void'},
  'textType' : {'type' : 'Void'},
  'dataType' : {'type' : 'Void'},
  'listType' : {'type' : 'Type'},
  'enumType' : {'type' : 'UInt64'},
  'structType' : {'type' : 'UInt64'},
  'interfaceType' : {'type' : 'UInt64'},
  'objectType' : {'type' : 'Void'},
}},
}},
'Value' : {'body' : 'struct',
'members' : {
'body' : {'body' : 'union',
'members' : {
  'voidValue' : {'type' : 'Void'},
  'boolValue' : {'type' : 'Bool'},
  'int8Value' : {'type' : 'Int8'},
  'int16Value' : {'type' : 'Int16'},
  'int32Value' : {'type' : 'Int32'},
  'int64Value' : {'type' : 'Int64'},
  'uint8Value' : {'type' : 'UInt8'},
  'uint16Value' : {'type' : 'UInt16'},
  'uint32Value' : {'type' : 'UInt32'},
  'uint64Value' : {'type' : 'UInt64'},
  'float32Value' : {'type' : 'Float32'},
  'float64Value' : {'type' : 'Float64'},
  'textValue' : {'type' : 'Text'},
  'dataValue' : {'type' : 'Data'},
  'listValue' : {'type' : 'Object'},
  'enumValue' : {'type' : 'UInt16'},
  'structValue' : {'type' : 'Object'},
  'interfaceValue' : {'type' : 'Void'},
  'objectValue' : {'type' : 'Object'},
}},
}},
'Annotation' : {'body' : 'struct',
'members' : {
  'id' : {'type' : 'UInt64'},
  'value' : {'type' : 'Value'},
}},
'FileNode' : {'body' : 'struct',
'members' : {
  'imports' : {'type' : 'List[FileNode.Import]'},
'Import' : {'body' : 'struct', 'is_not_field' : True,
'members' : {
  'id' : {'type' : 'UInt64'},
  'name' : {'type' : 'Text'},
}},
}},
'ElementSize' : {'body' : 'enum',
'members' : {
  'empty' : {},
  'bit' : {},
  'byte' : {},
  'twoBytes' : {},
  'fourBytes' : {},
  'eightBytes' : {},
  'pointer' : {},
  'inlineComposite' : {},
}},
'StructNode' : {'body' : 'struct',
'members' : {
  'dataSectionWordSize' : {'type' : 'UInt16'},
  'pointerSectionSize' : {'type' : 'UInt16'},
  # 'preferredListEncoding' : {'type' : 'ElementSize'},
  'members' : {'type' : 'List[StructNode.Member]'},
'Member' : {'body' : 'struct', 'is_not_field' : True,
'members' : {
  'name' : {'type' : 'Text'},
  'ordinal' : {'type' : 'UInt16'},
  'codeOrder' : {'type' : 'UInt16'},
  'annotations' : {'type' : 'List[Annotation]'},
'body' : {'body' : 'union',
'members' : {
  'fieldMember' : {'type' : 'StructNode.Field'},
  'unionMember' : {'type' : 'StructNode.Union'},
}},
}},
'Field' : {'body' : 'struct', 'is_not_field' : True,
'members' : {
  'offset' : {'type' : 'UInt32'},
  'type' : {'type' : 'Type'},
  'defaultValue' : {'type' : 'Value'},
}},
'Union' : {'body' : 'struct', 'is_not_field' : True,
'members' : {
  'discriminantOffset' : {'type' : 'UInt32'},
  'members' : {'type' : 'List[StructNode.Member]'},
}},
}},
'EnumNode' : {'body' : 'struct',
'members' : {
  'enumerants' : {'type' : 'List[EnumNode.Enumerant]'},
'Enumerant' : {'body' : 'struct', 'is_not_field' : True,
'members' : {
  'name' : {'type' : 'Text'},
  'codeOrder' : {'type' : 'UInt16'},
  'annotations' : {'type' : 'List[Annotation]'},
}},
}},
'InterfaceNode' : {'body' : 'struct',
'members' : {
  'methods' : {'type' : 'List[InterfaceNode.Method]'},
'Method' : {'body' : 'struct', 'is_not_field' : True,
'members' : {
  'name' : {'type' : 'Text'},
  'codeOrder' : {'type' : 'UInt16'},
  'params' : {'type' : 'List[InterfaceNode.Method.Param]'},
'Param' : {'body' : 'struct', 'is_not_field' : True,
'members' : {
  'name' : {'type' : 'Text'},
  'type' : {'type' : 'Type'},
  'defaultValue' : {'type' : 'Value'},
  'annotations' : {'type' : 'List[Annotation]'},
}},
  'requiredParamCount' : {'type' : 'UInt16'},
  'returnType' : {'type' : 'Type'},
  'annotations' : {'type' : 'List[Annotation]'},
}},
}},
'ConstNode' : {'body' : 'struct',
'members' : {
  'type' : {'type' : 'Type'},
  'value' : {'type' : 'Value'},
}},
'AnnotationNode' : {'body' : 'struct',
'members' : {
  'type' : {'type' : 'Type'},
  'targetsFile' : {'type' : 'Bool'},
  'targetsConst' : {'type' : 'Bool'},
  'targetsEnum' : {'type' : 'Bool'},
  'targetsEnumerant' : {'type' : 'Bool'},
  'targetsStruct' : {'type' : 'Bool'},
  'targetsField' : {'type' : 'Bool'},
  'targetsUnion' : {'type' : 'Bool'},
  'targetsInterface' : {'type' : 'Bool'},
  'targetsMethod' : {'type' : 'Bool'},
  'targetsParam' : {'type' : 'Bool'},
  'targetsAnnotation' : {'type' : 'Bool'},
}},
'CodeGeneratorRequest' : {'body' : 'struct',
'members' : {
  'nodes' : {'type' : 'List[Node]'},
  'requestedFiles' : {'type' : 'List[UInt64]'},
}},
}
primitive_types = set(('Bool','Int8','Int16','Int32','Int64','UInt8','UInt16','UInt32','UInt64','Float32','Float64'))
built_in_types = set(('Bool','Int8','Int16','Int32','Int64','UInt8','UInt16','UInt32','UInt64','Float32','Float64', 'Text', 'Data', 'Void', 'Object'))
list_types = {}
def capitalize(s):
  if len(s) < 2:
    return s
  return s[0].upper() + s[1:]
def fixNodes(n):
  def fixNode(node_dict, full_name):
    nested = {}
    node_dict['full_name'] = full_name
    node_dict['full_name_cython'] = '_' + full_name.replace('.', '_')
    for member, member_dict in node_dict['members'].items():
      member_dict['full_type'] = member_dict.get('type')
      if 'body' in member_dict:
        nested[member] = fixNode(member_dict, full_name+'.'+capitalize(member))
        if 'is_not_field' in member_dict:
          del node_dict['members'][member]
        else:
          node_dict['members'][member] = {'type' : full_name+'.'+capitalize(member)}
          node_dict['members'][member]['full_type'] = node_dict['members'][member].get('type')
      elif member_dict.get('type', '').startswith('List'):
        elem_type = member_dict['type'][member_dict['type'].find('[')+1:member_dict['type'].find(']')]
        elem_type_name = elem_type if elem_type in built_in_types else capitalize((full_name+'.'+elem_type))
        elem_type_cython = elem_type if elem_type in built_in_types else 'C_' + capitalize((full_name+'.'+elem_type))
        list_types['List[%s]' % elem_type_name] = {'elem_type' : elem_type, 'elem_type_cython' : elem_type_cython}
        member_dict['type'] = 'List[%s]' % elem_type_name

      elif '.' in member_dict.get('type', ''):
        member_dict['type'] = '.'.join(member_dict['type'].split('.')[1:])
    node_dict['nestedNodes'] = nested
    return node_dict
  for node, node_dict in n.items():
    fixNode(node_dict, capitalize(node))
  return n

env.filters['capitalize'] = capitalize
nodes = fixNodes(nodes)
tmpl = env.get_template('capnp.tmpl.pxd')
open(os.path.join(curr_dir, 'capnp_schema.pxd'), 'w').write(tmpl.render(nodes=nodes, namespace='::capnp::schema', built_in_types=built_in_types))
tmpl = env.get_template('capnp.tmpl.pyx')
open(os.path.join(curr_dir, 'schema.capnp.cpp.pyx'), 'w').write(tmpl.render(nodes=nodes, namespace='::capnp::schema', primitive_types=primitive_types, built_in_types=built_in_types, list_types=list_types))

setup(
    name = "capnp",
    ext_modules = cythonize('schema.capnp.cpp.pyx'),
)