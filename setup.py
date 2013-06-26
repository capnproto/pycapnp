#!/usr/bin/env python
from distutils.core import setup
from Cython.Build import cythonize
from jinja2 import Environment, FileSystemLoader
import os

curr_dir = os.path.abspath(os.path.dirname(__file__))
env = Environment(loader=FileSystemLoader(curr_dir))

setup(
    name = "capnp",
    ext_modules = cythonize('schema.pyx'),
)