#!/usr/bin/env python

import argparse
from importlib import import_module
from common import do_benchmark
from timeit import default_timer
import os
import sys

def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument("name", help="Name of the benchmark to run, eg. carsales", nargs='?', default='carsales')
    parser.add_argument("-c", "--compression", help="Specify the compression type", default=None)
    parser.add_argument("-s", "--suffix", help="Choose the protocol type.", default='pycapnp')
    parser.add_argument("-m", "--mode", help="Specify the mode", default='object')
    parser.add_argument("-i", "--iters", help="Specify the number of iterations manually. By default, it will be looked up in preset table", default=10, type=int)
    parser.add_argument("-r", "--reuse", help="If this flag is passed, objects will be re-used", action='store_true')
    parser.add_argument("-I", "--includes", help="Directories to add to PYTHONPATH", default='/usr/local/include')

    return parser.parse_args()

def run_test(args):
    tic = default_timer()

    name = args.name
    module = import_module(name + '_' + args.suffix)
    benchmark = module.Benchmark(compression=args.compression)

    if args.iters is None:
        iters = ITERATIONS[name]
    else:
        iters = args.iters

    do_benchmark(mode=args.mode, benchmark=benchmark, iters=iters, reuse=args.reuse)
    toc = default_timer()
    return toc - tic

def main():
    args = parse_args()
    sys.path.append(args.includes)
    run_test(args)

if __name__ == '__main__':
    main()