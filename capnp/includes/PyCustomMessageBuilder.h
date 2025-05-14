#pragma once

#include "Python.h"
#include <capnp/message.h>
#include <capnp/serialize.h>
#include <vector>

namespace capnp {

class PyCustomMessageBuilder : public capnp::MessageBuilder {
public:
  explicit PyCustomMessageBuilder(PyObject* allocateSegmentFunc);

  ~PyCustomMessageBuilder() noexcept(false) override;

  kj::ArrayPtr<capnp::word> allocateSegment(capnp::uint minimumSize) override;

private:
  uint curSize;

  PyObject* allocateSegmentFunc;
  std::vector<PyObject*> allocatedBuffers;
};

}
