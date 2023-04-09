#include "capnp/helpers/capabilityHelper.h"
#include "capnp/lib/capnp_api.h"

::kj::Promise<kj::Own<PyRefCounter>> convert_to_pypromise(kj::Own<capnp::RemotePromise<capnp::DynamicStruct>> promise) {
    return promise->then([](capnp::Response<capnp::DynamicStruct>&& response) {
      return stealPyRef(wrap_dynamic_struct_reader(response)); } );
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

inline kj::Promise<kj::Own<PyRefCounter>> maybeUnwrapPromise(PyObject * result) {
  check_py_error();
  auto promise = extract_promise(result);
  if (promise != NULL) {
    Py_DECREF(result);
    auto ret(kj::mv(*promise));
    return ret;
  }
  auto remote_promise = extract_remote_promise(result);
  if (remote_promise != NULL) {
    auto ret = convert_to_pypromise(kj::heap<capnp::RemotePromise<capnp::DynamicStruct>>(kj::mv(*remote_promise)));
    Py_DECREF(result);
    return ret;
  }
  return stealPyRef(result);
}

kj::Promise<kj::Own<PyRefCounter>> wrapPyFunc(kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> arg) {
    GILAcquire gil;
    // Creates an owned reference, which will be destroyed in maybeUnwrapPromise
    PyObject * result = PyObject_CallFunctionObjArgs(func->obj, arg->obj, NULL);
    return maybeUnwrapPromise(result);
}

kj::Promise<kj::Own<PyRefCounter>> wrapPyFuncNoArg(kj::Own<PyRefCounter> func) {
    GILAcquire gil;
    // Creates an owned reference, which will be destroyed in maybeUnwrapPromise
    PyObject * result = PyObject_CallFunctionObjArgs(func->obj, NULL);
    return maybeUnwrapPromise(result);
}

kj::Promise<kj::Own<PyRefCounter>> wrapRemoteCall(kj::Own<PyRefCounter> func, capnp::Response<capnp::DynamicStruct> & arg) {
    GILAcquire gil;
    // Creates an owned reference, which will be destroyed in maybeUnwrapPromise
    PyObject * ret = wrap_remote_call(func->obj, arg);
    return maybeUnwrapPromise(ret);
}

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Own<kj::Promise<kj::Own<PyRefCounter>>> promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func) {
  if(error_func->obj == Py_None)
    return promise->then(kj::mvCapture(func, [](auto func, kj::Own<PyRefCounter> arg) {
      return wrapPyFunc(kj::mv(func), kj::mv(arg)); } ));
  else
    return promise->then
      (kj::mvCapture(func, [](auto func, kj::Own<PyRefCounter> arg) {
        return wrapPyFunc(kj::mv(func), kj::mv(arg)); }),
        kj::mvCapture(error_func, [](auto error_func, kj::Exception arg) {
          return wrapPyFunc(kj::mv(error_func), stealPyRef(wrap_kj_exception(arg))); } ));
}

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Own<::capnp::RemotePromise<::capnp::DynamicStruct>> promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func) {
  if(error_func->obj == Py_None)
    return promise->then(kj::mvCapture(func, [](auto func, capnp::Response<capnp::DynamicStruct>&& arg) {
      return wrapRemoteCall(kj::mv(func), arg); } ));
  else
    return promise->then
      (kj::mvCapture(func, [](auto func, capnp::Response<capnp::DynamicStruct>&& arg) {
        return  wrapRemoteCall(kj::mv(func), arg); }),
       kj::mvCapture(error_func, [](auto error_func, kj::Exception arg) {
         return wrapPyFunc(kj::mv(error_func), stealPyRef(wrap_kj_exception(arg))); } ));
}

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Own<kj::Promise<void>> promise,
                                          kj::Own<PyRefCounter> func, kj::Own<PyRefCounter> error_func) {
  if(error_func->obj == Py_None)
    return promise->then(kj::mvCapture(func, [](auto func) { return wrapPyFuncNoArg(kj::mv(func)); } ));
  else
    return promise->then(kj::mvCapture(func, [](auto func) { return wrapPyFuncNoArg(kj::mv(func)); }),
                        kj::mvCapture(error_func, [](auto error_func, kj::Exception arg) {
                          return wrapPyFunc(kj::mv(error_func), stealPyRef(wrap_kj_exception(arg))); } ));
}

::kj::Promise<kj::Own<PyRefCounter>> then(kj::Promise<kj::Array<kj::Own<PyRefCounter>> > && promise) {
  return promise.then([](kj::Array<kj::Own<PyRefCounter>>&& arg) {
    return stealPyRef(convert_array_pyobject(arg)); } );
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
