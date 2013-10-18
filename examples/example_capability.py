from __future__ import print_function

import capnp
import example_capability_capnp

class Server:
    def foo(self, context):
        context.results.x = str(context.params.i * 5 + 1)

def example_client():
    loop = capnp.EventLoop()

    client = example_capability_capnp.TestInterface.new_client(Server(), loop)
    
    req = client.request('foo')
    req.i = 5

    remote = req.send()
    response = loop.wait_remote(remote)

    print(response.x)

if __name__ == '__main__':
    example_client()
