#!/usr/bin/env python
from distutils.core import setup
from Cython.Build import cythonize
setup(
    name = "capnp",
    ext_modules = cythonize('capnp.pyx'),
)