from __future__ import print_function

import capnp
import schema_capnp
import sys
from jinja2 import Environment, PackageLoader

def main():
  env = Environment(loader=PackageLoader('capnp', 'templates'))
  env.filters['format_name'] = lambda name: name[name.find(':')+1:]

  code = schema_capnp.CodeGeneratorRequest.read(sys.stdin)
  code=code.to_dict()
  code['nodes'] = [node for node in code['nodes'] if 'struct' in node]
  for node in code['nodes']:
    displayName = node['displayName']
    parent, path = displayName.split(':')
    node['module_path'] = parent.replace('.', '_') + '.' + '.'.join([x[0].upper() + x[1:] for x in path.split('.')])
    node['module_name'] = path.replace('.', '_')
    node['schema'] = '_{}_Schema'.format(node['module_name'])
    is_union = False
    for field in node['struct']['fields']:
      if field['discriminantValue'] != 65535:
        is_union = True
    node['is_union'] = is_union

  module = env.get_template('module.pyx')
  filename = code['requestedFiles'][0]['filename'].replace('.', '_') + '_cython.pyx'
  # TODO: handle multiple files
  with open(filename, 'w') as out:
    out.write(module.render(code=code))

  setup = env.get_template('setup.py')
  with open('setup_capnp.py', 'w') as out:
    out.write(setup.render(code=code))
  print('You now need to build the cython module by running `python setup_capnp.py build_ext --inplace`.')
  print()
