#capnpc-python-cpp

## Downloading

For now, this code is only on github, although I plan to put it up on PyPi at somepoint.

You can clone the repo like so:
    git clone https://github.com/jparyani/capnpc-python-cpp.git

## Requirements

A system-wide installation of the Capnproto C++ library, compiled with the 
-fpic flag. All you need to do is follow the official [installation docs](http://kentonv.github.io/capnproto/install.html)].

You also need a working version of the latest [Cython](http://cython.org/) installed. This is easily done with `pip install 'cython >= .19.1'

## Building and installation

`cd` into the repo directory and run `python setup.py install`

## Documentation/Example
At the moment, there is no documenation, but the library is almost a 1:1 clone of the [Capnproto C++ Library](http://kentonv.github.io/capnproto/cxx.html)

The following example should suffice to show off the differences:
    TODO