from __future__ import print_function

import capnp
import example_capability_capnp

class Server:
    def __init__(self, val=1):
        self.val = val

    def foo(self, context):
        context.results.x = str(context.params.i * 5 + self.val)

def test_simple_rpc():
    def _restore(ref_id):
        return example_capability_capnp.TestInterface.new_server(Server(100))

    loop = capnp.EventLoop()
    
    pipe = capnp.TwoWayPipe()
    restorer = capnp.Restorer(example_capability_capnp.TestSturdyRefObjectId, _restore)
    server = capnp.RpcServer(loop, restorer, pipe)
    client = capnp.RpcClient(loop, pipe)

    ref = example_capability_capnp.TestSturdyRefObjectId.new_message()
    cap = client.restore(ref.as_reader())
    cap = cap.cast_as(example_capability_capnp.TestInterface)

    remote = cap.foo(i=5)
    response = loop.wait_remote(remote)

    assert response.x == '125'

test_simple_rpc()