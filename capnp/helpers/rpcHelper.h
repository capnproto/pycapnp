#pragma once

#include "capnp/dynamic.h"
#include <capnp/rpc.capnp.h>
#include "capnp/rpc-twoparty.h"
#include "Python.h"
#include "capabilityHelper.h"

kj::Own<capnp::Capability::Client> bootstrapHelper(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::SERVER);
    return kj::heap<capnp::Capability::Client>(client.bootstrap(hostId));
}

kj::Own<capnp::Capability::Client> bootstrapHelperServer(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::CLIENT);
    return kj::heap<capnp::Capability::Client>(client.bootstrap(hostId));
}
