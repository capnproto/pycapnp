## v0.5.7 (2015-06-16)
- Update bundled libcapnp to v0.5.2
- Add warnings for using old restorer methods. You should use `bootstrap` instead
- Fix warning from PyEventPort
- Handle AnyPointers better as arguments to RPC functions
- Add support for using keyword arguments with a named struct in an RPC
- Add bootstrap method to TwoPartyServer
- Add `init` method to lists
- Add support for unix sockets in RPC

## v0.5.6 (2015-04-13)
- Fix a serious bug in TwoPartyServer that was preventing it from working when passed a string address.
- Fix bugs that were exposed by defining KJDEBUG (thanks @davidcarne for finding this)


## v0.5.5 (2015-03-06)
- Update bundled C++ libcapnp to v0.5.1.2 security release


## v0.5.4 (2015-03-02)
- Update bundled C++ libcapnp to v0.5.1.1 security release
- Add bootstrap RPC methods
- Fix possible segfault when importing multiple schemas


## v0.5.3 (2015-02-23)
- Fix possible crash due to bad destructor ordering in MessageReader (by @JohnEmhoff)
- Default to no longer using cython


## v0.5.2 (2015-02-20)
- Add read\_multiple\_bytes/read\_multiple\_bytes\_packed methods
- Added Python 3.4 to the travis build matrix
- Bump version for bundled C++ libcapnp to v0.5.1


## v0.5.1 (2014-12-27)
- Remove installation dependency on cython. We now have no dependencies since libcapnp will automatically build as well.


## v0.5.0 (2014-12-15)
- Timer class `capnp.getTimer()`
- pycapnp is now thread-safe and allows an event loop to be run in each thread
  - You must destroy and re-create the event loop to get this functionality (see `test_threads.py`)
- Inheritance now works correctly for interfaces (previously inherited methods were inaccessible from pycapnp)
- Add ability to import modules with dashes or spaces. Use underscores in place of them
- `from_bytes` with builder=True is no longer zero copy. It never worked correctly, and is much safer now
- Add `num_first_segment_words` argument wherever message creation can occur
- Allow restoring a null objectId by passing None to restore
- Support ordered dictionary in `to_dict`
- Add ListSchema class and schemas for native types under `capnp.types` which completes all the Schemas needed to be wrapped. See `test_schema.py` for examples using it
- Add automatic build of C++ libcapnp if it's not detected on the system. Also add flags --force-bundled-libcapnp and --force-system-libcapnp respectively


## v0.4.6 (2014-9-10)
- Fix build for new 0.21 release of Cython. 0.21 is now the minimum supported version of Cython.


## v0.4.5 (2014-6-26)
- Fix `to_dict` not converting enums to strings


## v0.4.4 (2014-04-25)
- Fix compilation problem with gcc 4.8


## v0.4.3 (2014-02-18)
- Fix problem with uninitialized unions in \_from\_dict
- Add accesible version numbers for C++ libcapnp


## v0.4.2 (2014-02-13)
- Remove onDrained since it was removed upstream
- Replace usage of strings as enum type with custom `_DynamicEnum` class.
- Also change `Struct.which()` method to be a property `Struct.which` and return an enum type (`_DynamicEnumField`, which behaves much like `_DynamicEnum`).
- TwoPartyServer.run_forever() now will handle more than 1 simulataneous connection.
- Change exception wrapper to detect and raise AttributeError for field lookup exceptions (Fixes problem in Python3.x `__dir__`)
- Allow setting of fields with python dicts.


## 0.4.1 (2013-12-18)
- Remove python 3.2 from travis tests. Python 3.2 still should work fine, but it's more trouble than it's worth to write unicode tests that work in both it and Python2.
- Fix problems with null characters in Text/Data fields. Fixes #19


## 0.4.0 (2013-12-12)
- Initial working version of RPC
- Add get_root_as_any to _MessageReader
- Add capnp.pxd for public declarations of cython classes
- Fix problems compiling with gcc4.7


## v0.3.18 (2013-11-05)
- Change naming of ReaderOption parameters to be pep8 compliant


## v0.3.17 (2013-11-05)
- Add ReaderOptions to read/read_packed/from_bytes


