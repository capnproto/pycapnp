#pragma once

#include "Python.h"
#include <capnp/message.h>
#include <capnp/serialize.h>
#include <vector>

namespace capnp {

class PyCustomMessageBuilder : public capnp::MessageBuilder {
public:
  explicit PyCustomMessageBuilder(PyObject* allocateSegmentCallable,
  uint firstSegmentWords = capnp::SUGGESTED_FIRST_SEGMENT_WORDS);

  ~PyCustomMessageBuilder() noexcept(false) override;

  kj::ArrayPtr<capnp::word> allocateSegment(capnp::uint minimumSize) override;

private:
  PyObject* allocateSegmentCallable;

  uint firstSize;
  uint curSize = 0;

  std::vector<PyObject*> allocatedBuffers;
};

}
