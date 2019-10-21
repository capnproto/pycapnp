# Copyright (c) 2013, Kenton Varda <temporal@gmail.com>
# All rights reserved.
#
# Redistribution and use in source and binary forms, with or without
# modification, are permitted provided that the following conditions are met:
#
# 1. Redistributions of source code must retain the above copyright notice, this
#    list of conditions and the following disclaimer.
# 2. Redistributions in binary form must reproduce the above copyright notice,
#    this list of conditions and the following disclaimer in the documentation
#    and/or other materials provided with the distribution.
#
# THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND
# ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED
# WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
# DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR
# ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES
# (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES;
# LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND
# ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
# (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
# SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

@0xd508eefec2dc42b8;

interface TestInterface {
  foo @0 (i :UInt32, j :Bool) -> (x: Text);
  bar @1 () -> ();
  buz @2 (i: TestSturdyRefHostId) -> (x: Text);
  bam @3 (i :UInt32, j :Bool) -> (x: Text, i:UInt32);
  # baz @2 (s: TestAllTypes);
}

interface TestExtends extends(TestInterface) {
  qux @0 ();
}

interface TestPipeline {
  getCap @0 (n: UInt32, inCap :TestInterface) -> (s: Text, outBox :Box);
  testPointers @1 (cap :TestInterface, obj :AnyPointer, list :List(TestInterface)) -> ();

  struct Box {
    cap @0 :TestInterface;
  }
}

struct TestSturdyRefHostId {
  host @0 :Text;
}

struct TestSturdyRefObjectId {
  tag @0 :Tag;
  enum Tag {
    testInterface @0;
    testExtends @1;
    testPipeline @2;
  }
}

interface TestCallOrder {
  getCallSequence @0 (expected: UInt32) -> (n: UInt32);
  # First call returns 0, next returns 1, ...
  #
  # The input `expected` is ignored but useful for disambiguating debug logs.
}

interface TestTailCallee {
  struct TailResult {
    i @0 :UInt32;
    t @1 :Text;
    c @2 :TestCallOrder;
  }

  foo @0 (i :Int32, t :Text) -> TailResult;
}

interface TestTailCaller {
  foo @0 (i :Int32, callee :TestTailCallee) -> TestTailCallee.TailResult;
}

interface TestPassedCap {
  foo @0 (cap :TestInterface) -> (x: Text);
}

interface TestStructArg {
  bar @0 BarParams -> (c: Text);
}
struct BarParams {
  a @0 :Text;
  b @1 :Int32;
}

interface TestGeneric(MyObject)  {
  foo @0 (a :MyObject) -> (b: Text);
}
