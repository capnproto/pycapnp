#pragma once

#include "kj/io.h"
#include "capnp/dynamic.h"
#include "capnp/serialize-packed.h"

kj::Array< ::capnp::byte> messageToPackedBytes(capnp::MessageBuilder & message, size_t wordCount)
{

    kj::Array<capnp::byte> result = kj::heapArray<capnp::byte>(wordCount * 8);
    kj::ArrayOutputStream out(result.asPtr());
    capnp::writePackedMessage(out, message);
    return heapArray(out.getArray()); // TODO: make this non-copying somehow
}