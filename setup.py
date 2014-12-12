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
from distutils.extension import Extension
import os

MAJOR = 0
MINOR = 4
MICRO = 6
VERSION = '%d.%d.%d' % (MAJOR, MINOR, MICRO)

def write_version_py(filename=None):
    cnt = """\
version = '%s'
short_version = '%s'

from .lib.capnp import _CAPNP_VERSION_MAJOR as LIBCAPNP_VERSION_MAJOR
from .lib.capnp import _CAPNP_VERSION_MINOR as LIBCAPNP_VERSION_MINOR
from .lib.capnp import _CAPNP_VERSION_MICRO as LIBCAPNP_VERSION_MICRO
from .lib.capnp import _CAPNP_VERSION as LIBCAPNP_VERSION
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

from distutils.command.clean import clean as _clean
class clean(_clean):
    def run(self):
        _clean.run(self)
        for x in [ 'capnp/lib/capnp.cpp', 'capnp/lib/capnp.h', 'capnp/version.py' ]:
            print('removing %s' % x)
            try:
                os.remove(x)
            except OSError:
                pass

include_path = []

BUNDLED_CAPNP_VERSION = (0, 4, 1)
CAPNP_PATH = 'capnproto-c++-%i.%i.%i' % BUNDLED_CAPNP_VERSION
CAPNP_ARCHIVE = CAPNP_PATH + '.tar.gz'
CAPNP_URL = 'https://capnproto.org/%s' % CAPNP_ARCHIVE
# Absolute path to installation
CAPNP_INSTALL_PATH = os.path.join(os.getcwd(), CAPNP_PATH, 'build')
CAPNP_INCLUDE_PATH = os.path.join(CAPNP_INSTALL_PATH, 'include')

# Check if Cap'n Proto is installed. Currently this checks if the `capnp`
# command-line tool is available.
# TODO: Attempt to build a simple program that links to the Cap'n Proto
# libraries to ensure they are present.
import os
import shutil
import subprocess
import tarfile
import urllib
if os.system('capnp id') != 0:
    # Cap'n Proto not installed, let's fetch and install
    print 'Cap\'n Proto not installed, downloading... ',
    urllib.urlretrieve(CAPNP_URL, CAPNP_ARCHIVE)
    print 'done.'
    print 'Extracting... ',
    tarfile.open(CAPNP_ARCHIVE).extractall()
    print 'done.'
    print 'Compiling... ',
    os.chdir(CAPNP_PATH)
    ret = subprocess.call(
        './configure --disable-shared --prefix=%s && make check && make install' %
            CAPNP_INSTALL_PATH,
        shell=True)
    os.chdir('..')
    os.remove(CAPNP_ARCHIVE)
    if ret == 0:
        print 'done.'
    else:
        print 'error. Cleaning up.'
        shutil.rmtree(CAPNP_PATH)
        raise RuntimeError('Error compiling Cap\'n Proto')
    # Now put the compiled libraries on the include path
    include_path.append(CAPNP_INCLUDE_PATH)

extensions = [
    Extension('*', ['capnp/lib/*.pyx'], include_dirs=include_path, library_dirs=include_path)
]

setup(
    name="pycapnp",
    packages=["capnp"],
    version=VERSION,
    package_data={'capnp': ['*.pxd', '*.h', '*.capnp', 'helpers/*.pxd', 'helpers/*.h', 'includes/*.pxd', 'lib/*.pxd', 'lib/*.py', 'lib/*.pyx']},
    ext_modules=cythonize(extensions),
    cmdclass = {
        'clean': clean
    },
    install_requires=[
        'cython >= 0.21',
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

shutil.rmtree(CAPNP_PATH)
