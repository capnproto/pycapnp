#pragma once

#include "kj/io.h"
#include "capnp/dynamic.h"
#include "capnp/serialize-packed.h"

kj::Array< ::capnp::byte> messageToPackedBytes(capnp::MessageBuilder & message)
{
    auto segments = message.getSegmentsForOutput();
    size_t totalSize = segments.size() / 2 + 1;

    for (auto& segment: segments) {
        totalSize += segment.size();
    }

    kj::Array<capnp::byte> result = kj::heapArray<capnp::byte>(totalSize * 8);
    kj::ArrayOutputStream out(result.asPtr());
    capnp::writePackedMessage(out, message);
    return heapArray(out.getArray()); // TODO: make this non-copying somehow
}