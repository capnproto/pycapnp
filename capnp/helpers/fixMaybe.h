#include "kj/common.h"
#include <stdexcept>

template<typename T>
T fixMaybe(::kj::Maybe<T> val) {
  KJ_IF_MAYBE(new_val, val) {
    return *new_val;
  } else {
    throw std::invalid_argument("member was null");
  }
}

template<typename T>
const char * getEnumString(T & val) {

  auto maybe_val = val.which();
  KJ_IF_MAYBE(new_val, maybe_val) {
    return new_val->getProto().getName().cStr();;
  } else {
    return "";
  }
}