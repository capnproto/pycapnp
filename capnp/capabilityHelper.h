#include "capnp/dynamic.h"
#include <stdexcept>
#include "Python.h"
#include <iostream>

extern "C" {
   PyObject * wrap_dynamic_struct_reader(capnp::DynamicStruct::Reader &);
   void call_server_method(PyObject * py_server, char * name, capnp::CallContext< capnp::DynamicStruct, capnp::DynamicStruct> & context);
 }

class PythonInterfaceDynamicImpl final: public capnp::DynamicCapability::Server {
public:
  PyObject * py_server;

  PythonInterfaceDynamicImpl(capnp::InterfaceSchema & schema, PyObject * py_server)
      : capnp::DynamicCapability::Server(schema), py_server(py_server) {}

  kj::Promise<void> call(capnp::InterfaceSchema::Method method,
                         capnp::CallContext< capnp::DynamicStruct, capnp::DynamicStruct> context) {
    auto methodName = method.getProto().getName();
    call_server_method(py_server, const_cast<char *>(methodName.cStr()), context);
    return kj::READY_NOW;
  }
};

capnp::DynamicCapability::Client new_client(capnp::InterfaceSchema & schema, PyObject * server, kj::EventLoop & loop) {
  return capnp::DynamicCapability::Client(kj::heap<PythonInterfaceDynamicImpl>(schema, server), loop);
}

::kj::Promise<PyObject *> convert_to_pypromise(capnp::RemotePromise<capnp::DynamicStruct> & promise) {
    return promise.then([](capnp::Response<capnp::DynamicStruct>&& response) { return wrap_dynamic_struct_reader(response); } );
}