#include "capnp/rpc-twoparty.h"
#include <kj/async-unix.h>
#include <kj/thread.h>
#include "test.capnp.h"
#include <iostream>
#include <cassert>

using namespace capnp;
using namespace capnproto_test::capnp;
using namespace kj;

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

int main()
{
  try
  {
    kj::UnixEventLoop loop;
    auto result = loop.evalLater([&]() {
      auto network = Network::newSystemNetwork();
      auto address = loop.wait(network->parseRemoteAddress("127.0.0.1:49999"));
      auto stream = loop.wait(address->connect());
      TwoPartyVatNetwork vat(loop, *stream, rpc::twoparty::Side::CLIENT);
      auto rpcClient = makeRpcClient(vat, loop);

      // Request the particular capability from the server.
      auto client = getPersistentCap(rpcClient, rpc::twoparty::Side::SERVER,
          test::TestSturdyRefObjectId::Tag::TEST_INTERFACE).castAs<test::TestInterface>();

      auto request1 = client.fooRequest();
      request1.setI(5);
      auto promise1 = request1.send();
      auto response1 = loop.wait(kj::mv(promise1));

      assert ("125" == response1.getX()); 
    });

    loop.wait(kj::mv(result));
  }
  catch (std::exception& e)
  {
    std::cerr << e.what() << std::endl;
  }
    return 0;
}