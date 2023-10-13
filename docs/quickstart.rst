.. _quickstart:

Quickstart
==========

This assumes you already have the capnp library installed. If you don't, please follow the instructions at :ref:`Installation <install>` first.

In general, this library is a very light wrapping of the `Cap'n Proto C++ library <https://capnproto.org/cxx.html>`_. You can refer to its docs for more advanced concepts, or just to get a basic idea of how the python library is structured.


Load a Cap'n Proto Schema
-------------------------
First you need to import the library::

    import capnp

Then you can load the Cap'n Proto schema with::

    import addressbook_capnp

This will look all through all the directories in your sys.path/PYTHONPATH, and try to find a file of the form 'addressbook.capnp'. If you want to disable the import hook magic that `import capnp` adds, and load manually, here's how::

    capnp.remove_import_hook()
    addressbook_capnp = capnp.load('addressbook.capnp')

For future reference, here is the Cap'n Proto schema. Also available in the github repository under `examples/addressbook.capnp <https://github.com/capnproto/pycapnp/tree/master/examples>`_::

    # addressbook.capnp
    @0x934efea7f017fff0;

    const qux :UInt32 = 123;

    struct Person {
      id @0 :UInt32;
      name @1 :Text;
      email @2 :Text;
      phones @3 :List(PhoneNumber);

      struct PhoneNumber {
        number @0 :Text;
        type @1 :Type;

        enum Type {
          mobile @0;
          home @1;
          work @2;
        }
      }

      employment :union {
        unemployed @4 :Void;
        employer @5 :Text;
        school @6 :Text;
        selfEmployed @7 :Void;
        # We assume that a person is only one of these.
      }
    }

    struct AddressBook {
      people @0 :List(Person);
    }


Const values
~~~~~~~~~~~~
Const values show up just as you'd expect under the loaded schema. For example::

    print(addressbook_capnp.qux)
    # 123


Build a message
---------------

Initialize a New Cap'n Proto Object
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now that you've imported your schema, you need to allocate an actual struct from that schema. In this case, we will allocate an `AddressBook`::

    addresses = addressbook_capnp.AddressBook.new_message()

Notice that we used `addressbook_capnp` from the previous section: `Load a Cap'n Proto Schema`_.

Also as a shortcut, you can pass keyword arguments to the `new_message` function, and those fields will be set in the new message::

    person = addressbook_capnp.Person.new_message(name='alice')
    # is equivalent to:
    person = addressbook_capnp.Person.new_message()
    person.name = 'alice'


List
~~~~
Allocating a list inside of an object requires use of the `init` function::

    people = addresses.init('people', 2)

For now, let's grab the first element out of this list and assign it to a variable named `alice`::

    alice = people[0]

.. note:: It is a very bad idea to call `init` more than once on a single field. Every call to `init` allocates new memory inside your Cap'n Proto message, and if you call it more than once, the previous memory is left as dead space in the message. See `Tips and Best Practices <https://capnproto.org/cxx.html#tips-and-best-practices>`_ for more details.


Primitive Types
~~~~~~~~~~~~~~~
For all primitive types, from the Cap'n Proto docs:

- Boolean: Bool
- Integers: Int8, Int16, Int32, Int64
- Unsigned integers: UInt8, UInt16, UInt32, UInt64
- Floating-point: Float32, Float64
- Blobs: Text, Data

You can assign straight to the variable with the corresponding Python type. For Blobs, you use strings. Assignment happens just by using the `.` syntax on the object you contstructed above::

    alice.id = 123
    alice.name = 'Alice'
    alice.email = 'alice@example.com'

.. note:: Text fields will behave differently depending on your version of Python. In Python 2.x, Text fields will expect and return a `bytes` string, while in Python 3.x, they will expect and return a `unicode` string. Data fields will always a return `bytes` string.


Enums
~~~~~
First we'll allocate a length one list of phonenumbers for `alice`::

    alicePhone = alice.init('phones', 1)[0]

Note that even though it was a length 1 list, it was still a list that was returned, and we extracted the first (and only) element with `[0]`.

Enums are treated like strings, and you assign to them like they were a Text field::

    alicePhone.type = 'mobile'

If you assign an invalid value to one, you will get a ValueError::

    alicePhone.type = 'foo'
    ---------------------------------------------------------------------------
    KjException                                Traceback (most recent call last)
    ...
    AttributeError: capnp/schema.c++:566: failed: enum has no such enumerant; name = foo


Unions
~~~~~~
For the most part, you just treat them like structs::

    alice.employment.school = "MIT"

