#pragma once

#include "capnp/dynamic.h"
#include <kj/async-io.h>
#include <capnp/serialize-async.h>
#include <stdexcept>
#include "Python.h"

class GILAcquire {
public:
  GILAcquire() : gstate(PyGILState_Ensure()) {}
  ~GILAcquire() {
    PyGILState_Release(gstate);
  }

  PyGILState_STATE gstate;
};

class GILRelease {
public:
  GILRelease() {
    Py_UNBLOCK_THREADS
  }
  ~GILRelease() {
    Py_BLOCK_THREADS
  }

  PyThreadState *_save; // The macros above read/write from this variable
};

class PyRefCounter {
public:
  PyObject * obj;

  PyRefCounter(PyObject * o) : obj(o) {
    GILAcquire gil;
    Py_INCREF(obj);
  }

  PyRefCounter(const PyRefCounter & ref) : obj(ref.obj) {
    GILAcquire gil;
    Py_INCREF(obj);
  }

  ~PyRefCounter() {
    GILAcquire gil;
    Py_DECREF(obj);
  }
};

inline kj::Own<PyRefCounter> stealPyRef(PyObject* o) {
  auto ret = kj::heap<PyRefCounter>(o);
  Py_DECREF(o);
  return ret;
}

::kj::Promise<kj::Own<PyRefCounter>> convert_to_pypromise(capnp::RemotePromise<capnp::DynamicStruct> promise);

inline ::kj::Promise<kj::Own<PyRefCounter>> convert_to_pypromise(kj::Promise<void> promise) {
    return promise.then([]() {
      GILAcquire gil;
      return kj::heap<PyRefCounter>(Py_None);
    });
}

void reraise_kj_exception();

void check_py_error();

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Promise<kj::Own<PyRefCounter>> promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func);

class PythonInterfaceDynamicImpl final: public capnp::DynamicCapability::Server {
public:
  PyObject * py_server;

  PythonInterfaceDynamicImpl(capnp::InterfaceSchema & schema, PyObject * _py_server)
      : capnp::DynamicCapability::Server(schema), py_server(_py_server) {
        GILAcquire gil;
        Py_INCREF(_py_server);
      }

  ~PythonInterfaceDynamicImpl() {
    GILAcquire gil;
    Py_DECREF(py_server);
  }

  kj::Promise<void> call(capnp::InterfaceSchema::Method method,
                         capnp::CallContext< capnp::DynamicStruct, capnp::DynamicStruct> context);
};

class PyAsyncIoStream: public kj::AsyncIoStream {
public:
  kj::Own<PyRefCounter> protocol;

  PyAsyncIoStream(kj::Own<PyRefCounter> protocol) : protocol(kj::mv(protocol)) {}
  ~PyAsyncIoStream();

  kj::Promise<size_t> tryRead(void* buffer, size_t minBytes, size_t maxBytes);

  kj::Promise<void> write(const void* buffer, size_t size);

  kj::Promise<void> write(kj::ArrayPtr<const kj::ArrayPtr<const kj::byte>> pieces);

  kj::Promise<void> whenWriteDisconnected();

  void shutdownWrite();
};

template <typename T>
inline void rejectDisconnected(kj::PromiseFulfiller<T>& fulfiller, kj::StringPtr message) {
  fulfiller.reject(KJ_EXCEPTION(DISCONNECTED, message));
}
inline void rejectVoidDisconnected(kj::PromiseFulfiller<void>& fulfiller, kj::StringPtr message) {
  fulfiller.reject(KJ_EXCEPTION(DISCONNECTED, message));
}

inline kj::Exception makeException(kj::StringPtr message) {
  return KJ_EXCEPTION(FAILED, message);
}

kj::Promise<void> taskToPromise(kj::Own<PyRefCounter> coroutine, PyObject* callback);

::kj::Promise<kj::Own<PyRefCounter>> tryReadMessage(kj::AsyncIoStream& stream, capnp::ReaderOptions opts);

void init_capnp_api();
