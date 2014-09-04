#!/usr/bin/env python
from distutils.core import setup
from Cython.Build import cythonize
import os

setup(
    name="{{code.requestedFiles[0] | replace('.', '_')}}",
    ext_modules=cythonize('*_capnp_cython.pyx', language="c++")
)
