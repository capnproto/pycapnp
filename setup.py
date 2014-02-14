#!/usr/bin/env python
try:
    from Cython.Build import cythonize
    import Cython
except ImportError:
    raise RuntimeError('No cython installed. Please run `pip install cython`')

if Cython.__version__ < '0.19.1':
    raise RuntimeError('Old cython installed (%s). Please run `pip install -U cython`' % Cython.__version__)

import pkg_resources
setuptools_version = pkg_resources.get_distribution("setuptools").version
if setuptools_version < '0.8':
    raise RuntimeError('Old setuptools installed (%s). Please run `pip install -U setuptools`. Running `pip install pycapnp` will not work alone, since setuptools needs to be upgraded before installing anything else.' % setuptools_version)

from distutils.core import setup
import os

MAJOR = 0
MINOR = 4
MICRO = 2
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
    name="pycapnp",
    packages=["capnp"],
    version=VERSION,
    package_data={'capnp': ['*.pxd', '*.h', '*.capnp', 'helpers/*.pxd', 'helpers/*.h', 'includes/*.pxd', 'lib/*.pxd', 'lib/*.py', 'lib/*.pyx']},
    ext_modules=cythonize('capnp/lib/*.pyx', language="c++"),
    install_requires=[
        'cython > 0.19',
        'setuptools >= 0.8'],
    # PyPi info
    description="A cython wrapping of the C++ Cap'n Proto library",
    long_description=long_description,
    license='BSD',
    author="Jason Paryani",
    author_email="pypi-contact@jparyani.com",
    url = 'https://github.com/jparyani/pycapnp',
    download_url = 'https://github.com/jparyani/pycapnp/archive/v%s.zip' % VERSION,
    keywords = ['capnp', 'capnproto', "Cap'n Proto"],
    classifiers = [
        'Development Status :: 3 - Alpha',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: BSD License',
        'Operating System :: MacOS :: MacOS X',
        'Operating System :: POSIX',
        'Programming Language :: C++',
        'Programming Language :: Cython',
        'Programming Language :: Python :: 2',
        'Programming Language :: Python :: 2.6',
        'Programming Language :: Python :: 2.7',
        'Programming Language :: Python :: 3',
        'Programming Language :: Python :: 3.2',
        'Programming Language :: Python :: 3.3',
        'Programming Language :: Python :: Implementation :: PyPy',
        'Topic :: Communications'],
)
