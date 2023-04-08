#include "capnp/helpers/capabilityHelper.h"
#include "capnp/lib/capnp_api.h"

::kj::Promise<kj::Own<PyRefCounter>> convert_to_pypromise(capnp::RemotePromise<capnp::DynamicStruct> & promise) {
    return promise.then([](capnp::Response<capnp::DynamicStruct>&& response) {
      return kj::heap<PyRefCounter>(wrap_dynamic_struct_reader(response)); } );
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

kj::Promise<kj::Own<PyRefCounter>> wrapPyFunc(kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> arg) {
    GILAcquire gil;
    PyObject * result = PyObject_CallFunctionObjArgs(func->obj, arg->obj, NULL);

    check_py_error();

    auto promise = extract_promise(result);
    if (promise != NULL) {
      return kj::mv(*promise); // TODO: delete promise, see incref of containing promise in capnp.pyx
    }
    auto remote_promise = extract_remote_promise(result);
    if (remote_promise != NULL) {
      return convert_to_pypromise(*remote_promise); // TODO: delete promise, see incref of containing promise in capnp.pyx
    }
    return kj::heap<PyRefCounter>(result);
}

kj::Promise<kj::Own<PyRefCounter>> wrapPyFuncNoArg(kj::Own<PyRefCounter> func) {
    GILAcquire gil;
    PyObject * result = PyObject_CallFunctionObjArgs(func->obj, NULL);

    check_py_error();

    auto promise = extract_promise(result);
    if(promise != NULL)
      return kj::mv(*promise);
    auto remote_promise = extract_remote_promise(result);
    if(remote_promise != NULL)
      return convert_to_pypromise(*remote_promise); // TODO: delete promise, see incref of containing promise in capnp.pyx
    return kj::heap<PyRefCounter>(result);
}

kj::Promise<kj::Own<PyRefCounter>> wrapRemoteCall(kj::Own<PyRefCounter> func, capnp::Response<capnp::DynamicStruct> & arg) {
    GILAcquire gil;
    PyObject * ret = wrap_remote_call(func->obj, arg);

    check_py_error();

    auto promise = extract_promise(ret);
    if(promise != NULL)
      return kj::mv(*promise);
    auto remote_promise = extract_remote_promise(ret);
    if(remote_promise != NULL)
      return convert_to_pypromise(*remote_promise); // TODO: delete promise, see incref of containing promise in capnp.pyx
    return kj::heap<PyRefCounter>(ret);
}

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Promise<kj::Own<PyRefCounter>> & promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func) {
  if(error_func->obj == Py_None)
    return promise.then(kj::mvCapture(func, [](auto func, kj::Own<PyRefCounter> arg) {
      return wrapPyFunc(kj::mv(func), kj::mv(arg)); } ));
  else
    return promise.then
      (kj::mvCapture(func, [](auto func, kj::Own<PyRefCounter> arg) {
        return wrapPyFunc(kj::mv(func), kj::mv(arg)); }),
        kj::mvCapture(error_func, [](auto error_func, kj::Exception arg) {
          return wrapPyFunc(kj::mv(error_func), kj::heap<PyRefCounter>(wrap_kj_exception(arg))); } ));
}

::kj::Promise<kj::Own<PyRefCounter>> then(::capnp::RemotePromise< ::capnp::DynamicStruct> & promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func) {
  if(error_func->obj == Py_None)
    return promise.then(kj::mvCapture(func, [](auto func, capnp::Response<capnp::DynamicStruct>&& arg) {
      return wrapRemoteCall(kj::mv(func), arg); } ));
  else
    return promise.then
      (kj::mvCapture(func, [](auto func, capnp::Response<capnp::DynamicStruct>&& arg) {
        return  wrapRemoteCall(kj::mv(func), arg); }),
       kj::mvCapture(error_func, [](auto error_func, kj::Exception arg) {
         return wrapPyFunc(kj::mv(error_func), kj::heap<PyRefCounter>(wrap_kj_exception(arg))); } ));
}

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Promise<void> & promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func) {
  if(error_func->obj == Py_None)
    return promise.then(kj::mvCapture(func, [](auto func) { return wrapPyFuncNoArg(kj::mv(func)); } ));
  else
    return promise.then(kj::mvCapture(func, [](auto func) { return wrapPyFuncNoArg(kj::mv(func)); }),
                        kj::mvCapture(error_func, [](auto error_func, kj::Exception arg) {
                          return wrapPyFunc(kj::mv(error_func), kj::heap<PyRefCounter>(wrap_kj_exception(arg))); } ));
}

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Promise<kj::Array<kj::Own<PyRefCounter>> > && promise) {
  return promise.then([](kj::Array<kj::Own<PyRefCounter>>&& arg) {
    return kj::heap<PyRefCounter>(convert_array_pyobject(arg)); } );
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
