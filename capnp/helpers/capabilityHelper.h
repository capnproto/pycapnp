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

void c_reraise_kj_exception();

void check_py_error();

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Promise<kj::Own<PyRefCounter>> promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func);

class PythonInterfaceDynamicImpl final: public capnp::DynamicCapability::Server {
public:
  kj::Own<PyRefCounter> py_server;
  kj::Own<PyRefCounter> kj_loop;

#if (CAPNP_VERSION_MAJOR < 1)
  PythonInterfaceDynamicImpl(capnp::InterfaceSchema & schema,
                             kj::Own<PyRefCounter> _py_server,
                             kj::Own<PyRefCounter> kj_loop)
    : capnp::DynamicCapability::Server(schema),
      py_server(kj::mv(_py_server)), kj_loop(kj::mv(kj_loop)) { }
#else
  PythonInterfaceDynamicImpl(capnp::InterfaceSchema & schema,
                             kj::Own<PyRefCounter> _py_server,
                             kj::Own<PyRefCounter> kj_loop)
    : capnp::DynamicCapability::Server(schema, { true }),
      py_server(kj::mv(_py_server)), kj_loop(kj::mv(kj_loop)) { }
#endif

  ~PythonInterfaceDynamicImpl() {
  }

  kj::Promise<void> call(capnp::InterfaceSchema::Method method,
                         capnp::CallContext< capnp::DynamicStruct, capnp::DynamicStruct> context);
};

inline void allowCancellation(capnp::CallContext<capnp::DynamicStruct, capnp::DynamicStruct> context) {
#if (CAPNP_VERSION_MAJOR < 1)
  context.allowCancellation();
#endif
}

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
