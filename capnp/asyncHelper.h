#include "kj/async.h"
#include "Python.h"

extern "C" {
   PyObject * wrap_kj_exception(kj::Exception &);
   // void _gevent_eventloop_prepare_to_sleep();
   // void _gevent_eventloop_sleep();
   // void _gevent_eventloop_wake();
}

PyObject * wrapPyFunc(PyObject * func, PyObject * arg) {
    PyObject * result = PyObject_CallFunctionObjArgs(func, arg, NULL);
    Py_DECREF(func);
    return result;
}

::kj::Promise<PyObject *> evalLater(kj::EventLoop & loop, PyObject * func) {
  return loop.evalLater([func]() { return wrapPyFunc(func, NULL); } );
}

::kj::Promise<PyObject *> there(kj::EventLoop & loop, kj::Promise<PyObject *> & promise, PyObject * func, PyObject * error_func) {
  if(error_func == Py_None)
    return loop.there(kj::mv(promise), [func](PyObject * arg) { return wrapPyFunc(func, arg); } );
  else
    return loop.there(kj::mv(promise), [func](PyObject * arg) { return wrapPyFunc(func, arg); } 
                                     , [error_func](kj::Exception arg) { return wrapPyFunc(error_func, wrap_kj_exception(arg)); } );
}
::kj::Promise<PyObject *> then(kj::Promise<PyObject *> & promise, PyObject * func, PyObject * error_func) {
  if(error_func == Py_None)
    return promise.then([func](PyObject * arg) { return wrapPyFunc(func, arg); } );
  else
    return promise.then([func](PyObject * arg) { return wrapPyFunc(func, arg); } 
                                     , [error_func](kj::Exception arg) { return wrapPyFunc(error_func, wrap_kj_exception(arg)); } );
}

// class PyEventLoop final: public ::kj::EventLoop {
// public:
//   PyEventLoop() {}
//   ~PyEventLoop() noexcept(false) {}

// protected:
//   void prepareToSleep() noexcept override {
//     _gevent_eventloop_prepare_to_sleep();
//   }
//   void sleep() override {
//     _gevent_eventloop_sleep();
//   }
//   void wake() const override {
//     _gevent_eventloop_wake();
//   }
// };