Now the `school` field is the active part of the union, and we've assigned `'MIT'` to it. You can query which field is set in a union with `which()`, shown in `Reading Unions`_

Also, one weird case is for Void types in Unions (and in general, but Void is really only used in Unions). For these, you will have to assign `None` to them::

    bob.employment.unemployed = None

.. note:: One caveat for unions is having structs as union members. Let us assume `employment.school` was actually a struct with a field of type `Text` called `name`::

        alice.employment.school.name = "MIT"
        # Raises a KjException

    The problem is that a struct within a union isn't initialized automatically. You have to do the following::

        TODO Broken
        school = alice.employment.init('school')
        school.name = "MIT"

    Note that this is similar to `init` for lists, but you don't pass a size. Requiring the `init` makes it more clear that a memory allocation is occurring, and will hopefully make you mindful that you shouldn't set more than 1 field inside of a union, else you risk a memory leak


Writing to a File
~~~~~~~~~~~~~~~~~
Once you're done assigning to all the fields in a message, you can write it to a file like so::

    with open('example.bin', 'wb') as f:
        addresses.write(f)

There is also a `write_packed` function, that writes out the message more space-efficientally. If you use write_packed, make sure to use read_packed when reading the message.

Writing to a socket
~~~~~~~~~~~~~~~~~~~
Alternatively, you can write to a socket. This is useful if you want to send the message over the network or to another process.
A full example of this is available on GitHub `examples/async_socket_message_client.py <https://github.com/capnproto/pycapnp/blob/master/examples/async_socket_message_client.py>`_.

.. important:: Writing to a socket is implemented using asyncio and requires a running event loop both for the python part (asyncio) and the C++ part (KJ). See :ref:`RPC <kj-event-loop>` for more information.
::

    stream = await capnp.AsyncIoStream.create_connection(host="localhost", port=6000)
    await addresses.write_async(stream)

Read a message
--------------

Reading from a file
~~~~~~~~~~~~~~~~~~~
Much like before, you will have to de-serialize the message from a file descriptor::

    with open('example.bin', 'rb') as f:
        addresses = addressbook_capnp.AddressBook.read(f)

Note that this very much needs to match the type you wrote out. In general, you will always be sending the same message types out over a given channel or you should wrap all your types in an unnamed union. Unnamed unions are defined in the .capnp file like so::

    struct Message {
        union {
          person @0 :Person;
          addressbook @1 :AddressBook;
        }
    }

Reading from a socket
~~~~~~~~~~~~~~~~~~~~~

The same as for writing, you can read from a socket. This is useful if you want to receive the message over the network or from another process.
A full example of this is available on GitHub `examples/async_socket_message_client.py <https://github.com/capnproto/pycapnp/blob/master/examples/async_socket_message_client.py>`_.

.. important:: Reading from a socket is implemented using asyncio and requires a running event loop both for the python part (asyncio) and the C++ part (KJ). See :ref:`RPC <kj-event-loop>` for more information.
::

    stream = await capnp.AsyncIoStream.create_connection(host="localhost", port=6000)
    message = await addressbook_capnp.AddressBook.read_async(stream)


Reading Fields
~~~~~~~~~~~~~~
Fields are very easy to read. You just use the `.` syntax as before. Lists behave just like normal Python lists::

    for person in addresses.people:
        print(person.name, ':', person.email)
        for phone in person.phones:
            print(phone.type, ':', phone.number)


Reading Unions
~~~~~~~~~~~~~~
The only tricky one is unions, where you need to call `.which()` to determine the union type. The `.which()` call returns an enum, ie. a string, corresponding to the field name::

        which = person.employment.which()
        print(which)

        if which == 'unemployed':
            print('unemployed')
        elif which == 'employer':
            print('employer:', person.employment.employer)
        elif which == 'school':
            print('student at:', person.employment.school)
        elif which == 'selfEmployed':
            print('self employed')
        print()


Serializing/Deserializing
-------------------------

Files
~~~~~
As shown in the examples above, there is file serialization with `write()`::

    addresses = addressbook_capnp.AddressBook.new_message()
    ...
    with open('example.bin', 'wb') as f:
        addresses.write(f)

And similarly for reading::

    with open('example.bin', 'rb') as f:
        addresses = addressbook_capnp.AddressBook.read(f)

There are packed versions as well::

    with open('example.bin', 'wb') as f:
        addresses.write_packed(f)
    ...
    with open('example.bin', 'rb') as f:
        addresses = addressbook_capnp.AddressBook.read_packed(f)