## v0.3.16 (2013-10-28)
- Add defaults flag to capnp-json. Also remove 'which' field
- Add capnp-json serializer script. Also fix bugs in from_dict
- Fix build for clang/python3. Also remove -fpermissive
- Add `as_builder` method to Struct Reader
- Add warning when writing the same message more than once
- First working version of capability interfaces
- Wrap InterfaceSchema
- Fix setting string fields to support all types of strings
- Fix changed API for DynamicObject/ObjectPointer


## v0.3.15 (2013-09-19)
- Add not having installed the C++ libcapnp library to 'Common Problems'
- Add _short_str function for use in capnp_test_pycapnp.py
- Add test script for testing with https://github.com/kaos/capnp_test
- Add handling of DynamicObject
- Fix lists of lists or dicts for from_dict


## v0.3.14 (2013-09-04)
- Fix problem with to_dict


## v0.3.13 (2013-09-04)
- Add _DynamicStructBuilder.to_bytes() and <struct module>.from_bytes()
- Change == on StructSchema to return cbool
- Add Builder and Reader ABCs for each struct type

## v0.3.12 (2013-09-03)
- Fix handling of empty path '' in load_module
- Add from_dict
- Fix bug in exception handling for which(). Also standardize exceptions.
- Change import hook to require modules to end in '_capnp'
- Add import monkey patch function.
- Change naming for functions to conform to PEP 8. Also deprecate old read/write API
- Update preferred method for reading/writing messages from files

## v0.3.11 (2013-09-01)
- Forgot to change project name in setup.py

## v0.3.10 (2013-09-01)
- Change all references to old project name (change from capnpc-python-cpp to pycapnp)
- Change DynamicValue.Reader lists to be returned as _DynamicListReader
- Unify setters for DynamicList and DynamicStruct
- Add shortcuts for reading from / writing to files.  In Python, it doesn't make much sense to force people to muck around with MessageReaders and MessageBuilders since everything is landing on the heap anyway.  Instead, let's make it easy:  MyType.read[Packed]From(file) reads a file and returns a MyType reader.  MyType.newMessage() returns a MyType builder representing the root of a new message.  You can call this builder's write[Packed]To(file) method to write it to a file.
- Store Builders by value rather than allocate them separately on the heap (matches treatment of Readers).  v0.3 fixes the bug that made this not work.
- Wrap MessageBuilder::setRoot().
- Add tests based on TestAllTypes from the C++ test.capnp.  Fix problems uncovered in capnp.pyx.
- Implement __str__ and __repr__ for struct and list builders.  __str__ uses prettyPrint while __repr__ shows the type name and the low-whitespace stringification.  Also implement __repr__ for StructSchema, just because why not?


## v0.3.9 (2013-08-30)
- Change load to use a global SchemaParser. Make structs settable as field
- Add docstrings for new functions and _DynamicResizableListBuilder


## v0.3.8 (2013-08-29)
- Add initial tests
- Add _capnp for original Cython module. Meant for testing.
- Lowercase schema so it conforms to member naming conventions
- Expose _StructSchema's raw node
- Add some useful _StructSchema, reader, and builder methods
- Add full orphan functionality. Also, allow special orphan lists
- Finish up adding docstrings to all public classes/methods


## v0.3.7 (2013-08-26)
- Add a ton of docstrings and add to official docs
- Add DynamicOrphan


## v0.3.6 (2013-08-26)
- Add intersphinx for linking to python docs
- Add C++ library version check


## v0.3.5 (2013-08-25)
- Add handling of constants in schemas
- Fix new error with DynamicValue.Builder no longer being copyable


## v0.3.4 (2013-08-22)
- Fix Void namespace change
- Updated capnp schema to conform with new union rules


## v0.3.3 (2013-08-22)
- Fix for the removal of DynamicUnion from the C++ API


## v0.3.2 (2013-08-21)
- Add MANIFEST.in to include README


## v0.3.1 (2013-08-21)
- Update docs with lines about upgrading setuptools


## 0.3.0 (2013-08-21)
- Initial commit of docs
- Add querying unnamed enums to structs


## 0.2.1 (2013-08-13)
- Fix enum interface change for benchmark
- Random formatting cleanup
- Allow import paths in the schema loader
- Add travis CI


## 0.2.0 (2013-08-12)
- Initial working version
