.. _quickstart:

Quickstart
===================

This assumes you already have the capnp library installed. If you don't, please follow the instructions at :ref:`Installation <install>` first.

In general, this library is a very light wrapping of the `Cap'n Proto C++ library <http://kentonv.github.io/capnproto/cxx.html>`_. You can refer to its docs for more advanced concepts, or just to get a basic idea of how the python library is structured.

Load a Cap'n Proto Schema
-------------------------

First you need to import the library::
    
    import capnp

Then you can load the Cap'n Proto schema with::

    addressbook = capnp.load('addressbook.capnp')

Note that we assign the loaded module to a variable, named `addressbook`. We'll use this from now on to access the Cap'n Proto schema, ie. when we need to get a Struct's class or accessing const values.

You can also provide an absolute path to the Cap'n Proto schema you wish to load. Otherwise, it will only look in the current working directory.

For future reference, here is the Cap'n Proto schema. Also available in the github repository under examples/addressbook.capnp::

    # addressbook.capnp
    0x934efea7f017fff0;

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

      employment @4 union {
        unemployed @5 :Void;
        employer @6 :Text;
        school @7 :Text;
        selfEmployed @8 :Void;
        # We assume that a person is only one of these.
      }
    }

    struct AddressBook {
      people @0 :List(Person);
    }

Const values
~~~~~~~~~~~~~~

Const values show up just as you'd expect under the loaded schema. For example::
    
    print addressbook.qux
    # 123

Build a message
------------------

Message Builder
~~~~~~~~~~~~~~~~~~~

First you need to allocate a MessageBuilder for your message to go in. There is only 1 message allocator available at the moment (Malloc), although there may be more varied kinds in the future::

    message = capnp.MallocMessageBuilder()

Initialize a New Cap'n Proto Object
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Now that you have a message buffer, you need to allocate an actual object that is from your schema. In this case, we will allocate an `AddressBook`::

    addressBook = message.initRoot(addressbook.AddressBook)

Notice that we used `addressbook` from the previous section: `Load a Cap'n Proto Schema`_.

List
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Allocating a list inside of an object requires use of the `init` function::
    
    people = addressBook.init('people', 2)

For now, let's grab the first element out of this list and assign it to a variable named `alice`::

    alice = people[0]

Primitive Types
~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

Enums
~~~~~~~~~~~~~~

First we'll allocate a length one list of phonenumbers for `alice`::

    alicePhone = alice.init('phones', 1)[0]

Note that even though it was a length 1 list, it was still a list that was returned, and we extracted the first (and only) element with `[0]`.

Now, enums are treated like strings, and you just assign to them like there were a Text field::
    
    alicePhone.type = 'mobile'

If you assign an invalid value to one, you will get a ValueError::

    alicePhone.type = 'foo'
    ---------------------------------------------------------------------------
    ValueError                                Traceback (most recent call last)
    ...
    ValueError: src/capnp/schema.c++:326: requirement not met: enum has no such enumerant; name = foo

Unions
~~~~~~~~~~~~~~~~~~
For the most part, you just treat them like structs::

    alice.employment.school = "MIT"

Now the `school` field is the active part of the union, and we've assigned `'MIT'` to it. You can query which field is set in a union with `which()`, shown in `Reading Unions`_

Also, one weird case is for Void types in Unions (and in general, but Void is really only used in Unions). For these, you will have to assign `None` to them::

    bob.employment.unemployed = None 

Writing to a File
~~~~~~~~~~~~~~~~~~~

For now, the only way to serialize a message is to write it directly to a file descriptor (expect serializing to strings at some point soon)::

    f = open('example.bin', 'w')
    capnp.writePackedMessageToFd(f.fileno(), message)

Note the call to fileno(), since it expects a raw file descriptor. There is also `writeMessageToFd` instead of `writePackedMessageToFd`. Make sure your reader uses the same packing type.

Read a message
-----------------

Reading from a file
~~~~~~~~~~~~~~~~~~~~~~

Much like before, you will have to de-serialize the message from a file descriptor::

    f = open('example.bin')
    message = capnp.PackedFdMessageReader(f.fileno())

Initialize a New Cap'n Proto Object
~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~~

Just like when building, you have to actually specify which message you want to read out of buffer::

    addressBook = message.getRoot(addressbook.AddressBook)

Note that this very much needs to match the type you wrote out. In general, you will always be sending the same message types out over a given channel, wrap all your types in an unnamed enum, or you need some out of band method for communicating what type a message is. Unnamed unions are defined in the .capnp file like so::

    struct Message {
        union {
          person @0 :Person;
          addressbook @1 :AddressBook;
        }
    }

Reading Fields
~~~~~~~~~~~~~~~~~~~~~~~~~~~

Fields are very easy to read. You just use the `.` syntax as before. Lists behave just like normal Python lists::

    for person in addressBook.people:
        print(person.name, ':', person.email)
        for phone in person.phones:
            print(phone.type, ':', phone.number)

Reading Unions
~~~~~~~~~~~~~~~~~~~~~~~~~~~

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

Full Example
------------------

Here is a full example reproduced from `examples/example.py <https://github.com/jparyani/pycapnp/blob/master/examples/example.py>`_::
    
    from __future__ import print_function
    import os
    import capnp

    this_dir = os.path.dirname(__file__)
    addressbook = capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

    def writeAddressBook(fd):
        message = capnp.MallocMessageBuilder()
        addressBook = message.initRoot(addressbook.AddressBook)
        people = addressBook.init('people', 2)

        alice = people[0]
        alice.id = 123
        alice.name = 'Alice'
        alice.email = 'alice@example.com'
        alicePhones = alice.init('phones', 1)
        alicePhones[0].number = "555-1212"
        alicePhones[0].type = 'mobile'
        alice.employment.school = "MIT"

        bob = people[1]
        bob.id = 456
        bob.name = 'Bob'
        bob.email = 'bob@example.com'
        bobPhones = bob.init('phones', 2)
        bobPhones[0].number = "555-4567"
        bobPhones[0].type = 'home'
        bobPhones[1].number = "555-7654"
        bobPhones[1].type = 'work'
        bob.employment.unemployed = None

        capnp.writePackedMessageToFd(fd, message)


    def printAddressBook(fd):
        message = capnp.PackedFdMessageReader(f.fileno())
        addressBook = message.getRoot(addressbook.AddressBook)

        for person in addressBook.people:
            print(person.name, ':', person.email)
            for phone in person.phones:
                print(phone.type, ':', phone.number)

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


    if __name__ == '__main__':
        f = open('example', 'w')
        writeAddressBook(f.fileno())

        f = open('example', 'r')
        printAddressBook(f.fileno())
