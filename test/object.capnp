@0x8186ddb142b58556;

struct Person {
  id @0 :UInt32;
  name @1 :Text;
}

struct Place {
  id @0 :UInt32;
  name @1 :Text;
}

struct Thing {
  id @0 :UInt64;
  value @1 :UInt64;
}

struct TestObject {
  object @0 :Object;
}

