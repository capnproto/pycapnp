.. _install:

Installation
===================

C++ Cap'n Proto Library
------------------------

You need to install the C++ Cap'n Proto library first. It requires a C++ compiler with C++11 support, such as GCC 4.7+ or Clang 3.2+. Follow installation docs at `http://kentonv.github.io/capnproto/install.html <http://kentonv.github.io/capnproto/install.html>`_, or if you're feeling lazy, you can run the commands below::

    curl -O http://capnproto.org/capnproto-c++-0.4.0.tar.gz
    tar zxf capnproto-c++-0.4.0.tar.gz
    cd capnproto-c++-0.4.0
    ./configure
    make -j6 check
    sudo make install

Pip
---------------------

Using pip is by far the easiest way to install the library. After you've installed the C++ library, all you need to run is::
    
    [sudo] pip install -U cython
    [sudo] pip install -U setuptools
    [sudo] pip install pycapnp

On some systems you will have to install Python's headers before doing any of this. For Debian/Ubuntu, this is::

    sudo apt-get install python-dev

You can control what compiler is used with the environment variable CC, ie. `CC=gcc-4.8 pip install pycapnp`, and flags with CFLAGS. You only need to run the setuptools line if you have a setuptools older than v0.8.0, and the cython line if you have a version older than v0.19.1.

From Source
---------------------

If you want the latest development version, you can clone the github repo and install like so::

    git clone https://github.com/jparyani/pycapnp.git
    pip install ./pycapnp

or::

    cd pycapnp
    python setup.py install

Development
-------------------

Clone the repo from https://github.com/jparyani/pycapnp.git and use the `develop` branch. I'll probably ask you to redo pull requests that target `master` and aren't easily mergable to `develop`::
    
    git clone https://github.com/jparyani/pycapnp.git
    git checkout develop

Testing is done through pytest, like so::

    pip install pytest
    py.test

Once you're done installing, take a look at the :ref:`quickstart`
