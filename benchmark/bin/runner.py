#!/usr/bin/env python

import argparse
import sys
import os
from importlib import import_module
from timeit import default_timer
import random

_this_dir = os.path.dirname(__file__)
sys.path.append(os.path.join(_this_dir, ".."))
from common import do_benchmark


def parse_args_simple():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "mode", help="Mode to use for serialization, ie. object or bytes"
    )
    parser.add_argument("reuse", help="Currently ignored")
    parser.add_argument("compression", help="Valid values are none or packed")
    parser.add_argument("iters", help="Number of iterations to run for", type=int)
    parser.add_argument(
        "-I",
        "--includes",
        help="Directories to add to PYTHONPATH",
        default="/usr/local/include",
    )

    return parser.parse_args()


def parse_args():
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "name",
        help="Name of the benchmark to run, eg. carsales",
        nargs="?",
        default="carsales",
    )
    parser.add_argument(
        "-c", "--compression", help="Specify the compression type", default=None
    )
    parser.add_argument(
        "-s", "--suffix", help="Choose the protocol type.", default="pycapnp"
    )
    parser.add_argument("-m", "--mode", help="Specify the mode", default="object")
    parser.add_argument(
        "-i",
        "--iters",
        help="Specify the number of iterations manually. By default, it will be looked up in preset table",
        default=10,
        type=int,
    )
    parser.add_argument(
        "-r",
        "--reuse",
        help="If this flag is passed, objects will be re-used",
        action="store_true",
    )
    parser.add_argument(
        "-I",
        "--includes",
        help="Directories to add to PYTHONPATH",
        default="/usr/local/include",
    )

    return parser.parse_args()


def run_test(name, mode, reuse, compression, iters, suffix, includes):
    tic = default_timer()

    name = name
    sys.path.append(includes)
    module = import_module(name + "_" + suffix)
    benchmark = module.Benchmark(compression=compression)

    do_benchmark(mode=mode, benchmark=benchmark, iters=iters, reuse=reuse)
    toc = default_timer()
    return toc - tic


def main():
    args = parse_args()
    run_test(**vars(args))


if __name__ == "__main__":
    main()
