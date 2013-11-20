from libc.stdint cimport *

cdef uint32_t A = 1664525
cdef uint32_t C = 1013904223
cdef uint32_t state = C
cdef int32_t MAX_INT = 2**31 - 1

cpdef uint32_t nextFastRand():
  global state
  state = A * state + C
  return state

cpdef uint32_t rand_int(uint32_t range):
  return nextFastRand() % range

cpdef double rand_double(double range):
  return nextFastRand() * range / MAX_INT

cpdef bint rand_bool():
  return nextFastRand() % 2
