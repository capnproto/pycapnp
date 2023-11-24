@0x95c41c96183b9c2f;

using import "/schemas/child.capnp".Child;

struct Parent {
  child @0 :List(Child);
}
