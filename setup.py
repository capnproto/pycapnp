#!/usr/bin/env python
"""
pycapnp distutils setup.py
"""

import glob
import os
import shutil
import struct
import sys

import pkgconfig

from distutils.command.clean import clean as _clean

from setuptools import setup, Extension

_this_dir = os.path.dirname(__file__)
sys.path.insert(1, _this_dir)

from buildutils.build import build_libcapnp
from buildutils.bundle import fetch_libcapnp


MAJOR = 2
MINOR = 0
MICRO = 0
TAG = ""
VERSION = "%d.%d.%d%s" % (MAJOR, MINOR, MICRO, TAG)


# Write version info
def write_version_py(filename=None):
    """
    Generate pycapnp version
    """
    cnt = """\
from .lib.capnp import _CAPNP_VERSION_MAJOR as LIBCAPNP_VERSION_MAJOR  # noqa: F401
from .lib.capnp import _CAPNP_VERSION_MINOR as LIBCAPNP_VERSION_MINOR  # noqa: F401
from .lib.capnp import _CAPNP_VERSION_MICRO as LIBCAPNP_VERSION_MICRO  # noqa: F401
from .lib.capnp import _CAPNP_VERSION as LIBCAPNP_VERSION  # noqa: F401

version = '%s'
short_version = '%s'
"""
    if not filename:
        filename = os.path.join(os.path.dirname(__file__), "capnp", "version.py")

    a = open(filename, "w")
    try:
        a.write(cnt % (VERSION, VERSION))
    finally:
        a.close()


write_version_py()

# Try to use README.md and CHANGELOG.md as description and changelog
with open("README.md", encoding="utf-8") as f:
    long_description = f.read()
with open("CHANGELOG.md", encoding="utf-8") as f:
    changelog = f.read()
changelog = "\nChangelog\n=============\n" + changelog
long_description += changelog


class clean(_clean):
    """
    Clean command, invoked with `python setup.py clean`
    """

    def run(self):
        _clean.run(self)
        for x in [
            os.path.join("capnp", "lib", "capnp.cpp"),
            os.path.join("capnp", "lib", "capnp.h"),
            os.path.join("capnp", "version.py"),
            "build",
            "build32",
            "build64",
            "bundled",
        ] + glob.glob(os.path.join("capnp", "*.capnp")):
            print("removing %s" % x)
            try:
                os.remove(x)
            except OSError:
                shutil.rmtree(x, ignore_errors=True)


from Cython.Distutils import build_ext as build_ext_c  # noqa: E402


class build_libcapnp_ext(build_ext_c):
    """
    Build capnproto library
    """

    user_options = build_ext_c.user_options + [
        ("force-bundled-libcapnp", None, "Bundle capnp library into the installer"),
        ("force-system-libcapnp", None, "Use system capnp library"),
        ("libcapnp-url=", "u", "URL to download libcapnp from (only if bundled)"),
    ]

    def initialize_options(self):
        build_ext_c.initialize_options(self)
        self.force_bundled_libcapnp = None
        self.force_system_libcapnp = None
        self.libcapnp_url = None

    def finalize_options(self):
        # print('The custom option for install is ', self.custom_option)
        build_ext_c.finalize_options(self)

    def build_extension(self, ext):
        build_ext_c.build_extension(self, ext)

    def run(self):  # noqa: C901
        if self.force_bundled_libcapnp:
            need_build = True
        elif self.force_system_libcapnp:
            need_build = False
        else:
            # Try to use capnp executable to find include and lib path
            capnp_executable = shutil.which("capnp")
            if capnp_executable:
                capnp_dir = os.path.dirname(capnp_executable)
                self.include_dirs += [os.path.join(capnp_dir, "..", "include")]
                self.library_dirs += [
                    os.path.join(
                        capnp_dir, "..", "lib{}".format(8 * struct.calcsize("P"))
                    )
                ]
                self.library_dirs += [os.path.join(capnp_dir, "..", "lib")]

            # Look for capnproto using pkg-config (and minimum version)
            try:
                if pkgconfig.installed("capnp", ">= 0.7.0"):
                    need_build = False
                else:
                    need_build = True
            except EnvironmentError:
                # pkg-config not available in path
                need_build = True

        if need_build:
            print(
                "*WARNING* no libcapnp detected or rebuild forced. "
                "Attempting to build it from source now. "
                "If you have C++ Cap'n Proto installed, it may be out of date or is not being detected. "
                "This may take a while..."
            )
            bundle_dir = os.path.join(_this_dir, "bundled")
            if not os.path.exists(bundle_dir):
                os.mkdir(bundle_dir)
            build_dir = os.path.join(
                _this_dir, "build{}".format(8 * struct.calcsize("P"))
            )
            if not os.path.exists(build_dir):
                os.mkdir(build_dir)

            # Check if we've already built capnproto
            capnp_bin = os.path.join(build_dir, "bin", "capnp")
            if os.name == "nt":
                capnp_bin = os.path.join(build_dir, "bin", "capnp.exe")

            if not os.path.exists(capnp_bin):
                # Not built, fetch and build
                fetch_libcapnp(bundle_dir, self.libcapnp_url)
                build_libcapnp(bundle_dir, build_dir)
            else:
                print("capnproto already built at {}".format(build_dir))

            self.include_dirs = [os.path.join(build_dir, "include")] + self.include_dirs
            self.library_dirs = [
                os.path.join(build_dir, "lib{}".format(8 * struct.calcsize("P"))),
                os.path.join(build_dir, "lib"),
            ] + self.library_dirs

            # Copy .capnp files from source
            src_glob = glob.glob(os.path.join(build_dir, "include", "capnp", "*.capnp"))
            dst_dir = os.path.join(self.build_lib, "capnp")
            os.makedirs(dst_dir, exist_ok=True)
            for file in src_glob:
                print("copying {} -> {}".format(file, dst_dir))
                shutil.copy(file, dst_dir)

        return build_ext_c.run(self)


