.. _install:

Installation
============

Pip
---
The pip installation will using the binary versions of the package (if possible). These contain a bundled version of capnproto (on Linux compiled with `manylinux <https://github.com/pypa/manylinux>`_). Starting from v1.0.0b1 binary releases are available for Windows, macOS and Linux from `pypi <https://pypi.org/project/pycapnp/#history>`_::

    [sudo] pip install pycapnp

To force rebuilding the pip package from source (you'll need requirments.txt or pipenv)::

    pip install --no-binary :all: pycapnp

To force bundling libcapnp (or force system libcapnp), just in case setup.py isn't doing the right thing::

    pip install --no-binary :all: -C force-bundled-libcapnp=True
    pip install --no-binary :all: -C force-system-libcapnp=True

If you're using an older Linux distro (e.g. CentOS 6) you many need to set `LDFLAGS="-Wl,--no-as-needed -lrt"`::

    LDFLAGS="-Wl,--no-as-needed -lrt" pip install --no-binary :all: pycapnp

It's also possible to specify the libcapnp url when bundling (this may not work, there be dragons)::

    pip install --no-binary :all: -C force-bundled-libcapnp=True -C libcapnp-url="https://github.com/capnproto/capnproto/archive/master.tar.gz"

From Source
-----------
Source installation is generally not needed unless you're looking into an issue with capnproto or pycapnp itself.

C++ Cap'n Proto Library
~~~~~~~~~~~~~~~~~~~~~~~
You need to install the C++ Cap'n Proto library first. It requires a C++ compiler with C++14 support, such as GCC 5+ or Clang 5+. Follow installation docs at `https://capnproto.org/install.html <https://capnproto.org/install.html>`_.

pycapnp from git
~~~~~~~~~~~~~~~~
If you want the latest development version, you can clone the github repo::

    git clone https://github.com/capnproto/pycapnp.git

For development packages use one of the following to install the python dependencies::

    pipenv install
    pip install -r requirements.txt

And install pycapnp with::

    cd pycapnp
    pip install .

or::

    cd pycapnp
    python setup.py install


Development
-----------
Clone the repo from https://github.com/capnproto/pycapnp.git::

    git clone https://github.com/capnproto/pycapnp.git

For development packages use one of the following to install the python dependencies::

    pipenv install
    pip install -r requirements.txt

Building::

    cd pycapnp
    pip install .

or::

    cd pycapnp
    python setup.py install

Useful targets for setup.py::

    python setup.py build
    python setup.py clean

Useful command-line arguments are available for setup.py::

    --force-bundled-libcapnp
    --force-system-libcapnp
    --libcapnp-url

Testing is done through pytest::

    cd pycapnp
    pytest
    pytest test/test_rpc_calculator.py

Once you're done installing, take a look at the :ref:`quickstart`
