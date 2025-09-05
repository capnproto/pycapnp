.. _api:

API Reference
=============

.. automodule:: capnp

.. currentmodule:: capnp


Classes
-------

RPC
~~~

.. autoclass:: capnp.lib.capnp._RemotePromise
  :members:
  :undoc-members:
  :inherited-members:

Communication
#############

.. autoclass:: TwoPartyClient
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: TwoPartyServer
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: AsyncIoStream
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: capnp.lib.capnp._AsyncIoStream
  :members:
  :undoc-members:
  :inherited-members:

Capability
##########

.. autoclass:: capnp.lib.capnp._DynamicCapabilityClient
  :members:
  :undoc-members:
  :inherited-members:


Response
########

.. autoclass:: capnp.lib.capnp._Response
  :members:
  :undoc-members:
  :inherited-members:


Miscellaneous
~~~~~~~~~~~~~
.. autoclass:: KjException
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: SchemaParser
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: SchemaLoader
  :members:
  :undoc-members:
  :inherited-members:

Functions
---------
.. autofunction:: add_import_hook
.. autofunction:: remove_import_hook
.. autofunction:: cleanup_global_schema_parser

.. autofunction:: kj_loop
.. autofunction:: run

.. autofunction:: load



Internal Classes
----------------
These classes are internal to the library. You will never need to allocate
one yourself, but you may end up using some of their member methods.

Modules
~~~~~~~
These are classes that are made for you when you import a Cap'n Proto file::

  import capnp
  import addressbook_capnp

  print type(addressbook_capnp.Person) # capnp.capnp._StructModule

.. autoclass:: _InterfaceModule
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _StructModule
  :members:
  :undoc-members:
  :inherited-members:

Readers
~~~~~~~
.. autoclass:: _DynamicListReader
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _DynamicStructReader
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _PackedFdMessageReader
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _StreamFdMessageReader
  :members:
  :undoc-members:
  :inherited-members:

Builders
~~~~~~~~
.. autoclass:: _DynamicResizableListBuilder
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _DynamicListBuilder
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _DynamicStructBuilder
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _MallocMessageBuilder
  :members:
  :undoc-members:
  :inherited-members:

RPC
~~~
.. autoclass:: _CapabilityClient
  :members:
  :undoc-members:
  :inherited-members:

.. autoclass:: _DynamicCapabilityClient
  :members:
  :undoc-members:
  :inherited-members:

Miscellaneous
~~~~~~~~~~~~~
.. autoclass:: _DynamicOrphan
  :members:
  :undoc-members:
  :inherited-members:
