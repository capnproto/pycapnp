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
    employer @5 :Employer;
    school @6 :Text;
    selfEmployed @7 :Void;
    # We assume that a person is only one of these.
  }
}

struct Employer {
  name @0 :Text;
  boss @1 :Person;
}

struct AddressBook {
  people @0 :List(Person);
}

struct NestedList {
  list @0 :List(List(Int32));
}
