#include "PyCustomMessageBuilder.h"
#include <iostream>
#include <stdexcept>

namespace capnp {

PyCustomMessageBuilder::PyCustomMessageBuilder(PyObject* allocateSegmentFunc)
    :capnp::MessageBuilder(),
      allocateSegmentFunc(allocateSegmentFunc)
{
  KJ_REQUIRE(PyCallable_Check(allocateSegmentFunc),
               "allocateSegmentFunc must be callable");
  Py_INCREF(allocateSegmentFunc);
}

PyCustomMessageBuilder::~PyCustomMessageBuilder() noexcept(false) {
  PyGILState_STATE gstate = PyGILState_Ensure();

  for (auto* obj : allocatedBuffers) {
    Py_DECREF(obj);
  }
  allocatedBuffers.clear();

  Py_DECREF(allocateSegmentFunc);
  PyGILState_Release(gstate);
}

kj::ArrayPtr<capnp::word> PyCustomMessageBuilder::allocateSegment(capnp::uint minimumSize) {
  PyGILState_STATE gstate = PyGILState_Ensure();
  KJ_DEFER({ PyGILState_Release(gstate); });

  std::cout << "allocateSegment start test \n";

  PyObject* pyBufObj = PyObject_CallFunction(allocateSegmentFunc, "I", minimumSize);
  KJ_REQUIRE(pyBufObj, "PyCustomMessageBuilder: allocateSegment failed");
  allocatedBuffers.push_back(pyBufObj);


  Py_buffer view;
  int bufRes = PyObject_GetBuffer(pyBufObj, &view, PyBUF_SIMPLE);
  KJ_REQUIRE(bufRes == 0, "PyCustomMessageBuilder: object does not support buffer protocol");
  KJ_DEFER({ PyBuffer_Release(&view); });

  size_t byteCount = view.len;
  size_t wordCount = byteCount / sizeof(capnp::word);
  KJ_REQUIRE(wordCount >= minimumSize, "PyCustomMessageBuilder: buffer too small for minimumSize");

  auto seg = kj::arrayPtr(reinterpret_cast<capnp::word*>(view.buf), wordCount);

  std::cout << "allocateSegment finish test \n";
  return seg;
}

}