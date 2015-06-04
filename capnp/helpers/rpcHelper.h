#pragma once

#include "capnp/dynamic.h"
#include <capnp/rpc.capnp.h>
#include "capnp/rpc-twoparty.h"
#include "Python.h"
#include "capabilityHelper.h"

extern "C" {
   capnp::Capability::Client * call_py_restorer(PyObject *, capnp::AnyPointer::Reader &);
}

class PyRestorer final: public capnp::SturdyRefRestorer<capnp::AnyPointer> {
public:
  PyRestorer(PyObject * _py_restorer): py_restorer(_py_restorer) {
    // We don't need to incref/decref, since this C++ class will be owned by the Python wrapper class, and we'll make sure the python class doesn't refcount to 0 elsewhere.
    // Py_INCREF(py_restorer);
  }

  // ~PyRestorer() {
  //   Py_DECREF(py_restorer);
  // }

  capnp::Capability::Client restore(capnp::AnyPointer::Reader objectId) override {
    GILAcquire gil;
    capnp::Capability::Client * ret = call_py_restorer(py_restorer, objectId);
    check_py_error();
    capnp::Capability::Client stack_ret(*ret);
    delete ret;

    return stack_ret;
  }

private:
  PyObject * py_restorer;
};

capnp::Capability::Client restoreHelper(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client, capnp::MessageBuilder & objectId) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::SERVER);
    return client.restore(hostId, objectId.getRoot<capnp::AnyPointer>());
}

capnp::Capability::Client restoreHelper(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client, capnp::MessageReader & objectId) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::SERVER);
    return client.restore(hostId, objectId.getRoot<capnp::AnyPointer>());
}

capnp::Capability::Client restoreHelper(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client, capnp::AnyPointer::Reader & objectId) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::SERVER);
    return client.restore(hostId, objectId);
}

capnp::Capability::Client restoreHelper(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client, capnp::AnyPointer::Builder & objectId) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::SERVER);
    return client.restore(hostId, objectId);
}

capnp::Capability::Client restoreHelper(capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId>& client) {
    capnp::MallocMessageBuilder hostIdMessage(8);
    auto hostId = hostIdMessage.initRoot<capnp::rpc::twoparty::SturdyRefHostId>();
    hostId.setSide(capnp::rpc::twoparty::Side::SERVER);

    capnp::MallocMessageBuilder blankMessage(8);
    auto objectId = blankMessage.getRoot<capnp::AnyPointer>();
    return client.restore(hostId, objectId);
}

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

template <typename SturdyRefHostId, typename ProvisionId,
          typename RecipientId, typename ThirdPartyCapId, typename JoinAnswer>
capnp::RpcSystem<SturdyRefHostId> makeRpcClientWithRestorer(
    capnp::VatNetwork<SturdyRefHostId, ProvisionId, RecipientId, ThirdPartyCapId, JoinAnswer>& network,
    PyRestorer& restorer) {
    using namespace capnp;
  return RpcSystem<SturdyRefHostId>(network, restorer);
}

struct ServerContextRestorer {
  kj::Own<kj::AsyncIoStream> stream;
  capnp::TwoPartyVatNetwork network;
  capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId> rpcSystem;

  ServerContextRestorer(kj::Own<kj::AsyncIoStream>&& stream, capnp::SturdyRefRestorer<capnp::AnyPointer>& restorer)
      : stream(kj::mv(stream)),
        network(*this->stream, capnp::rpc::twoparty::Side::SERVER),
        rpcSystem(makeRpcServer(network, restorer)) {}
};

class ErrorHandler : public kj::TaskSet::ErrorHandler {
  void taskFailed(kj::Exception&& exception) override {
    kj::throwFatalException(kj::mv(exception));
  }
};

void acceptLoopRestorer(kj::TaskSet & tasks, PyRestorer & restorer, kj::Own<kj::ConnectionReceiver>&& listener) {
  auto ptr = listener.get();
  tasks.add(ptr->accept().then(kj::mvCapture(kj::mv(listener),
      [&](kj::Own<kj::ConnectionReceiver>&& listener,
             kj::Own<kj::AsyncIoStream>&& connection) {
    acceptLoopRestorer(tasks, restorer, kj::mv(listener));

    auto server = kj::heap<ServerContextRestorer>(kj::mv(connection), restorer);

    // Arrange to destroy the server context when all references are gone, or when the
    // EzRpcServer is destroyed (which will destroy the TaskSet).
    tasks.add(server->network.onDisconnect().attach(kj::mv(server)));
  })));
}

kj::Promise<PyObject *> connectServerRestorer(kj::TaskSet & tasks, PyRestorer & restorer, kj::AsyncIoContext * context, kj::StringPtr bindAddress) {
    auto paf = kj::newPromiseAndFulfiller<unsigned int>();
    auto portPromise = paf.promise.fork();

    tasks.add(context->provider->getNetwork().parseAddress(bindAddress)
        .then(kj::mvCapture(paf.fulfiller,
          [&](kj::Own<kj::PromiseFulfiller<unsigned int>>&& portFulfiller,
                 kj::Own<kj::NetworkAddress>&& addr) {
      auto listener = addr->listen();
      portFulfiller->fulfill(listener->getPort());
      acceptLoopRestorer(tasks, restorer, kj::mv(listener));
    })));

    return portPromise.addBranch().then([&](unsigned int port) { return PyLong_FromUnsignedLong(port); });
}


struct ServerContext {
  kj::Own<kj::AsyncIoStream> stream;
  capnp::TwoPartyVatNetwork network;
  capnp::RpcSystem<capnp::rpc::twoparty::SturdyRefHostId> rpcSystem;

  ServerContext(kj::Own<kj::AsyncIoStream>&& stream, capnp::Capability::Client client)
      : stream(kj::mv(stream)),
        network(*this->stream, capnp::rpc::twoparty::Side::SERVER),
        rpcSystem(makeRpcServer(network, client)) {}
};

void acceptLoop(kj::TaskSet & tasks, capnp::Capability::Client client, kj::Own<kj::ConnectionReceiver>&& listener) {
  auto ptr = listener.get();
  tasks.add(ptr->accept().then(kj::mvCapture(kj::mv(listener),
      [&, client](kj::Own<kj::ConnectionReceiver>&& listener,
             kj::Own<kj::AsyncIoStream>&& connection) mutable {
    acceptLoop(tasks, client, kj::mv(listener));

    auto server = kj::heap<ServerContext>(kj::mv(connection), client);

    // Arrange to destroy the server context when all references are gone, or when the
    // EzRpcServer is destroyed (which will destroy the TaskSet).
    tasks.add(server->network.onDisconnect().attach(kj::mv(server)));
  })));
}

kj::Promise<PyObject *> connectServer(kj::TaskSet & tasks, capnp::Capability::Client client, kj::AsyncIoContext * context, kj::StringPtr bindAddress) {
    auto paf = kj::newPromiseAndFulfiller<unsigned int>();
    auto portPromise = paf.promise.fork();

    tasks.add(context->provider->getNetwork().parseAddress(bindAddress)
        .then(kj::mvCapture(paf.fulfiller,
          [&, client](kj::Own<kj::PromiseFulfiller<unsigned int>>&& portFulfiller,
                 kj::Own<kj::NetworkAddress>&& addr) mutable {
      auto listener = addr->listen();
      portFulfiller->fulfill(listener->getPort());
      acceptLoop(tasks, client, kj::mv(listener));
    })));

    return portPromise.addBranch().then([&](unsigned int port) { return PyLong_FromUnsignedLong(port); });
}