extra_compile_args = ["--std=c++14"]
extra_link_args = []
if os.name == "nt":
    extra_compile_args = ["/std:c++14", "/MD"]
    extra_link_args = ["/MANIFEST"]

import Cython.Build  # noqa: E402
import Cython  # noqa: E402

extensions = [
    Extension(
        "*",
        [
            "capnp/helpers/capabilityHelper.cpp",
            "capnp/lib/*.pyx",
        ],
        extra_compile_args=extra_compile_args,
        extra_link_args=extra_link_args,
        language="c++",
    )
]

setup(
    python_requires=">=3.8",
    name="pycapnp",
    packages=["capnp"],
    version=VERSION,
    package_data={
        "capnp": [
            "*.pxd",
            "*.h",
            "*.capnp",
            "helpers/*.pxd",
            "helpers/*.h",
            "includes/*.pxd",
            "lib/*.pxd",
            "lib/*.py",
            "lib/*.pyx",
            "lib/*.h",
            "templates/*",
        ]
    },
    ext_modules=Cython.Build.cythonize(extensions),
    cmdclass={"clean": clean, "build_ext": build_libcapnp_ext},
    install_requires=[],
    entry_points={"console_scripts": ["capnpc-cython = capnp._gen:main"]},
    # PyPi info
    description="A cython wrapping of the C++ Cap'n Proto library",
    long_description=long_description,
    long_description_content_type="text/markdown",
    license="BSD-2-Clause",
    # (setup.py only supports 1 author...)
    author="Jacob Alexander",  # <- Current maintainer; Original author -> Jason Paryani
    author_email="haata@kiibohd.com",
    url="https://github.com/capnproto/pycapnp",
    download_url="https://github.com/haata/pycapnp/archive/v%s.zip" % VERSION,
    keywords=["capnp", "capnproto", "Cap'n Proto", "pycapnp"],
    classifiers=[
        "Development Status :: 5 - Production/Stable",
        "Intended Audience :: Developers",
        "Operating System :: MacOS :: MacOS X",
        "Operating System :: Microsoft :: Windows :: Windows 10",
        "Operating System :: POSIX",
        "Programming Language :: C++",
        "Programming Language :: Cython",
        "Programming Language :: Python :: 3.8",
        "Programming Language :: Python :: 3.9",
        "Programming Language :: Python :: 3.10",
        "Programming Language :: Python :: 3.11",
        "Programming Language :: Python :: 3.12",
        "Programming Language :: Python :: Implementation :: PyPy",
        "Topic :: Communications",
    ],
)
