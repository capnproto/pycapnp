#pragma once

#include "capnp/dynamic.h"
#include <stdexcept>
#include "Python.h"

extern "C" {
   PyObject * wrap_remote_call(PyObject * func, capnp::Response<capnp::DynamicStruct> &);
   PyObject * wrap_dynamic_struct_reader(capnp::Response<capnp::DynamicStruct> &);
   ::kj::Promise<void> * call_server_method(PyObject * py_server, char * name, capnp::CallContext< capnp::DynamicStruct, capnp::DynamicStruct> & context);
   PyObject * wrap_kj_exception(kj::Exception &);
   PyObject * wrap_kj_exception_for_reraise(kj::Exception &);
   PyObject * get_exception_info(PyObject *, PyObject *, PyObject *);
   PyObject * convert_array_pyobject(kj::Array<PyObject *>&);
   ::kj::Promise<PyObject *> * extract_promise(PyObject *);
   ::capnp::RemotePromise< ::capnp::DynamicStruct> * extract_remote_promise(PyObject *);
 }

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

::kj::Promise<PyObject *> convert_to_pypromise(capnp::RemotePromise<capnp::DynamicStruct> & promise) {
    return promise.then([](capnp::Response<capnp::DynamicStruct>&& response) { return wrap_dynamic_struct_reader(response); } );
}

::kj::Promise<PyObject *> convert_to_pypromise(kj::Promise<void> & promise) {
    return promise.then([]() {
      GILAcquire gil;
      Py_INCREF( Py_None );
      return Py_None;
    });
}

template<class T>
::kj::Promise<void> convert_to_voidpromise(kj::Promise<T> & promise) {
    return promise.then([](T) { } );
}

void reraise_kj_exception() {
  GILAcquire gil;
  try {
    if (PyErr_Occurred())
      ; // let the latest Python exn pass through and ignore the current one
    else
      throw;
  }
  catch (kj::Exception& exn) {
    auto obj = wrap_kj_exception_for_reraise(exn);
    PyErr_SetObject((PyObject*)obj->ob_type, obj);
    Py_DECREF(obj);
  }
  catch (const std::exception& exn) {
    PyErr_SetString(PyExc_RuntimeError, exn.what());
  }
  catch (...)
  {
    PyErr_SetString(PyExc_RuntimeError, "Unknown exception");
  }
}

void check_py_error() {
    GILAcquire gil;
    PyObject * err = PyErr_Occurred();
    if(err) {
        PyObject * ptype, *pvalue, *ptraceback;
        PyErr_Fetch(&ptype, &pvalue, &ptraceback);
        if(ptype == NULL || pvalue == NULL || ptraceback == NULL)
          throw kj::Exception(kj::Exception::Type::FAILED, kj::heapString("capabilityHelper.h"), 44, kj::heapString("Unknown error occurred"));

        PyObject * info = get_exception_info(ptype, pvalue, ptraceback);

        PyObject * py_filename = PyTuple_GetItem(info, 0);
        kj::String filename(kj::heapString(PyBytes_AsString(py_filename)));

        PyObject * py_line = PyTuple_GetItem(info, 1);
        int line = PyInt_AsLong(py_line);

        PyObject * py_description = PyTuple_GetItem(info, 2);
        kj::String description(kj::heapString(PyBytes_AsString(py_description)));

        Py_DECREF(ptype);
        Py_DECREF(pvalue);
        Py_DECREF(ptraceback);
        Py_DECREF(info);
        PyErr_Clear();

        throw kj::Exception(kj::Exception::Type::FAILED, kj::mv(filename), line, kj::mv(description));
    }
}

kj::Promise<PyObject *> wrapPyFunc(PyObject * func, PyObject * arg) {
    GILAcquire gil;
    auto arg_promise = extract_promise(arg);

    if(arg_promise == NULL) {
      PyObject * result = PyObject_CallFunctionObjArgs(func, arg, NULL);
      Py_DECREF(arg);

      check_py_error();

      auto promise = extract_promise(result);
      if(promise != NULL)
        return kj::mv(*promise); // TODO: delete promise, see incref of containing promise in capnp.pyx
      auto remote_promise = extract_remote_promise(result);
      if(remote_promise != NULL)
        return convert_to_pypromise(*remote_promise); // TODO: delete promise, see incref of containing promise in capnp.pyx
      return result;
    }
    else {
      return arg_promise->then([&](PyObject * new_arg){ return wrapPyFunc(func, new_arg); });// TODO: delete arg_promise?
    }
}

