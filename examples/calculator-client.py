#!/usr/bin/env python

from __future__ import print_function
import argparse
import socket
import capnp

import calculator_capnp
import rpc_capnp

class PowerFunction(calculator_capnp.Calculator.Function.Server):
    '''An implementation of the Function interface wrapping pow().  Note that
    we're implementing this on the client side and will pass a reference to
    the server.  The server will then be able to make calls back to the client.'''

    def call(self, params):
      return pow(params[0], params[1])

def parse_args():
    parser = argparse.ArgumentParser('Connects to the Calculator server at the given address and does some RPCs')
    parser.add_argument("host", help="HOST:PORT")

    return parser.parse_args()

def main():
    host, port = parse_args().host.split(':')

    sock = socket.create_connection((host, port))
    client = capnp.RpcClient(sock)

    ref = rpc_capnp.SturdyRef.new_message()
    ref.objectId.set_as_text('calculator')
    calculator = client.restore(ref.objectId).cast_as(calculator_capnp.Calculator)

    '''Make a request that just evaluates the literal value 123.

    What's interesting here is that evaluate() returns a "Value", which is
    another interface and therefore points back to an object living on the
    server.  We then have to call read() on that object to read it.
    However, even though we are making two RPC's, this block executes in
    *one* network round trip because of promise pipelining:  we do not wait
    for the first call to complete before we send the second call to the
    server.'''

    print('Evaluating a literal... ', end="")

    request = calculator.evaluate_request()
    request.expression.literal = 123

    eval_promise = request.send()
    read_promise = eval_promise.value.read()
    response = read_promise.wait()
    assert response.value == 123

    print("PASS")

    '''Make a request to evaluate 123 + 45 - 67.
    #     //
    The Calculator interface requires that we first call getOperator() to
    get the addition and subtraction functions, then call evaluate() to use
    them.  But, once again, we can get both functions, call evaluate(), and
    then read() the result -- four RPCs -- in the time of *one* network
    round trip, because of promise pipelining.'''

    print("Using add and subtract... ", end='')
    add = calculator.getOperator(op='add').func
    subtract = calculator.getOperator(op='subtract').func

    request = calculator.evaluate_request()
    subtract_call = request.expression.init('call')
    subtract_call.function = subtract
    params = subtract_call.init('params', 2)
    params[1] = 67.0

if __name__ == '__main__':
    main()

