"""utilities for fetching build dependencies."""

#-----------------------------------------------------------------------------
#  Copyright (C) PyZMQ Developers
#  Distributed under the terms of the Modified BSD License.
#
#  This bundling code is largely adapted from pyzmq-static's get.sh by
#  Brandon Craig-Rhodes, which is itself BSD licensed.
#-----------------------------------------------------------------------------
#
# Adapted for use in pycapnp from pyzmq. See https://github.com/zeromq/pyzmq
# for original project.


import os
import shutil
import stat
import sys
import tarfile
from glob import glob
from subprocess import Popen, PIPE

try:
    # py2
    from urllib2 import urlopen
except ImportError:
    # py3
    from urllib.request import urlopen

from .msg import fatal, debug, info, warn

pjoin = os.path.join

#-----------------------------------------------------------------------------
# Constants
#-----------------------------------------------------------------------------

bundled_version = (0,5,2)
libcapnp = "capnproto-c++-%i.%i.%i.tar.gz" % (bundled_version)
libcapnp_url = "https://capnproto.org/" + libcapnp

HERE = os.path.dirname(__file__)
ROOT = os.path.dirname(HERE)

#-----------------------------------------------------------------------------
# Utilities
#-----------------------------------------------------------------------------


def untgz(archive):
    return archive.replace('.tar.gz', '')

def localpath(*args):
    """construct an absolute path from a list relative to the root pycapnp directory"""
    plist = [ROOT] + list(args)
    return os.path.abspath(pjoin(*plist))

def fetch_archive(savedir, url, fname, force=False):
    """download an archive to a specific location"""
    dest = pjoin(savedir, fname)
    if os.path.exists(dest) and not force:
        info("already have %s" % fname)
        return dest
    info("fetching %s into %s" % (url, savedir))
    if not os.path.exists(savedir):
        os.makedirs(savedir)
    req = urlopen(url)
    with open(dest, 'wb') as f:
        f.write(req.read())
    return dest

#-----------------------------------------------------------------------------
# libcapnp
#-----------------------------------------------------------------------------

def fetch_libcapnp(savedir):
    """download and extract libcapnp"""
    dest = pjoin(savedir, 'capnproto-c++')
    if os.path.exists(dest):
        info("already have %s" % dest)
        return
    fname = fetch_archive(savedir, libcapnp_url, libcapnp)
    tf = tarfile.open(fname)
    with_version = pjoin(savedir, tf.firstmember.path)
    tf.extractall(savedir)
    tf.close()
    # remove version suffix:
    shutil.move(with_version, dest)

def stage_platform_hpp(capnproot):
    """stage platform.hpp into libcapnp sources

    Tries ./configure first (except on Windows),
    then falls back on included platform.hpp previously generated.
    """

    platform_hpp = pjoin(capnproot, 'src', 'platform.hpp')
    if os.path.exists(platform_hpp):
        info("already have platform.hpp")
        return
    if os.name == 'nt':
        # stage msvc platform header
        platform_dir = pjoin(capnproot, 'builds', 'msvc')
    else:
        info("attempting ./configure to generate platform.hpp")

        p = Popen('./configure', cwd=capnproot, shell=True,
            stdout=PIPE, stderr=PIPE,
        )
        o,e = p.communicate()
        if p.returncode:
            warn("failed to configure libcapnp:\n%s" % e)
            if sys.platform == 'darwin':
                platform_dir = pjoin(HERE, 'include_darwin')
            elif sys.platform.startswith('freebsd'):
                platform_dir = pjoin(HERE, 'include_freebsd')
            elif sys.platform.startswith('linux-armv'):
                platform_dir = pjoin(HERE, 'include_linux-armv')
            else:
                platform_dir = pjoin(HERE, 'include_linux')
        else:
            return

    info("staging platform.hpp from: %s" % platform_dir)
    shutil.copy(pjoin(platform_dir, 'platform.hpp'), platform_hpp)


def copy_and_patch_libcapnp(capnp, libcapnp):
    """copy libcapnp into source dir, and patch it if necessary.

    This command is necessary prior to running a bdist on Linux or OS X.
    """
    if sys.platform.startswith('win'):
        return
    # copy libcapnp into capnp for bdist
    local = localpath('capnp',libcapnp)
    if not capnp and not os.path.exists(local):
        fatal("Please specify capnp prefix via `setup.py configure --capnp=/path/to/capnp` "
        "or copy libcapnp into capnp/ manually prior to running bdist.")
    try:
        # resolve real file through symlinks
        lib = os.path.realpath(pjoin(capnp, 'lib', libcapnp))
        print ("copying %s -> %s"%(lib, local))
        shutil.copy(lib, local)
    except Exception:
        if not os.path.exists(local):
            fatal("Could not copy libcapnp into capnp/, which is necessary for bdist. "
            "Please specify capnp prefix via `setup.py configure --capnp=/path/to/capnp` "
            "or copy libcapnp into capnp/ manually.")

    if sys.platform == 'darwin':
        # chmod u+w on the lib,
        # which can be user-read-only for some reason
        mode = os.stat(local).st_mode
        os.chmod(local, mode | stat.S_IWUSR)
        # patch install_name on darwin, instead of using rpath
        cmd = ['install_name_tool', '-id', '@loader_path/../%s'%libcapnp, local]
        try:
            p = Popen(cmd, stdout=PIPE,stderr=PIPE)
        except OSError:
            fatal("install_name_tool not found, cannot patch libcapnp for bundling.")
        out,err = p.communicate()
        if p.returncode:
            fatal("Could not patch bundled libcapnp install_name: %s"%err, p.returncode)

