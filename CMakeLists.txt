cmake_minimum_required(VERSION 3.15)
project(pycapnp LANGUAGES CXX)

find_package(Python3 REQUIRED COMPONENTS Interpreter Development.Module)
# FindPython3 skips SOABI detection when CMAKE_OSX_ARCHITECTURES differs from the runner
# arch (e.g. x86_64 wheel on arm64 runner), leaving Python3_SOABI empty. On macOS,
# Rosetta 2 can transparently execute the cross-compile target Python, so re-derive it.
if(APPLE AND NOT Python3_SOABI)
    execute_process(
        COMMAND "${Python3_EXECUTABLE}" -c
            "import sysconfig; print(sysconfig.get_config_var('SOABI') or '', end='')"
        OUTPUT_VARIABLE Python3_SOABI
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
endif()
find_package(CapnProto REQUIRED)

set(CAPNP_PYX "${CMAKE_SOURCE_DIR}/capnp/lib/capnp.pyx")
set(CAPNP_CPP "${CMAKE_CURRENT_BINARY_DIR}/capnp/lib/capnp.cpp")

file(MAKE_DIRECTORY "${CMAKE_CURRENT_BINARY_DIR}/capnp/lib")

add_custom_command(
    OUTPUT "${CAPNP_CPP}"
    COMMAND "${Python3_EXECUTABLE}" -m cython
            --cplus
            -I "${CMAKE_SOURCE_DIR}"
            "${CAPNP_PYX}"
            -o "${CAPNP_CPP}"
    DEPENDS "${CAPNP_PYX}"
            "${CMAKE_SOURCE_DIR}/capnp/includes/capnp_cpp.pxd"
            "${CMAKE_SOURCE_DIR}/capnp/includes/schema_cpp.pxd"
            "${CMAKE_SOURCE_DIR}/capnp/helpers/helpers.pxd"
            "${CMAKE_SOURCE_DIR}/capnp/lib/capnp.pxd"
    COMMENT "Running Cython on capnp/lib/capnp.pyx"
)

Python3_add_library(capnp_ext MODULE WITH_SOABI
    "${CAPNP_CPP}"
    "${CMAKE_SOURCE_DIR}/capnp/helpers/capabilityHelper.cpp"
    "${CMAKE_SOURCE_DIR}/capnp/includes/PyCustomMessageBuilder.cpp"
)

set_target_properties(capnp_ext PROPERTIES
    OUTPUT_NAME "capnp"
    CXX_STANDARD 14
    CXX_STANDARD_REQUIRED ON
)

target_include_directories(capnp_ext PRIVATE
    "${CMAKE_SOURCE_DIR}"
    "${CMAKE_CURRENT_BINARY_DIR}"
    "${CMAKE_SOURCE_DIR}/capnp/includes"
)

target_link_libraries(capnp_ext PRIVATE
    CapnProto::capnpc
    CapnProto::capnp-rpc
    CapnProto::capnp
    CapnProto::kj-async
    CapnProto::kj
)

install(TARGETS capnp_ext DESTINATION capnp/lib)

install(FILES "${CMAKE_CURRENT_BINARY_DIR}/capnp/lib/capnp_api.h"
        DESTINATION capnp/lib)

get_target_property(_capnp_inc_dirs CapnProto::capnp INTERFACE_INCLUDE_DIRECTORIES)
foreach(_inc_dir IN LISTS _capnp_inc_dirs)
    string(REGEX REPLACE "\\$<\\$<CONFIG:[^>]+>:([^>]+)>" "\\1" _inc_dir_resolved "${_inc_dir}")
    if(EXISTS "${_inc_dir_resolved}/capnp/schema.capnp")
        file(GLOB _capnp_schemas "${_inc_dir_resolved}/capnp/*.capnp")
        install(FILES ${_capnp_schemas} DESTINATION capnp)
        break()
    endif()
endforeach()
