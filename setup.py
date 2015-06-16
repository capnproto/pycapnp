#!/usr/bin/env python
from __future__ import print_function

use_cython = False

from distutils.core import setup
import os
import sys
from buildutils import test_build, fetch_libcapnp, build_libcapnp, info
from distutils.errors import CompileError
from distutils.extension import Extension

_this_dir = os.path.dirname(__file__)

MAJOR = 0
MINOR = 5
MICRO = 7
VERSION = '%d.%d.%d' % (MAJOR, MINOR, MICRO)


# Write version info
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

# Try to convert README using pandoc
try:
    import pypandoc
    long_description = pypandoc.convert('README.md', 'rst')
    changelog = pypandoc.convert('CHANGELOG.md', 'rst')
    changelog = '\nChangelog\n=============\n' + changelog
    long_description += changelog
except (IOError, ImportError):
    long_description = ''

# Clean command, invoked with `python setup.py clean`
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

# set use_cython if lib/capnp.cpp is not detected
capnp_compiled_file = os.path.join(os.path.dirname(__file__), 'capnp', 'lib', 'capnp.cpp')
if not os.path.isfile(capnp_compiled_file):
    use_cython = True

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
    use_cython = True

if use_cython:
    from Cython.Distutils import build_ext as build_ext_c
else:
    from distutils.command.build_ext import build_ext as build_ext_c

class build_libcapnp_ext(build_ext_c):
    def build_extension(self, ext):
        build_ext_c.build_extension(self, ext)

    def run(self):
        build_failed = False
        try:
            test_build()
        except CompileError:
            build_failed = True

        if build_failed and force_system_libcapnp:
            raise RuntimeError("libcapnp C++ library not detected and --force-system-libcapnp was used")
        if build_failed or force_bundled_libcapnp:
            if build_failed:
                info("*WARNING* no libcapnp detected. Will download and build it from source now. If you have C++ Cap'n Proto installed, it may be out of date or is not being detected. Downloading and building libcapnp may take a while.")
            bundle_dir = os.path.join(_this_dir, "bundled")
            if not os.path.exists(bundle_dir):
                os.mkdir(bundle_dir)
            build_dir = os.path.join(_this_dir, "build")
            if not os.path.exists(build_dir):
                os.mkdir(build_dir)
            fetch_libcapnp(bundle_dir)

            build_libcapnp(bundle_dir, build_dir)

            self.include_dirs += [os.path.join(build_dir, 'include')]
            self.library_dirs += [os.path.join(build_dir, 'lib')]

        return build_ext_c.run(self)

if use_cython:
    from Cython.Build import cythonize
    import Cython
    extensions = cythonize('capnp/lib/*.pyx')
else:
    extensions = [Extension("capnp.lib.capnp", ["capnp/lib/capnp.cpp"],
                            include_dirs=["."],
                            language='c++',
                            extra_compile_args=['--std=c++11'],
                            libraries=['capnpc', 'capnp-rpc', 'capnp', 'kj-async', 'kj'])]

setup(
    name="pycapnp",
    packages=["capnp"],
    version=VERSION,
    package_data={'capnp': ['*.pxd', '*.h', '*.capnp', 'helpers/*.pxd', 'helpers/*.h', 'includes/*.pxd', 'lib/*.pxd', 'lib/*.py', 'lib/*.pyx', 'templates/*']},
    ext_modules=extensions,
    cmdclass = {
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
    license='BSD',
    author="Jason Paryani",
    author_email="pypi-contact@jparyani.com",
    url = 'https://github.com/jparyani/pycapnp',
    download_url = 'https://github.com/jparyani/pycapnp/archive/v%s.zip' % VERSION,
    keywords = ['capnp', 'capnproto', "Cap'n Proto"],
    classifiers = [
        'Development Status :: 4 - Beta',
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
