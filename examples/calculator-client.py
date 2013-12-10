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

    def call(self, params, **kwargs):
        '''Note the **kwargs. This is very necessary to include, since protocols can add parameters over time. Also, by default, a _context variable is passed to all server methods. Read the docs for further explanation.'''
        return pow(params[0], params[1])

def parse_args():
    parser = argparse.ArgumentParser('Connects to the Calculator server at the given address and does some RPCs')
    parser.add_argument("host", help="HOST:PORT")

    return parser.parse_args()

def main():
    host, port = parse_args().host.split(':')

    sock = socket.create_connection((host, port))
    client = capnp.RpcClient(sock)

    # Pass "calculator" to ez_restore (there's also a `restore` function that takes a struct or AnyPointer as an argument), and then cast the returned capability to it's proper type. This casting is due to capabilities not having a reference to their schema
    calculator = client.ez_restore('calculator').cast_as(calculator_capnp.Calculator)

    '''Make a request that just evaluates the literal value 123.

    What's interesting here is that evaluate() returns a "Value", which is
    another interface and therefore points back to an object living on the
    server.  We then have to call read() on that object to read it.
    However, even though we are making two RPC's, this block executes in
    *one* network round trip because of promise pipelining:  we do not wait
    for the first call to complete before we send the second call to the
    server.'''

    print('Evaluating a literal... ', end="")

    # Set up the request. Note the form is 'evaluate' + '_request', where 'evaluate' is the name of the method we want to call
    request = calculator.evaluate_request()
    request.expression.literal = 123

    # Send it, which returns a promise for the result (without blocking).
    eval_promise = request.send()

    # Using the promise, create a pipelined request to call read() on the returned object. Note that here we are using the shortened method call syntax read(), which is mostly just sugar for read_request().send()
    read_promise = eval_promise.value.read()

    # Now that we've sent all the requests, wait for the response.  Until this
    # point, we haven't waited at all!
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

    # Get the "add" function from the server.
    add = calculator.getOperator(op='add').func
    # Get the "subtract" function from the server.
    subtract = calculator.getOperator(op='subtract').func

    # Build the request to evaluate 123 + 45 - 67.
    request = calculator.evaluate_request()
    subtract_call = request.expression.init('call')
    subtract_call.function = subtract
    subtract_params = subtract_call.init('params', 2)
    subtract_params[1].literal = 67.0

    add_call = subtract_params[0].init('call')
    add_call.function = add
    add_params = add_call.init('params', 2)
    add_params[0].literal = 123
    add_params[1].literal = 45

    # Send the evaluate() request, read() the result, and wait for read() to finish.
    eval_promise = request.send()
    read_promise = eval_promise.value.read()

    response = read_promise.wait()
    assert response.value == 101

    print("PASS")


    '''Make a request to evaluate 4 * 6, then use the result in two more
    requests that add 3 and 5.

    Since evaluate() returns its result wrapped in a `Value`, we can pass
    that `Value` back to the server in subsequent requests before the first
    `evaluate()` has actually returned.  Thus, this example again does only
    one network round trip.'''

    print("Pipelining eval() calls... ", end="")

    # Get the "add" function from the server.
    add = calculator.getOperator(op='add').func
    # Get the "multiply" function from the server.
    multiply = calculator.getOperator(op='multiply').func


    # Build the request to evaluate 4 * 6
    request = calculator.evaluate_request()

    multiply_call = request.expression.init("call")
    multiply_call.function = multiply
    multiply_params = multiply_call.init("params", 2);
    multiply_params[0].literal = 4
    multiply_params[1].literal = 6

    multiply_result = request.send().value

    # Use the result in two calls that add 3 and add 5.

    add3Request = calculator.evaluate_request()
    add3Call = add3Request.expression.init("call")
    add3Call.function = add
    add3Params = add3Call.init("params", 2)
    add3Params[0].previousResult = multiply_result
    add3Params[1].literal = 3
    add3Promise = add3Request.send().value.read()

    add5Request = calculator.evaluate_request()
    add5Call = add5Request.expression.init("call")
    add5Call.function = add
    add5Params = add5Call.init("params", 2)
    add5Params[0].previousResult = multiply_result
    add5Params[1].literal = 5
    add5Promise = add5Request.send().value.read()

    # Now wait for the results.
    assert add3Promise.wait().value == 27
    assert add5Promise.wait().value == 29

    print("PASS")

    '''Our calculator interface supports defining functions.  Here we use it
    to define two functions and then make calls to them as follows:

      f(x, y) = x * 100 + y
      g(x) = f(x, x + 1) * 2;
      f(12, 34)
      g(21)

    Once again, the whole thing takes only one network round trip.'''

    print("Defining functions... ", end="")

    # Get the "add" function from the server.
    add = calculator.getOperator(op='add').func
    # Get the "multiply" function from the server.
    multiply = calculator.getOperator(op='multiply').func

    # Define f.
    request = calculator.defFunction_request()
    request.paramCount = 2

    # Build the function body.
    addCall = request.body.init("call")
    addCall.function = add
    addParams = addCall.init("params", 2)
    addParams[1].parameter = 1  # y

    multiplyCall = addParams[0].init("call")
    multiplyCall.function = multiply
    multiplyParams = multiplyCall.init("params", 2)
    multiplyParams[0].parameter = 0 # x
    multiplyParams[1].literal = 100

    f = request.send().func

    # Define g.
    request = calculator.defFunction_request()
    request.paramCount = 1

    # Build the function body.
    multiplyCall = request.body.init("call")
    multiplyCall.function = multiply
    multiplyParams = multiplyCall.init("params", 2)
    multiplyParams[1].literal = 2

    fCall = multiplyParams[0].init("call")
    fCall.function = f
    fParams = fCall.init("params", 2)
    fParams[0].parameter = 0

    addCall = fParams[1].init("call")
    addCall.function = add
    addParams = addCall.init("params", 2)
    addParams[0].parameter = 0
    addParams[1].literal = 1

    g = request.send().func

    # OK, we've defined all our functions.  Now create our eval requests.

    # f(12, 34)
    fEvalRequest = calculator.evaluate_request()
    fCall = fEvalRequest.expression.init("call")
    fCall.function = f
    fParams = fCall.init("params", 2)
    fParams[0].literal = 12
    fParams[1].literal = 34
    fEvalPromise = fEvalRequest.send().value.read()

    # g(21)
    gEvalRequest = calculator.evaluate_request()
    gCall = gEvalRequest.expression.init("call")
    gCall.function = g
    gCall.init('params', 1)[0].literal = 21
    gEvalPromise = gEvalRequest.send().value.read()

    # Wait for the results.
    assert fEvalPromise.wait().value == 1234
    assert gEvalPromise.wait().value == 4244

    print("PASS")

    '''Make a request that will call back to a function defined locally.

    Specifically, we will compute 2^(4 + 5).  However, exponent is not
    defined by the Calculator server.  So, we'll implement the Function
    interface locally and pass it to the server for it to use when
    evaluating the expression.

    This example requires two network round trips to complete, because the
    server calls back to the client once before finishing.  In this
    particular case, this could potentially be optimized by using a tail
    call on the server side -- see CallContext::tailCall().  However, to
    keep the example simpler, we haven't implemented this optimization in
    the sample server.'''

    print("Using a callback... ", end="")

    # Get the "add" function from the server.
    add = calculator.getOperator(op='add').func

    # Build the eval request for 2^(4+5).
    request = calculator.evaluate_request()

    powCall = request.expression.init("call")
    powCall.function = PowerFunction()
    powParams = powCall.init("params", 2)
    powParams[0].literal = 2

    addCall = powParams[1].init("call")
    addCall.function = add
    addParams = addCall.init("params", 2)
    addParams[0].literal = 4
    addParams[1].literal = 5

    # Send the request and wait.
    response = request.send().value.read().wait()
    assert response.value == 512

    print("PASS")

if __name__ == '__main__':
    main()
