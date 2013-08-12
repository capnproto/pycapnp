#!/usr/bin/env python
try:
    from Cython.Build import cythonize
    import Cython
except ImportError:
    raise RuntimeError('No cython installed. Please run `pip install cython`')

if Cython.__version__ < '0.19.1':
    raise RuntimeError('Old cython installed. Please run `pip install -U cython`')

try:
    import setuptools
except ImportError:
    raise RuntimeError('No setuptools installed. Please run `pip install setuptools`')

if setuptools.__version__ < '.0.9.8':
    raise RuntimeError('Old setuptools installed. Please run `pip install -U setuptools`')

from distutils.core import setup
import os

MAJOR = 0
MINOR = 2
MICRO = 8
VERSION = '%d.%d.%d' % (MAJOR, MINOR, MICRO)


def write_version_py(filename=None):
    cnt = """\
version = '%s'
short_version = '%s'
"""
    if not filename:
        filename = os.path.join(
            os.path.dirname(__file__), 'capnp', 'version.py')

    a = open(filename, 'w')
    try:
        a.write(cnt % (VERSION, VERSION))
    finally:
        a.close()

write_version_py()

try:
    import pypandoc
    long_description = pypandoc.convert('README.md', 'rst')
except (IOError, ImportError):
    long_description = ''

setup(
    name="capnp",
    packages=["capnp"],
    version=VERSION,
    package_data={'capnp': ['*.pxd', '*.pyx', '*.h']},
    ext_modules=cythonize('capnp/*.pyx', language="c++"),
    install_requires=['cython > 0.19'],
    # PyPi info
    description='A cython wrapping of the C++ capnproto library',
    long_description=long_description,
    license='BSD',
    author="Jason Paryani",
    author_email="pypi-contact@jparyani.com",
    url = 'https://github.com/jparyani/capnpc-python-cpp',
    download_url = 'https://github.com/jparyani/capnpc-python-cpp/archive/v{}.zip'.format(VERSION),
    keywords = ['capnp', 'capnproto'],
    classifiers = [
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: BSD License',
        'Operating System :: MacOS :: MacOS X',
        'Operating System :: POSIX',
        'Programming Language :: C++',
        'Programming Language :: Cython',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.3',
        # 'Programming Language :: Python :: Implementation :: PyPy'
        'Topic :: Communications'],
)
