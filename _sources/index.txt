.. capnp documentation master file

Welcome to capnp's documentation!
=================================

This is a python wrapping of the C++ implementation of the `Cap'n Proto <http://kentonv.github.io/capnproto/>`_ library. Here is a short description, quoted from its docs:
    
    Cap’n Proto is an insanely fast data interchange format and capability-based RPC system. Think JSON, except binary. Or think Protocol Buffers, except faster. In fact, in benchmarks, Cap’n Proto is INFINITY TIMES faster than Protocol Buffers.

The INFINITY TIMES faster part isn't so true for python, but in some simplistic benchmarks (available in the `benchmark directory of the repo <https://github.com/jparyani/capnpc-python-cpp/tree/master/benchmark>`_), capnp has proven to be decently faster than Protocol Buffers. Also, the python capnp library can load Cap'n Proto schema files directly, without the need for a seperate compile step like with Protocol Buffers or Thrift.

Contents:

.. toctree::
   :maxdepth: 4

   install
   quickstart
   capnp


Indices and tables
==================

* :ref:`genindex`
* :ref:`modindex`
* :ref:`search`

