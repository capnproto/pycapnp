#include <boost/asio.hpp>
#include "capnp/rpc-twoparty.h"
#include <kj/async-unix.h>
#include <kj/thread.h>
#include "test.capnp.h"

using namespace capnp;
using namespace capnproto_test::capnp;
using namespace kj;

class TestInterfaceImpl final: public test::TestInterface::Server {
public:
  TestInterfaceImpl(int& callCount);

  ::kj::Promise<void> foo(
      test::TestInterface::FooParams::Reader params,
      test::TestInterface::FooResults::Builder result) override;

  ::kj::Promise<void> bazAdvanced(
      ::capnp::CallContext<test::TestInterface::BazParams,
                           test::TestInterface::BazResults> context) override;

private:
  int& callCount;
};

class TestExtendsImpl final: public test::TestExtends::Server {
public:
  TestExtendsImpl(int& callCount);

  ::kj::Promise<void> foo(
      test::TestInterface::FooParams::Reader params,
      test::TestInterface::FooResults::Builder result) override;

  ::kj::Promise<void> graultAdvanced(
      ::capnp::CallContext<test::TestExtends::GraultParams, test::TestAllTypes> context) override;

private:
  int& callCount;
};

class TestPipelineImpl final: public test::TestPipeline::Server {
public:
  TestPipelineImpl(int& callCount);

  ::kj::Promise<void> getCapAdvanced(
      capnp::CallContext<test::TestPipeline::GetCapParams,
                         test::TestPipeline::GetCapResults> context) override;

private:
  int& callCount;
};


TestInterfaceImpl::TestInterfaceImpl(int& callCount): callCount(callCount) {}

::kj::Promise<void> TestInterfaceImpl::foo(
    test::TestInterface::FooParams::Reader params,
    test::TestInterface::FooResults::Builder result) {
  ++callCount;
  result.setX("foo");
  return kj::READY_NOW;
}

::kj::Promise<void> TestInterfaceImpl::bazAdvanced(
    ::capnp::CallContext<test::TestInterface::BazParams,
                         test::TestInterface::BazResults> context) {
  ++callCount;
  auto params = context.getParams();
  // checkTestMessage(params.getS());
  context.releaseParams();

  return kj::READY_NOW;
}

TestExtendsImpl::TestExtendsImpl(int& callCount): callCount(callCount) {}

::kj::Promise<void> TestExtendsImpl::foo(
    test::TestInterface::FooParams::Reader params,
    test::TestInterface::FooResults::Builder result) {
  ++callCount;
  result.setX("bar");
  return kj::READY_NOW;
}

::kj::Promise<void> TestExtendsImpl::graultAdvanced(
    ::capnp::CallContext<test::TestExtends::GraultParams, test::TestAllTypes> context) {
  ++callCount;
  context.releaseParams();

  // initTestMessage(context.getResults());

  return kj::READY_NOW;
}

TestPipelineImpl::TestPipelineImpl(int& callCount): callCount(callCount) {}

::kj::Promise<void> TestPipelineImpl::getCapAdvanced(
    capnp::CallContext<test::TestPipeline::GetCapParams,
                       test::TestPipeline::GetCapResults> context) {
  ++callCount;

  auto params = context.getParams();

  auto cap = params.getInCap();
  context.releaseParams();

  auto request = cap.fooRequest();
  request.setI(123);
  request.setJ(true);

  return request.send().then(
      [this,context](capnp::Response<test::TestInterface::FooResults>&& response) mutable {

        auto result = context.getResults();
        result.setS("bar");
        result.initOutBox().setCap(kj::heap<TestExtendsImpl>(callCount));
      });
}


class TestRestorer final: public SturdyRefRestorer<test::TestSturdyRefObjectId> {
public:
  TestRestorer(int& callCount): callCount(callCount) {}

  Capability::Client restore(test::TestSturdyRefObjectId::Reader objectId) override {
    switch (objectId.getTag()) {
      case test::TestSturdyRefObjectId::Tag::TEST_INTERFACE:
        return kj::heap<TestInterfaceImpl>(callCount);
      // case test::TestSturdyRefObjectId::Tag::TEST_EXTENDS:
      //   return Capability::Client(newBrokenCap("No TestExtends implemented."));
      case test::TestSturdyRefObjectId::Tag::TEST_PIPELINE:
        return kj::heap<TestPipelineImpl>(callCount);
    }
    KJ_UNREACHABLE;
  }

private:
  int& callCount;
};

void runServer(kj::Promise<void> quit, kj::Own<kj::AsyncIoStream> stream, int& callCount) {
  // Set up the server.
  kj::UnixEventLoop eventLoop;
  TwoPartyVatNetwork network(eventLoop, *stream, rpc::twoparty::Side::SERVER);
  TestRestorer restorer(callCount);
  auto server = makeRpcServer(network, restorer, eventLoop);

  // Wait until quit promise is fulfilled.
  eventLoop.wait(kj::mv(quit));
}

Capability::Client getPersistentCap(RpcSystem<rpc::twoparty::SturdyRefHostId>& client,
                                    rpc::twoparty::Side side,
                                    test::TestSturdyRefObjectId::Tag tag) {
  // Create the SturdyRefHostId.
  MallocMessageBuilder hostIdMessage(8);
  auto hostId = hostIdMessage.initRoot<rpc::twoparty::SturdyRefHostId>();
  hostId.setSide(side);

  // Create the SturdyRefObjectId.
  MallocMessageBuilder objectIdMessage(8);
  objectIdMessage.initRoot<test::TestSturdyRefObjectId>().setTag(tag);

  // Connect to the remote capability.
  return client.restore(hostId, objectIdMessage.getRoot<ObjectPointer>());
}

using boost::asio::ip::tcp;
int main()
{
  try
  {
    int callCount(0);
    boost::asio::io_service io_service;

    tcp::acceptor acceptor(io_service, tcp::endpoint(tcp::v4(), 49999));
    tcp::socket socket(io_service);
    acceptor.accept(socket);

    kj::Own<AsyncIoStream> stream(AsyncIoStream::wrapFd(socket.native_handle()));
    auto quitter = kj::newPromiseAndFulfiller<void>();
    runServer(kj::mv(quitter.promise), kj::mv(stream), callCount);
  }
  catch (std::exception& e)
  {
    std::cerr << e.what() << std::endl;
  }
    return 0;
}