kj::Promise<PyObject *> wrapPyFuncNoArg(PyObject * func) {
    GILAcquire gil;
    PyObject * result = PyObject_CallFunctionObjArgs(func, NULL);

    check_py_error();

    auto promise = extract_promise(result);
    if(promise != NULL)
      return kj::mv(*promise);
    auto remote_promise = extract_remote_promise(result);
    if(remote_promise != NULL)
      return convert_to_pypromise(*remote_promise); // TODO: delete promise, see incref of containing promise in capnp.pyx
    return result;
}

kj::Promise<PyObject *> wrapRemoteCall(PyObject * func, capnp::Response<capnp::DynamicStruct> & arg) {
    GILAcquire gil;
    PyObject * ret = wrap_remote_call(func, arg);

    check_py_error();

    auto promise = extract_promise(ret);
    if(promise != NULL)
      return kj::mv(*promise);
    auto remote_promise = extract_remote_promise(ret);
    if(remote_promise != NULL)
      return convert_to_pypromise(*remote_promise); // TODO: delete promise, see incref of containing promise in capnp.pyx
    return ret;
}

::kj::Promise<PyObject *> then(kj::Promise<PyObject *> & promise, PyObject * func, PyObject * error_func) {
  if(error_func == Py_None)
    return promise.then([func](PyObject * arg) { return wrapPyFunc(func, arg); } );
  else
    return promise.then([func](PyObject * arg) { return wrapPyFunc(func, arg); }
                                     , [error_func](kj::Exception arg) { return wrapPyFunc(error_func, wrap_kj_exception(arg)); } );
}

::kj::Promise<PyObject *> then(::capnp::RemotePromise< ::capnp::DynamicStruct> & promise, PyObject * func, PyObject * error_func) {
  if(error_func == Py_None)
    return promise.then([func](capnp::Response<capnp::DynamicStruct>&& arg) { return wrapRemoteCall(func, arg); } );
  else
    return promise.then([func](capnp::Response<capnp::DynamicStruct>&& arg) { return  wrapRemoteCall(func, arg); }
                                     , [error_func](kj::Exception arg) { return wrapPyFunc(error_func, wrap_kj_exception(arg)); } );
}

::kj::Promise<PyObject *> then(kj::Promise<void> & promise, PyObject * func, PyObject * error_func) {
  if(error_func == Py_None)
    return promise.then([func]() { return wrapPyFuncNoArg(func); } );
  else
    return promise.then([func]() { return wrapPyFuncNoArg(func); }
                                     , [error_func](kj::Exception arg) { return wrapPyFunc(error_func, wrap_kj_exception(arg)); } );
}

::kj::Promise<PyObject *> then(kj::Promise<kj::Array<PyObject *> > && promise) {
  return promise.then([](kj::Array<PyObject *>&& arg) { return convert_array_pyobject(arg); } );
}

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
                         capnp::CallContext< capnp::DynamicStruct, capnp::DynamicStruct> context) {
    auto methodName = method.getProto().getName();

    kj::Promise<void> * promise = call_server_method(py_server, const_cast<char *>(methodName.cStr()), context);

    check_py_error();

    if(promise == nullptr)
      return kj::READY_NOW;

    kj::Promise<void> ret(kj::mv(*promise));
    delete promise;
    return ret;
  }
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

capnp::DynamicCapability::Client new_client(capnp::InterfaceSchema & schema, PyObject * server) {
  return capnp::DynamicCapability::Client(kj::heap<PythonInterfaceDynamicImpl>(schema, server));
}
capnp::DynamicValue::Reader new_server(capnp::InterfaceSchema & schema, PyObject * server) {
  return capnp::DynamicValue::Reader(kj::heap<PythonInterfaceDynamicImpl>(schema, server));
}

capnp::Capability::Client server_to_client(capnp::InterfaceSchema & schema, PyObject * server) {
  return kj::heap<PythonInterfaceDynamicImpl>(schema, server);
}
