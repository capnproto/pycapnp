#ifdef __GNUC__
  #if __clang__
    #if __cplusplus >= 201103L && !__has_include(<initializer_list>)
      #warning "Your compiler supports C++11 but your C++ standard library does not.  If your system has libc++ installed (as should be the case on e.g. Mac OSX), try adding -stdlib=libc++ to your CFLAGS (ignore the other warning that says to use CXXFLAGS)."
    #endif
  #endif
#endif

#include "capnp/dynamic.h"

static_assert(CAPNP_VERSION >= 5000, "Version of Cap'n Proto C++ Library is too old. Please upgrade to a version >= 0.5 and then re-install this python library");
