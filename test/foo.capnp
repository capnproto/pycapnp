@0x84ed73ce30ad1d3f;

struct Foo {
  id @0 :UInt32;
  name @1 :Text;
}


struct Baz{
    text @0 :Text;
    qux @1 :Qux;
}

struct Qux{
    id @0 :UInt64;
}

interface Wrapper  {
    wrapped @0 (object :AnyPointer);
}
