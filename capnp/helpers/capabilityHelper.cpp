#include "capnp/helpers/capabilityHelper.h"
#include "capnp/lib/capnp_api.h"

::kj::Promise<PyObject *> convert_to_pypromise(capnp::RemotePromise<capnp::DynamicStruct> & promise) {
    return promise.then([](capnp::Response<capnp::DynamicStruct>&& response) { return wrap_dynamic_struct_reader(response); } );
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
        int line = PyLong_AsLong(py_line);

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

kj::Promise<void> PythonInterfaceDynamicImpl::call(capnp::InterfaceSchema::Method method,
                         capnp::CallContext< capnp::DynamicStruct, capnp::DynamicStruct> context) {
    auto methodName = method.getProto().getName();

    kj::Promise<void> * promise = call_server_method(py_server, const_cast<char *>(methodName.cStr()), context);

    check_py_error();

    if(promise == nullptr)
      return kj::READY_NOW;

    kj::Promise<void> ret(kj::mv(*promise));
    delete promise;
    return ret;
};

void init_capnp_api() {
    import_capnp__lib__capnp();
}
