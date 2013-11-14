import capnp
import test_capnp

import socket
import traceback

class Server:
    def __init__(self, val=1):
        self.val = val

    def foo(self, context):
        context.results.x = str(context.params.i * 5 + self.val)

def restore(ref_id):
    return test_capnp.TestInterface.new_server(Server(100))

def example_server(host='localhost', port=49999):
    backlog = 1 

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM) 
    s.bind((host,port)) 
    s.listen(backlog) 

    loop = capnp.EventLoop()
    while 1:
        try:
            (clientsocket, address) = s.accept()
            stream = capnp.FdAsyncIoStream(clientsocket.fileno())
            restorer = capnp.Restorer(test_capnp.TestSturdyRefObjectId, restore)
            server = capnp.RpcServer(loop, stream, restorer)

            waiter = capnp.PromiseFulfillerPair()
            loop.wait(waiter)
        except KeyboardInterrupt:
            break
        except:
            traceback.print_exc()

example_server()