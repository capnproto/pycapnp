#pragma once

#include "capnp/dynamic.h"
#include "capnp/schema.capnp.h"

/// @brief Convert the dynamic struct to a Node::Reader
::capnp::schema::Node::Reader toReader(capnp::DynamicStruct::Reader reader)
{
    // requires an intermediate step to AnyStruct before going directly to Node::Reader,
    // since there exists no direct conversion from DynamicStruct::Reader to Node::Reader.
    return reader.as<capnp::AnyStruct>().as<capnp::schema::Node>();
}
