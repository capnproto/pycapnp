#pragma once

#include "kj/async.h"
#include "capabilityHelper.h"

void waitNeverDone(kj::WaitScope & scope) {
  kj::NEVER_DONE.wait(scope);
}

capnp::Response< ::capnp::DynamicStruct> * waitRemote(kj::Own<capnp::RemotePromise<::capnp::DynamicStruct>> promise,
                                                      kj::WaitScope & scope) {
  return new capnp::Response< ::capnp::DynamicStruct>(promise->wait(scope));
}
