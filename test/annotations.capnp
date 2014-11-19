@0xfb9a160831eee9bb;

struct AnnotationStruct {
  test @0: Int32;
}

annotation test1(*): Text;
annotation test2(*): AnnotationStruct;
annotation test3(*): List(AnnotationStruct);

$test1("TestFile");

struct TestAnnotationOne $test1("Test") { }
struct TestAnnotationTwo $test2(test = 100) { }
struct TestAnnotationThree $test3([(test=100), (test=101)]) { }
