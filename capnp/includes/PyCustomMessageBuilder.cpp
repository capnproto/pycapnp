#include "PyCustomMessageBuilder.h"
#include <stdexcept>

namespace capnp {

PyCustomMessageBuilder::PyCustomMessageBuilder(
    PyObject* allocateSegmentCallable, uint firstSegmentWords)
    : allocateSegmentCallable(allocateSegmentCallable), firstSize(firstSegmentWords)
{
  KJ_REQUIRE(PyCallable_Check(allocateSegmentCallable),
               "allocateSegmentCallable must be callable");
  Py_INCREF(allocateSegmentCallable);
}

PyCustomMessageBuilder::~PyCustomMessageBuilder() noexcept(false) {
  PyGILState_STATE gstate = PyGILState_Ensure();

  for (auto* obj : allocatedBuffers) {
    Py_DECREF(obj);
  }
  allocatedBuffers.clear();

  Py_DECREF(allocateSegmentCallable);
  PyGILState_Release(gstate);
}

kj::ArrayPtr<capnp::word> PyCustomMessageBuilder::allocateSegment(capnp::uint minimumSize) {
  PyGILState_STATE gstate = PyGILState_Ensure();
  KJ_DEFER({ PyGILState_Release(gstate); });
  if (curSize == 0) {
    minimumSize = kj::max(minimumSize, firstSize);
  }
  PyObject* pyBufObj = PyObject_CallFunction(allocateSegmentCallable, "I", minimumSize);
  KJ_REQUIRE(pyBufObj, "PyCustomMessageBuilder: allocateSegment failed");
  allocatedBuffers.push_back(pyBufObj);


  Py_buffer view;
  int bufRes = PyObject_GetBuffer(pyBufObj, &view, PyBUF_SIMPLE);
  KJ_REQUIRE(bufRes == 0, "PyCustomMessageBuilder: object does not support buffer protocol");
  KJ_DEFER({ PyBuffer_Release(&view); });

  size_t byteCount = view.len;
  size_t wordCount = byteCount / sizeof(capnp::word);
  KJ_REQUIRE(wordCount >= minimumSize, "PyCustomMessageBuilder: buffer too small for minimumSize");
  curSize += wordCount;
  return kj::arrayPtr(reinterpret_cast<capnp::word*>(view.buf), wordCount);
}

}