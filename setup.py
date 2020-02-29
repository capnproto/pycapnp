#!/usr/bin/env python
'''
pycapnp distutils setup.py
'''

from __future__ import print_function

import os
import struct
import sys

from distutils.command.clean import clean as _clean
from distutils.errors import CompileError
from distutils.extension import Extension
from distutils.spawn import find_executable

from setuptools import setup, find_packages, Extension

from buildutils import test_build, fetch_libcapnp, build_libcapnp, info

_this_dir = os.path.dirname(__file__)

MAJOR = 1
MINOR = 0
MICRO = 0
TAG = 'b1'
VERSION = '%d.%d.%d%s' % (MAJOR, MINOR, MICRO, TAG)


# Write version info
def write_version_py(filename=None):
    '''
    Generate pycapnp version
    '''
    cnt = """\
version = '%s'
short_version = '%s'

# flake8: noqa E402 F401
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

# Try to use README.md and CHANGELOG.md as description and changelog
with open('README.md', encoding='utf-8') as f:
    long_description = f.read()
with open('CHANGELOG.md', encoding='utf-8') as f:
    changelog = f.read()
changelog = '\nChangelog\n=============\n' + changelog
long_description += changelog

class clean(_clean):
    '''
    Clean command, invoked with `python setup.py clean`
    '''
    def run(self):
        _clean.run(self)
        for x in [ 'capnp/lib/capnp.cpp', 'capnp/lib/capnp.h', 'capnp/version.py' ]:
            print('removing %s' % x)
            try:
                os.remove(x)
            except OSError:
                pass


# hack to parse commandline arguments
force_bundled_libcapnp = "--force-bundled-libcapnp" in sys.argv
if force_bundled_libcapnp:
    sys.argv.remove("--force-bundled-libcapnp")
force_system_libcapnp = "--force-system-libcapnp" in sys.argv
if force_system_libcapnp:
    sys.argv.remove("--force-system-libcapnp")
force_cython = "--force-cython" in sys.argv
if force_cython:
    sys.argv.remove("--force-cython")
    # Always use cython, ignoring option
libcapnp_url = None
try:
    libcapnp_url_index = sys.argv.index("--libcapnp-url")
    libcapnp_url = sys.argv[libcapnp_url_index + 1]
    sys.argv.remove("--libcapnp-url")
    sys.argv.remove(libcapnp_url)
except Exception:
    pass

from Cython.Distutils import build_ext as build_ext_c

class build_libcapnp_ext(build_ext_c):
    '''
    Build capnproto library
    '''
    def build_extension(self, ext):
        build_ext_c.build_extension(self, ext)

    def run(self):
        if force_bundled_libcapnp:
            need_build = True
        elif force_system_libcapnp:
            need_build = False
        else:
            # Try to use capnp executable to find include and lib path
            capnp_executable = find_executable("capnp")
            if capnp_executable:
                self.include_dirs += [os.path.join(os.path.dirname(capnp_executable), '..', 'include')]
                self.library_dirs += [os.path.join(os.path.dirname(capnp_executable), '..', 'lib{}'.format(8 * struct.calcsize("P")))]
                self.library_dirs += [os.path.join(os.path.dirname(capnp_executable), '..', 'lib')]

            # Try to autodetect presence of library. Requires compile/run
            # step so only works for host (non-cross) compliation
            try:
                test_build(include_dirs=self.include_dirs, library_dirs=self.library_dirs)
                need_build = False
            except CompileError:
                need_build = True

        if need_build:
            info(
                "*WARNING* no libcapnp detected or rebuild forced. "
                "Will download and build it from source now. "
                "If you have C++ Cap'n Proto installed, it may be out of date or is not being detected. "
                "Downloading and building libcapnp may take a while."
            )
            bundle_dir = os.path.join(_this_dir, "bundled")
            if not os.path.exists(bundle_dir):
                os.mkdir(bundle_dir)
            build_dir = os.path.join(_this_dir, "build{}".format(8 * struct.calcsize("P")))
            if not os.path.exists(build_dir):
                os.mkdir(build_dir)

            # Check if we've already built capnproto
            capnp_bin = os.path.join(build_dir, 'bin', 'capnp')
            if os.name == 'nt':
                capnp_bin = os.path.join(build_dir, 'bin', 'capnp.exe')

            if not os.path.exists(capnp_bin):
                # Not built, fetch and build
                fetch_libcapnp(bundle_dir, libcapnp_url)
                build_libcapnp(bundle_dir, build_dir)
            else:
                info("capnproto already built at {}".format(build_dir))

            self.include_dirs += [os.path.join(build_dir, 'include')]
            self.library_dirs += [os.path.join(build_dir, 'lib{}'.format(8 * struct.calcsize("P")))]
            self.library_dirs += [os.path.join(build_dir, 'lib')]

        return build_ext_c.run(self)

extra_compile_args = ['--std=c++14']
extra_link_args = []
if os.name == 'nt':
    extra_compile_args = ['/std:c++14', '/MD']
    extra_link_args = ['/MANIFEST']

import Cython.Build
import Cython # noqa: F401
extensions = [Extension(
    '*', ['capnp/helpers/capabilityHelper.cpp', 'capnp/lib/*.pyx'],
    extra_compile_args=extra_compile_args,
    extra_link_args=extra_link_args,
    language='c++',
)]

setup(
    name="pycapnp",
    packages=["capnp"],
    version=VERSION,
    package_data={
        'capnp': [
            '*.pxd', '*.h', '*.capnp', 'helpers/*.pxd', 'helpers/*.h',
            'includes/*.pxd', 'lib/*.pxd', 'lib/*.py', 'lib/*.pyx', 'templates/*'
        ]
    },
    ext_modules=Cython.Build.cythonize(extensions),
    cmdclass={
        'clean': clean,
        'build_ext': build_libcapnp_ext
    },
    install_requires=[],
    entry_points={
        'console_scripts' : ['capnpc-cython = capnp._gen:main']
    },
    # PyPi info
    description="A cython wrapping of the C++ Cap'n Proto library",
    long_description=long_description,
    long_description_content_type = 'text/markdown',
    license='BSD',
    author="Jacob Alexander", # <- Current maintainer; Original author -> Jason Paryani (setup.py only supports 1 author...)
    author_email="haata@kiibohd.com",
    url='https://github.com/capnproto/pycapnp',
    download_url='https://github.com/haata/pycapnp/archive/v%s.zip' % VERSION,
    keywords=['capnp', 'capnproto', "Cap'n Proto", 'pycapnp'],
    classifiers=[
        'Development Status :: 4 - Beta',
        'Intended Audience :: Developers',
        'License :: OSI Approved :: BSD License',
        'Operating System :: MacOS :: MacOS X',
        'Operating System :: Microsoft :: Windows :: Windows 10',
        'Operating System :: POSIX',
        'Programming Language :: C++',
        'Programming Language :: Cython',
        'Programming Language :: Python :: 3.7',
        'Programming Language :: Python :: 3.8',
        'Programming Language :: Python :: Implementation :: PyPy',
        'Topic :: Communications'],
)
