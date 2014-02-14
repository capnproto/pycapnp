#include "kj/common.h"
#include <stdexcept>

template<typename T>
T fixMaybe(::kj::Maybe<T> val) {
  KJ_IF_MAYBE(new_val, val) {
    return *new_val;
  } else {
    throw std::invalid_argument("Member was null.");
  }
}
