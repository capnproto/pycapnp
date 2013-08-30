@0x84ed73ce30ad1d3e;

using Foo = import "foo.capnp";

struct Bar {
  id @0 :UInt32;
  foo @1 :Foo.Foo;
}