Multi-message files
~~~~~~~~~~~~~~~~~~~
The above methods only guaranteed to work if your file contains a single message. If you have more than 1 message serialized sequentially in your file, then you need to use these convenience functions::

    addresses = addressbook_capnp.AddressBook.new_message()
    ...
    with open('example.bin', 'wb') as f:
        addresses.write(f)
        addresses.write(f)
        addresses.write(f) # write 3 messages
    
    with open('example.bin', 'rb') as f:
        for addresses in addressbook_capnp.AddressBook.read_multiple(f):
            print(addresses)

There is also a packed version::

    for addresses in addressbook_capnp.AddressBook.read_multiple_packed(f):
        print addresses

Dictionaries
~~~~~~~~~~~~
There is a convenience method for converting Cap'n Proto messages to a dictionary. This works for both Builder and Reader type messages::

    alice.to_dict()

For the reverse, all you have to do is pass keyword arguments to the new_message constructor::

    my_dict = {'name' : 'alice'}
    alice = addressbook_capnp.Person.new_message(**my_dict)
    # equivalent to: alice = addressbook_capnp.Person.new_message(name='alice')

It's also worth noting, you can use python lists/dictionaries interchangably with their Cap'n Proto equivalent types::

    book = addressbook_capnp.AddressBook.new_message(people=[{'name': 'Alice'}])
    ...
    book = addressbook_capnp.AddressBook.new_message()
    book.init('people', 1)
    book.people[0] = {'name': 'Bob'}


Byte Strings/Buffers
~~~~~~~~~~~~~~~~~~~~
There is serialization to a byte string available::

    encoded_message = alice.to_bytes()

And a corresponding from_bytes function::

    with addressbook_capnp.Person.from_bytes(encoded_message) as alice:
        # something with alice

There are also packed versions::

    alice2 = addressbook_capnp.Person.from_bytes_packed(alice.to_bytes_packed())


Byte Segments
~~~~~~~~~~~~~
.. note:: This feature is not supported in PyPy at the moment, pending investigation.

Cap'n Proto supports a serialization mode which minimizes object copies. In the C++ interface, ``capnp::MessageBuilder::getSegmentsForOutput()`` returns an array of pointers to segments of the message's content without copying. ``capnp::SegmentArrayMessageReader`` performs the reverse operation, i.e., takes an array of pointers to segments and uses the underlying data, again without copying. This produces a different wire serialization format from ``to_bytes()`` serialization, which uses ``capnp::messageToFlatArray()`` and ``capnp::FlatArrayMessageReader`` (both of which use segments internally, but write them in an incompatible way).

For compatibility on the Python side, use the ``to_segments()`` and ``from_segments()`` functions::

    segments = alice.to_segments()

This returns a list of segments, each a byte buffer. Each segment can be, e.g., turned into a ZeroMQ message frame. The list of segments can also be turned back into an object::

    alice = addressbook_capnp.Person.from_segments(segments)

For more information, please refer to the following links:

- `Advice on minimizing copies from Cap'n Proto <https://stackoverflow.com/questions/28149139/serializing-mutable-state-and-sending-it-asynchronously-over-the-network-with-ne/28156323#28156323>`_ (from the author of Cap'n Proto)
- `Advice on using Cap'n Proto over ZeroMQ <https://stackoverflow.com/questions/32041315/how-to-send-capn-proto-message-over-zmq/32042234#32042234>`_ (from the author of Cap'n Proto)
- `Discussion about sending and reassembling Cap'n Proto message segments in C++ <https://groups.google.com/forum/#!topic/capnproto/ClDjGbO7egA>`_ (from the Cap'n Proto mailing list; includes sample code)


RPC
---

Cap'n Proto has a rich RPC protocol. You should read the `RPC specification <https://capnproto.org/rpc.html>`_ as well as the `C++ RPC documentation <http://kentonv.github.io/capnproto/cxxrpc.html>`_ before using pycapnp's RPC features. As with the serialization part of this library, the RPC component tries to be a very thin wrapper on top of the C++ API.

The examples below will be using `calculator.capnp <https://github.com/capnproto/pycapnp/blob/master/examples/calculator.capnp>`_. Please refer to it to understand the interfaces that will be used.

Asyncio support was added to pycapnp in v1.0.0. Since v2.0.0, the usage of asyncio is mandatory for all RPC calls. This guarantees a more robust and flexible RPC implementation.

KJ Event Loop
~~~~~~~~~~~~~

.. _kj-event-loop:

Cap'n Proto uses the KJ event loop for its RPC implementation. Pycapnp handles all the required mapping between the asyncio event loop and the KJ event loop.
To ensure proper creation, usage, and cleanup of the KJ event loop, a context manager called :py:meth:`capnp.kj_loop` is exposed by pycapnp . All RPC calls must be made within this context::

    import capnp
    import asyncio

    async def main():
        async with capnp.kj_loop():
            # RPC calls here
    
    asyncio.run(main())

To simplify the usage, the helper function:py:meth:`capnp.run` can execute a asyncio coroutine within the :py:meth:`capnp.kj_loop` context manager::

    import capnp
    import asyncio

    async def main():
        # RPC calls here

    asyncio.run(capnp.run(main()))

Client
~~~~~~

.. _rpc-asyncio-client:

Thanks to the integration into the asyncio library, most of the boiler plate code is handled by pycapnp directly. The only thing that needs to be done is to create a client object and bootstrap the server capability.

Starting a Client 
#################

The first step is to open a socket to the server. For now this needs to be done 
through :py:meth:`~._AsyncIoStream.create_connection`. A thin wrapper around :py:meth:`asyncio.get_running_loop().create_connection()`
that adds all required Protocol handling::

    async def main():
        host = 'localhost'
        port = '6000'
        connection = await capnp.AsyncIoStream.create_connection(host=host, port=port)
    
    asyncio.run(capnp.run(main()))

.. note:: :py:meth:`~._AsyncIoStream.create_connection` forwards all calls to the underlying asyncio create_connection function.

In the next step, this created connection can be passed to :py:meth:`capnp.TwoPartyClient` to create the client object::

    async def main():
        host = 'localhost'
        port = '6000'
        connection = await capnp.AsyncIoStream.create_connection(host=host, port=port)
        client = capnp.TwoPartyClient(connection)
        ## Bootstrap Here ##

    asyncio.run(capnp.run(main()))


SSL/TLS Client
^^^^^^^^^^^^^^
SSL/TLS setup effectively wraps the socket transport. You'll need an SSL certificate, for this example, we'll use a self-signed certificate. Since we wrap around the asyncio connection interface, the SSL/TLS setup is done through the :py:obj:`ssl`` parameter of :py:meth:`~._AsyncIoStream.create_connection`::

    async def main():
        host = 'localhost'
        port = '6000'
        # Setup SSL context
        ctx = ssl.create_default_context(ssl.Purpose.SERVER_AUTH, cafile=os.path.join(this_dir, "selfsigned.cert"))

        connection = await capnp.AsyncIoStream.create_connection(host=host, port=port, ssl=ctx, family=socket.AF_INET)
        client = capnp.TwoPartyClient(connection)
        ## Bootstrap Here ##

    asyncio.run(capnp.run(main()))


Due to a `bug <https://bugs.python.org/issue36709>`_ in Python 3.8 asyncio client needs to be initialized in a slightly different way::

    if __name__ == '__main__':
        loop = asyncio.get_event_loop()
        loop.run_until_complete(capnp.run(main(parse_args().host)))


Bootstrap
#########
Before calling any methods you'll need to bootstrap the Calculator interface::

    calculator = client.bootstrap().cast_as(calculator_capnp.Calculator)

There's two things worth noting here. First, we are asking for the server capability. Secondly, you see that we are casting the capability that we receive. This is because capabilities are intrinsically dynamic, and they hold no run time type information, so we need to pick what interface to interpret them as.


Calling methods
###############
There are 2 ways to call RPC methods. First the more verbose `request` syntax::

    request = calculator.evaluate_request()
    request.expression.literal = 123
    eval_promise = request.send()

This creates a request for the method named 'evaluate', sets `expression.literal` in that call's parameters to 123, and then sends the request and returns a promise (all non-blocking).

The shorter syntax for calling methods is::

    eval_promise = calculator.evaluate({"literal": 123})

The major shortcoming with this method is that expressing complex fields with many nested sub-structs can become very tedious.

The returned promise can be handled like any other asyncio promise::

    result = await eval_promise()


Pipelining
##########
If a method returns values that are themselves capabilites, then you can access these fields before awaiting the promise. Doing this is called pipelining, and it allows Cap'n Proto to chain the calls without a round-trip occurring to the server::

    # evaluate returns `value` which is itself an interface.
    # You can call a new method on `value` without having to call wait first
    read_promise = eval_promise.value.read()
    read_result = await read_promise # only 1 await call

Server
~~~~~~

Starting a Server
###########################

Like the client, the server uses an asyncio server that can be created with :py:meth:`~._AsyncIoStream.create_server`.

.. note:: :py:meth:`~._AsyncIoStream.create_server`, similar to :py:meth:`~._AsyncIoStream.create_connection`, forwards all arguments to the underlying asyncio create_connection function (with the exception of the first argument).

The first argument to :py:meth:`~._AsyncIoStream.create_server` must be a callback
used by the pycapnp protocol implementation. The :py:obj:`callback` parameter will be called
whenever a new connection is made. It receives a py:obj:`AsyncIoStream` instance as its
only argument. If the result of py:obj:`callback` is a coroutine, it will be scheduled as a
task. At minimum, the callback should create a :py:class:`capnp.TwoPartyServer` for the 
passed stream. :py:class:`capnp.TwoPartyServer` also exposes a
:py:meth:`~.TwoPartyServer.on_disconnect()` function, which can be used as a task to handle
the lifetime properly::

    async def new_connection(stream):
        await capnp.TwoPartyServer(stream, bootstrap=CalculatorImpl()).on_disconnect()

    async def main():
        host = 'localhost'
        port = '6000'
        server = await capnp.AsyncIoStream.create_server(new_connection, host, port)
        async with server:
            await server.serve_forever()

    if __name__ == "__main__":
        asyncio.run(capnp.run(main()))

.. note:: On systems that have both IPv4 and IPv6 addresses, IPv6 is often resolved first and needs to be handled separately. If you're certain IPv6 won't be used, you can remove it (you should also avoid localhost, and stick to something like 127.0.0.1). If you're broadcasting in general, you'll probably want to use `0.0.0.0` (IPv4) or `::/0` (IPv6).


SSL/TLS Server
^^^^^^^^^^^^^^
Adding SSL/TLS support for a pycapnp asyncio server is fairly straight-forward. Just create an SSL context before starting the asyncio server::

    async def new_connection(stream):
        await capnp.TwoPartyServer(stream, bootstrap=CalculatorImpl()).on_disconnect()

    async def main():
        host = 'localhost'
        port = '6000'

        # Setup SSL context
        ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
        ctx.load_cert_chain(
            os.path.join(this_dir, "selfsigned.cert"),
            os.path.join(this_dir, "selfsigned.key"),
        )

        server = await capnp.AsyncIoStream.create_server(
            new_connection, host, port, ssl=ctx, family=socket.AF_INET
        )
        async with server:
            await server.serve_forever()

    if __name__ == "__main__":
        asyncio.run(capnp.run(main()))


Implementing a Server
#####################
Here's a part of how you would implement a Calculator server::

    class CalculatorImpl(calculator_capnp.Calculator.Server):

        "Implementation of the Calculator Cap'n Proto interface."

        def evaluate(self, expression, _context, **kwargs):
            return evaluate_impl(expression).then(lambda value: setattr(_context.results, 'value', ValueImpl(value)))

        def defFunction_context(self, context):
            params = context.params
            context.results.func = FunctionImpl(params.paramCount, params.body)

        def getOperator(self, op, **kwargs):
            return OperatorImpl(op)

Some major things worth noting.

- You must inherit from `your_module_capnp.YourInterface.Server`, but don't worry about calling __super__ in your __init__
- Method names of your class must either match the interface exactly, or have '_context' appended to it
- If your method name is exactly the same as the interface, then you will be passed all the arguments from the interface as keyword arguments, so your argument names must match the interface spec exactly. You will also receive a `_context` parameter which is equivalent to the C++ API's Context. I highly recommend having `**kwargs` as well, so that even if your interface spec is upgraded and arguments were added, your server will still operate fine.
- Returns work with a bit of magic as well. If you return a promise, then it will be handled the same as if you returned a promise from a server method in the C++ API. Otherwise, your return statement will be filled into the results struct following the ordering in your spec, for example::

    # capability.capnp file
    interface TestInterface {
      foo @0 (i :UInt32, j :Bool) -> (x: Text, i:UInt32);
    }

    # python code
    class TestInterface(capability_capnp.TestInterface.Server):
        def foo(self, i, j, **kwargs):
            return str(j), i

- If your method ends in _context, then you will only be passed a context parameter. You will have to access params and set results yourself manually. Returning promises still works as above, but you can't return anything else from a method.


Full Examples
-------------
`Full examples <https://github.com/capnproto/pycapnp/blob/master/examples>`_ are available on github. There is also an example of a very simplistic RPC available in `test_rpc.py <https://github.com/capnproto/pycapnp/blob/master/test/test_rpc.py>`_.
