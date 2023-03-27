#pragma once

#include "kj/async.h"
#include "Python.h"
#include "capabilityHelper.h"

void waitNeverDone(kj::WaitScope & scope) {
  GILRelease gil;
  kj::NEVER_DONE.wait(scope);
}

void pollWaitScope(kj::WaitScope & scope) {
  GILRelease gil;
  scope.poll();
}

kj::Timer * getTimer(kj::LowLevelAsyncIoProvider * provider) {
  return &provider->getTimer();
}

void waitVoidPromise(kj::Promise<void> * promise, kj::WaitScope & scope) {
  GILRelease gil;
  promise->wait(scope);
}

PyObject * waitPyPromise(kj::Promise<PyObject *> * promise, kj::WaitScope & scope) {
  GILRelease gil;
  return promise->wait(scope);
}

capnp::Response< ::capnp::DynamicStruct> * waitRemote(capnp::RemotePromise< ::capnp::DynamicStruct> * promise, kj::WaitScope & scope) {
  GILRelease gil;
  return new capnp::Response< ::capnp::DynamicStruct>(promise->wait(scope));
}

bool pollRemote(capnp::RemotePromise< ::capnp::DynamicStruct> * promise, kj::WaitScope & scope) {
  GILRelease gil;
  return promise->poll(scope);
}
