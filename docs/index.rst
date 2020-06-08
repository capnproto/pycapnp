.. capnp documentation master file

pycapnp
=======

This is a python wrapping of the C++ implementation of the `Cap'n Proto <https://capnproto.org/>`_ library. Here is a short description, quoted from its docs:

    Cap’n Proto is an insanely fast data interchange format and capability-based RPC system. Think JSON, except binary. Or think Protocol Buffers, except faster. In fact, in benchmarks, Cap’n Proto is INFINITY TIMES faster than Protocol Buffers.

Since the python library is just a thin wrapping of the C++ library, we inherit a lot of what makes Cap'n Proto fast. In some simplistic benchmarks (available in the `benchmark directory of the repo <https://github.com/capnproto/pycapnp/tree/master/benchmark>`_), pycapnp has proven to be decently faster than Protocol Buffers (both pure python and C++ implementations). Also, the python capnp library can load Cap'n Proto schema files directly, without the need for a seperate compile step like with Protocol Buffers or Thrift. pycapnp is available on `github <https://github.com/capnproto/pycapnp.git>`_ and `pypi <https://pypi.python.org/pypi/pycapnp>`_.

Contents:

.. toctree::
   :maxdepth: 4

   install
   quickstart
   capnp
