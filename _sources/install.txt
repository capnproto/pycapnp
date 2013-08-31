.. _install:

Installation
===================

C++ Cap'n Proto Library
------------------------

You need to install the C++ Cap'n Proto library first. It requires a C++ compiler with C++11 support, such as GCC 4.7+ or Clang 3.2+. Follow installation docs at `http://kentonv.github.io/capnproto/install.html <http://kentonv.github.io/capnproto/install.html>`_ with an added `sudo ldconfig` after you're done installing, or if you're feeling lazy, you can run the commands below::

    wget http://capnproto.org/capnproto-c++-0.3.0-rc2.tar.gz
    tar xzf capnproto-c++-0.3.0-rc2.tar.gz
    cd capnproto-c++-0.3.0-rc2
    ./configure
    make -j8 check
    sudo make install
    sudo ldconfig

Pip
---------------------

Using pip is by far the easiest way to install the library. After you've installed the C++ library, all you need to run is::
    
    pip install -U cython
    pip install -U setuptools
    pip install capnp

You can control the compiler version with the environment variable CC, ie. `CC=gcc-4.8 pip install capnp`. You only need to run the setuptools line if you have a setuptools older than v0.8.0, and the cython line if you have a version older than v0.19.1.

From Source
---------------------

If you want the latest development version, you can clone the github repo and install like so::

    git clone https://github.com/jparyani/capnpc-python-cpp.git
    pip install capnpc-python-cpp

or::

    cd capnpc-python-cpp
    python setup.py install

If you don't use pip, you will need to manually install Cython, and a setuptools with a version >= .8.

Development
-------------------

Clone the repo from https://github.com/jparyani/capnpc-python-cpp.git and use the `develop` branch. I'll probably ask you to redo pull requests that target `master` and aren't easily mergable to `develop`::
    
    git clone https://github.com/jparyani/capnpc-python-cpp.git
    git checkout develop


Once you're done installing, take a look at the :ref:`quickstart`
