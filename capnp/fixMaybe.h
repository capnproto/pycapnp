#include "kj/common.h"
#include <stdexcept>

static_assert(CAPNP_VERSION >= 3000, "Version of Cap'n Proto C++ Library is too old. Please upgrade to a version >= 0.3 and then re-install this python library");

template<typename T>
T fixMaybe(::kj::Maybe<T> val) {
  KJ_IF_MAYBE(new_val, val) {
    return *new_val;
  } else {
    throw std::invalid_argument("member was null");
  }
}

template<typename T>
const char * getEnumString(T val) {

  auto maybe_val = val.which();
  KJ_IF_MAYBE(new_val, maybe_val) {
    return new_val->getProto().getName().cStr();;
  } else {
    return "";
  }
}