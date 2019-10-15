'Build the bundled capnp distribution'

import subprocess
import os
import shutil
import sys
import tempfile

def build_libcapnp(bundle_dir, build_dir, verbose=False):
    '''
    Build capnproto
    '''
    bundle_dir = os.path.abspath(bundle_dir)
    capnp_dir = os.path.join(bundle_dir, 'capnproto-c++')
    build_dir = os.path.abspath(build_dir)
    tmp_dir = os.path.join(capnp_dir, 'build')
    if not os.path.exists(tmp_dir):
        os.mkdir(tmp_dir)

    cxxflags = os.environ.get('CXXFLAGS', None)
    os.environ['CXXFLAGS'] = (cxxflags or '') + ' -O2 -DNDEBUG'

    # Enable ninja for compilation if available
    build_type = []
    if shutil.which('ninja'):
        build_type = ['-G', 'Ninja']

    # TODO Determine VS version

    args = [
        'cmake',
        '-DCMAKE_POSITION_INDEPENDENT_CODE=1',
        '-DBUILD_TESTING=OFF',
        '-DBUILD_SHARED_LIBS=OFF',
        '-DCMAKE_INSTALL_PREFIX:PATH={}'.format(build_dir),
        capnp_dir,
    ]
    args.extend(build_type)
    conf = subprocess.Popen(args, cwd=tmp_dir, stdout=sys.stdout)
    returncode = conf.wait()
    if returncode != 0:
        raise RuntimeError('CMake failed')

    # Run build through cmake
    build = subprocess.Popen([
        'cmake',
        '--build',
        '.',
        '--target',
        'install',
    ], cwd=tmp_dir, stdout=sys.stdout)
    returncode = build.wait()
    if cxxflags is None:
        del os.environ['CXXFLAGS']
    else:
        os.environ['CXXFLAGS'] = cxxflags
    if returncode != 0:
        raise RuntimeError('capnproto compilation failed')
