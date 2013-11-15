.. _api:

API Reference
===================

.. automodule:: capnp

.. currentmodule:: capnp

Internal Classes
----------------
These classes are internal to the library. You will never need to allocate 
one yourself, but you may end up using some of their member methods.

Modules
~~~~~~~~~~
These are classes that are made for you when you import a Cap'n Proto file::

  import capnp
  import addressbook_capnp

  print type(addressbook_capnp.Person) # capnp.capnp._StructModule

.. autoclass:: _StructModule
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _InterfaceModule
  :members:
  :undoc-members:
  :inherited-members:

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
  
.. autoclass:: _DynamicResizableListBuilder
  :members:
  :undoc-members:
  :inherited-members:

RPC
~~~~~~~~~~~~~~~
  
.. autoclass:: _DynamicCapabilityClient
  :members:
  :undoc-members:
  :inherited-members:

  
.. autoclass:: _CapabilityClient
  :members:
  :undoc-members:
  :inherited-members:

Miscellaneous
~~~~~~~~~~~~~
.. autoclass:: _DynamicOrphan
  :members:
  :undoc-members:
  :inherited-members:

Functions
-------------
.. autofunction:: load
.. autofunction:: add_import_hook
.. autofunction:: remove_import_hook

Classes
----------------

RPC
~~~~~~~~~~~~~~~
.. autoclass:: EventLoop
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: FdAsyncIoStream
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: RpcClient
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: RpcServer
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: Restorer
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: KjException
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: PromiseFulfillerPair
  :members:
  :undoc-members:
  :inherited-members:

Miscellaneous
~~~~~~~~~~~~~
.. autoclass:: SchemaParser
  :members:
  :undoc-members:
  :inherited-members:


