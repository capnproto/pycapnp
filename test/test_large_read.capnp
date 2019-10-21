@0x86dbb3b256f5d2af;

struct Row {
  values @0 :List(Int32);
}

struct MultiArray {
  rows @0 :List(Row);
}

struct Msg {
  data @0 :List(UInt8);
}
