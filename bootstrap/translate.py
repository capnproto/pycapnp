#!/usr/bin/env python
from jinja2 import Template


nodes = {
'Node' : {'body' : 'struct',
          'members' : {
            'id' : {'type' : 'UInt64'}
          }
          }}
f=open('schema.verbose')
for line in f.readlines()[10:]:
    sline = line.strip()
    if sline == '':
        continue
    elif sline.startswith('struct ') or sline.startswith('union ') or sline.startswith('enum '):
        print "'%s' : {'body' : '%s',\n'members' : {" % (line.split()[1], line.split()[0])
    elif sline.startswith('}'):
        print '}},'
    else:
        if len(sline.split()) > 1:
            name, type = sline.split()[:2]
            if type.startswith('List('):
                type = type.replace('List(', 'List[').replace(')', ']').replace('[.', '[')
            if type.startswith('.'):
                type = type[1:]
            print ' ', "'%s' : {'type' : '%s'}," % (name, type)
        else:
            print ' ', "'%s' : {}," % sline.split()[0]