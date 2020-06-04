#ifdef _MSC_VER
#pragma comment(lib, "Ws2_32.lib")
#pragma comment(lib, "advapi32.lib")
#endif

#include "capnp/dynamic.h"

static_assert(CAPNP_VERSION >= 8000, "Version of Cap'n Proto C++ Library is too old. Please upgrade to a version >= 0.8 and then re-install this python library");
