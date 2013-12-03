import capnp
import test_capnp

import socket
import traceback

class Server:
    def __init__(self, val=1):
        self.val = val

    def foo(self, i, **kwargs):
        return str(i * 5 + self.val)

def restore(ref_id):
    if ref_id.tag == 'testInterface':
        return test_capnp.TestInterface.new_server(Server(100))
    else:
        raise ValueError('invalid ref')

def example_server(host='localhost', port=49999):
    backlog = 1 

    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM) 
    s.bind((host,port)) 
    s.listen(backlog) 

    while 1:
        try:
            (clientsocket, address) = s.accept()
            restorer = capnp.Restorer(test_capnp.TestSturdyRefObjectId, restore)
            server = capnp.RpcServer(clientsocket, restorer)

            server.run_forever()
        except KeyboardInterrupt:
            break
        except:
            traceback.print_exc()

example_server()