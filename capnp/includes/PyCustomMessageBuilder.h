#pragma once

#include "Python.h"
#include <capnp/message.h>
#include <capnp/serialize.h>
#include <vector>

namespace capnp {

class PyCustomMessageBuilder : public capnp::MessageBuilder {
public:
  explicit PyCustomMessageBuilder(PyObject* allocateSegmentFunc,
  uint firstSegmentWords = capnp::SUGGESTED_FIRST_SEGMENT_WORDS);

  ~PyCustomMessageBuilder() noexcept(false) override;

  kj::ArrayPtr<capnp::word> allocateSegment(capnp::uint minimumSize) override;

private:
  PyObject* allocateSegmentFunc;

  uint firstSize;
  uint curSize;

  std::vector<PyObject*> allocatedBuffers;
};

}
