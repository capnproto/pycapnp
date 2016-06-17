@0x84249be5c3bff005;

interface Foo {
  foo @0 () -> (val :UInt32);
}

struct Bar {
  foo @0 :Foo;
}

interface Baz {
  grault @0 () -> (bar: Bar);
}
