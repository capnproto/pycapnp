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

::kj::Promise<kj::Own<PyRefCounter>> convert_to_pypromise(kj::Own<capnp::RemotePromise<capnp::DynamicStruct>> promise);

inline ::kj::Promise<kj::Own<PyRefCounter>> convert_to_pypromise(kj::Own<kj::Promise<void>> promise) {
    return promise->then([]() {
      GILAcquire gil;
      return kj::heap<PyRefCounter>(Py_None);
    });
}

template<class T>
::kj::Promise<void> convert_to_voidpromise(kj::Own<kj::Promise<T>> promise) {
    return promise->then([](T) { } );
}

void reraise_kj_exception();

void check_py_error();

inline kj::Promise<kj::Own<PyRefCounter>> wrapSizePromise(kj::Promise<size_t> promise) {
  return promise.then([](size_t response) { return stealPyRef(PyLong_FromSize_t(response)); } );
}

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Own<kj::Promise<kj::Own<PyRefCounter>>> promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func);
::kj::Promise<kj::Own<PyRefCounter>> then(kj::Own<::capnp::RemotePromise< ::capnp::DynamicStruct>> promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func);

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Own<kj::Promise<void>> promise,
                                          kj::Own<PyRefCounter>func, kj::Own<PyRefCounter> error_func);

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Promise<kj::Array<kj::Own<PyRefCounter>> > && promise);

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

inline capnp::DynamicCapability::Client new_client(capnp::InterfaceSchema & schema, PyObject * server) {
  return capnp::DynamicCapability::Client(kj::heap<PythonInterfaceDynamicImpl>(schema, server));
}
inline capnp::DynamicValue::Reader new_server(capnp::InterfaceSchema & schema, PyObject * server) {
  return capnp::DynamicValue::Reader(kj::heap<PythonInterfaceDynamicImpl>(schema, server));
}

inline capnp::Capability::Client server_to_client(capnp::InterfaceSchema & schema, PyObject * server) {
  return kj::heap<PythonInterfaceDynamicImpl>(schema, server);
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
