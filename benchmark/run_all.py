#!/usr/bin/env python

from subprocess import Popen, PIPE
import sys
import os
import json
import random

seed = int(random.random()*10**6)
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

    p = Popen(["time", "-p", "python", "runner.py", name, '-s', type, '-i', str(iters), '--seed', str(seed)] + args, stdout=PIPE, stderr=PIPE)
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

def run_cpp(name, mode, iters, faster, compression):
    res_type = 'capnp'
    reuse = 'no-reuse'
    if faster:
        reuse = 'reuse'
        res_type += '_reuse'
    if compression != 'none':
        res_type += '_' + compression

    p = Popen(["time", "-p", "capnproto-"+name, mode, reuse, compression, str(iters)], stdout=PIPE, stderr=PIPE)
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
    return data


def run_each(name, iters):
    ret = []

    ret.append(run_cpp(name, 'object', iters, False, 'none'))
    ret.append(run_cpp(name, 'object', iters, True, 'none'))
    ret.append(run_cpp(name, 'bytes', iters, False, 'none'))
    ret.append(run_cpp(name, 'bytes', iters, False, 'packed'))
    ret.append(run_cpp(name, 'bytes', iters, True, 'none'))
    ret.append(run_cpp(name, 'bytes', iters, True, 'packed'))

    ret.append(run_one('pycapnp', name, 'object', iters, False))
    ret.append(run_one('proto', name, 'object', iters, False))
    ret.append(run_one('proto', name, 'object', iters, True))

    ret.append(run_one('pycapnp', name, 'bytes', iters, False))
    ret.append(run_one('pycapnp', name, 'bytes', iters, True))
    ret.append(run_one('proto', name, 'bytes', iters, False))
    ret.append(run_one('proto', name, 'bytes', iters, True))

    return ret

def main():
    data = []
    data += run_each('carsales', 2000)
    data += run_each('catrank', 100)
    data += run_each('eval', 10000)
    json.dump(data, sys.stdout, sort_keys=True, indent=4, separators=(',', ': '))

if __name__ == '__main__':
    main()
