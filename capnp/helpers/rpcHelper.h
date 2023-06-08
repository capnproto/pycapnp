#pragma once

#include "capnp/dynamic.h"
#include <capnp/rpc.capnp.h>
#include "capnp/rpc-twoparty.h"
#include "Python.h"
#include "capabilityHelper.h"

capnp::Capability::Client bootstrapHelper(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::SERVER);
    return client.bootstrap(hostId);
}

capnp::Capability::Client bootstrapHelperServer(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::CLIENT);
    return client.bootstrap(hostId);
}
