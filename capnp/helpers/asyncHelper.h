#pragma once

#include "kj/async.h"
#include "Python.h"

class PyEventPort: public kj::EventPort {
public:
  PyEventPort(PyObject * _py_event_port): py_event_port(_py_event_port) {
    // We don't need to incref/decref, since this C++ class will be owned by the Python wrapper class, and we'll make sure the python class doesn't refcount to 0 elsewhere.
    // Py_INCREF(py_event_port);
  }
  virtual void wait() {
    PyObject_CallMethod(py_event_port, const_cast<char *>("wait"), NULL);
  }

  virtual void poll() {
    PyObject_CallMethod(py_event_port, const_cast<char *>("poll"), NULL);
  }

  virtual void setRunnable(bool runnable) {
    PyObject * arg = Py_False;
    if (runnable)
      arg = Py_True;
    PyObject_CallMethod(py_event_port, const_cast<char *>("set_runnable"), const_cast<char *>("o"), arg);
  }

private:
  PyObject * py_event_port;
};

void waitNeverDone(kj::WaitScope & scope) {
  kj::NEVER_DONE.wait(scope);
}
