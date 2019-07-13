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

class ErrorHandler : public kj::TaskSet::ErrorHandler {
  void taskFailed(kj::Exception&& exception) override {
    kj::throwFatalException(kj::mv(exception));
  }
};

struct ServerContext {
  kj::Own<kj::AsyncIoStream> stream;
  capnp::TwoPartyVatNetwork network;
  capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId> rpcSystem;

  ServerContext(kj::Own<kj::AsyncIoStream>&& stream, capnp::Capability::Client client, capnp::ReaderOptions & opts)
      : stream(kj::mv(stream)),
        network(*this->stream, capnp::rpc::twoparty::Side::SERVER, opts),
        rpcSystem(makeRpcServer(network, client)) {}
};

void acceptLoop(kj::TaskSet & tasks, capnp::Capability::Client client, kj::Own<kj::ConnectionReceiver>&& listener, capnp::ReaderOptions & opts) {
  auto ptr = listener.get();
  tasks.add(ptr->accept().then(kj::mvCapture(kj::mv(listener),
      [&, client](kj::Own<kj::ConnectionReceiver>&& listener,
             kj::Own<kj::AsyncIoStream>&& connection) mutable {
    acceptLoop(tasks, client, kj::mv(listener), opts);

    auto server = kj::heap<ServerContext>(kj::mv(connection), client, opts);

    // Arrange to destroy the server context when all references are gone, or when the
    // EzRpcServer is destroyed (which will destroy the TaskSet).
    tasks.add(server->network.onDisconnect().attach(kj::mv(server)));
  })));
}

kj::Promise<PyObject *> connectServer(kj::TaskSet & tasks, capnp::Capability::Client client, kj::AsyncIoContext * context, kj::StringPtr bindAddress, capnp::ReaderOptions & opts) {
    auto paf = kj::newPromiseAndFulfiller<unsigned int>();
    auto portPromise = paf.promise.fork();

    tasks.add(context->provider->getNetwork().parseAddress(bindAddress)
        .then(kj::mvCapture(paf.fulfiller,
          [&, client](kj::Own<kj::PromiseFulfiller<unsigned int>>&& portFulfiller,
                 kj::Own<kj::NetworkAddress>&& addr) mutable {
      auto listener = addr->listen();
      portFulfiller->fulfill(listener->getPort());
      acceptLoop(tasks, client, kj::mv(listener), opts);
    })));

    return portPromise.addBranch().then([&](unsigned int port) { return PyLong_FromUnsignedLong(port); });
}
