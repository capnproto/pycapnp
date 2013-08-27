.. _api:

API Reference
===================

.. automodule:: capnp

.. currentmodule:: capnp

Functions
-------------
.. autofunction:: load
.. autofunction:: writeMessageToFd
.. autofunction:: writePackedMessageToFd

Readers
-------------

.. autoclass:: StreamFdMessageReader
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: PackedFdMessageReader
  :members:
  :undoc-members:
  :inherited-members:

Builders
-------------

.. autoclass:: MessageBuilder
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: MallocMessageBuilder
  :members:
  :undoc-members:
  :inherited-members:

Internal Classes
----------------
These classes are internal to the library. You will never need to allocate 
one yourself, but you may end up using some of their member methods.

Readers
~~~~~~~~~~
.. autoclass:: _DynamicStructReader
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _DynamicListReader
  :members:
  :undoc-members:
  :inherited-members:

Builders
~~~~~~~~~~
.. autoclass:: _DynamicStructBuilder
  :members:
  :undoc-members:
  :inherited-members:
  
.. autoclass:: _DynamicListBuilder
  :members:
  :undoc-members:
  :inherited-members:
