#!/usr/bin/env python

from subprocess import Popen, PIPE
import sys
import os
import json

def run_one(type, name, mode, iters, faster):
    args = []
    res_type = type
    if faster:
        if type == 'proto':
            os.environ['PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION'] = 'cpp'
            res_type = 'proto_cpp'
        if type == 'pycapnp':
            args += ['-c', 'packed']
            res_type = 'pycapnp_packed'

    p = Popen(["time", "-p", "python", "runner.py", name, '-s', type, '-i', str(iters)] + args, stdout=PIPE, stderr=PIPE)
    res = p.communicate()[1]

    data = {}
    res = res.strip()

    for line in res.split('\n'):
        vals = line.split()
        data[vals[0]] = float(vals[1])

    data['type'] = res_type
    data['mode'] = mode
    data['name'] = name
    data['iters'] = iters

    if 'PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION' in os.environ:
        del os.environ['PROTOCOL_BUFFERS_PYTHON_IMPLEMENTATION']
    return data

def run_each(name, iters):
    ret = []

    ret.append(run_one('pycapnp', name, 'object', iters, False))
    ret.append(run_one('proto', name, 'object', iters, False))
    ret.append(run_one('proto', name, 'object', iters, True))

    ret.append(run_one('pycapnp', name, 'passByBytes', iters, False))
    ret.append(run_one('pycapnp', name, 'passByBytes', iters, True))
    ret.append(run_one('proto', name, 'passByBytes', iters, False))
    ret.append(run_one('proto', name, 'passByBytes', iters, True))

    return ret

def main():
    data = []
    data += run_each('carsales', 2000)
    data += run_each('catrank', 100)
    data += run_each('eval', 10000)
    json.dump(data, sys.stdout, sort_keys=True, indent=4, separators=(',', ': '))

if __name__ == '__main__':
    main()
