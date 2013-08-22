.. _install:

Installation
===================

C++ Cap'n Proto Library
------------------------

You need to install the C++ Cap'n Proto library first. It requires a C++ compiler with C++11 support, such as GCC 4.7+ or Clang 3.2+. Follow installation docs at `http://kentonv.github.io/capnproto/install.html <http://kentonv.github.io/capnproto/install.html>`_ with an added `sudo ldconfig` after you're done installing, or if you're feeling lazy, you can run the commands below::

    wget https://github.com/kentonv/capnproto/archive/master.zip
    unzip master.zip
    cd capnproto-master/c++
    ./setup-autotools.sh
    autoreconf -i
    ./configure
    make -j6 check
    sudo make install
    sudo ldconfig

Pip
---------------------

Using pip is by far the easiest way to install the library. After you've installed the C++ library, all you need to run is::
    
    pip install -U setuptools
    pip install capnp

You only need to run the setuptools line if you have a setuptools older than v0.8.0.

From Source
---------------------

If you want the latest development version, you can clone the github repo and install like so::

    git clone https://github.com/jparyani/capnpc-python-cpp.git
    pip install capnpc-python-cpp

or::

    cd capnpc-python-cpp
    python setup.py install

If you don't use pip, you will need to manually install Cython, and a setuptools with a version > .7.

Once you're done installing, take a look at the :ref:`quickstart`
