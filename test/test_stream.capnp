@0xc3a5e2b7d9f14068;

interface StreamSink {
  write @0 (seq :UInt32, data :Data) -> stream;
  done @1 () -> (count :UInt32, inOrder :Bool);
}
