#ifndef __PYX_HAVE__capnp__async
#define __PYX_HAVE__capnp__async


#ifndef __PYX_HAVE_API__capnp__async

#ifndef __PYX_EXTERN_C
  #ifdef __cplusplus
    #define __PYX_EXTERN_C extern "C"
  #else
    #define __PYX_EXTERN_C extern
  #endif
#endif

__PYX_EXTERN_C DL_IMPORT(PyObject) *wrap_kj_exception( ::kj::Exception &);

#endif /* !__PYX_HAVE_API__capnp__async */

#if PY_MAJOR_VERSION < 3
PyMODINIT_FUNC initasync(void);
#else
PyMODINIT_FUNC PyInit_async(void);
#endif

#endif /* !__PYX_HAVE__capnp__async */
