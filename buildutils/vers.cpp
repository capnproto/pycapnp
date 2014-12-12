// check libcapnp version

#include <stdio.h>
#include "capnp/common.h"

int main(int argc, char **argv){
    fprintf(stdout, "vers: %d.%d.%d\n", CAPNP_VERSION_MAJOR, CAPNP_VERSION_MINOR, CAPNP_VERSION_MICRO);
    return 0;
}
