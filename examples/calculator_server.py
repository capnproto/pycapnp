#!/usr/bin/env python3

import argparse
import capnp
import time

import calculator_capnp


def read_value(value):
    """Helper function to asynchronously call read() on a Calculator::Value and
    return a promise for the result.  (In the future, the generated code might
    include something like this automatically.)"""

    return value.read().then(lambda result: result.value)


def evaluate_impl(expression, params=None):
    """Implementation of CalculatorImpl::evaluate(), also shared by
    FunctionImpl::call().  In the latter case, `params` are the parameter
    values passed to the function; in the former case, `params` is just an
    empty list."""

    which = expression.which()

    if which == "literal":
        return capnp.Promise(expression.literal)
    elif which == "previousResult":
        return read_value(expression.previousResult)
    elif which == "parameter":
        assert expression.parameter < len(params)
        return capnp.Promise(params[expression.parameter])
    elif which == "call":
        call = expression.call
        func = call.function

        # Evaluate each parameter.
        paramPromises = [evaluate_impl(param, params) for param in call.params]

        joinedParams = capnp.join_promises(paramPromises)
        # When the parameters are complete, call the function.
        ret = joinedParams.then(lambda vals: func.call(vals)).then(
            lambda result: result.value
        )

        return ret
    else:
        raise ValueError("Unknown expression type: " + which)


class ValueImpl(calculator_capnp.Calculator.Value.Server):

    "Simple implementation of the Calculator.Value Cap'n Proto interface."

    def __init__(self, value):
        self.value = value

    def read(self, **kwargs):
        return self.value


class FunctionImpl(calculator_capnp.Calculator.Function.Server):

    """Implementation of the Calculator.Function Cap'n Proto interface, where the
    function is defined by a Calculator.Expression."""

    def __init__(self, paramCount, body):
        self.paramCount = paramCount
        self.body = body.as_builder()

    def call(self, params, _context, **kwargs):
        """Note that we're returning a Promise object here, and bypassing the
        helper functionality that normally sets the results struct from the
        returned object. Instead, we set _context.results directly inside of
        another promise"""

        assert len(params) == self.paramCount
        # using setattr because '=' is not allowed inside of lambdas
        return evaluate_impl(self.body, params).then(
            lambda value: setattr(_context.results, "value", value)
        )


class OperatorImpl(calculator_capnp.Calculator.Function.Server):

    """Implementation of the Calculator.Function Cap'n Proto interface, wrapping
    basic binary arithmetic operators."""

    def __init__(self, op):
        self.op = op

    def call(self, params, **kwargs):
        assert len(params) == 2

        op = self.op

        if op == "add":
            return params[0] + params[1]
        elif op == "subtract":
            return params[0] - params[1]
        elif op == "multiply":
            return params[0] * params[1]
        elif op == "divide":
            return params[0] / params[1]
        else:
            raise ValueError("Unknown operator")


class CalculatorImpl(calculator_capnp.Calculator.Server):

    "Implementation of the Calculator Cap'n Proto interface."

    def evaluate(self, expression, _context, **kwargs):
        return evaluate_impl(expression).then(
            lambda value: setattr(_context.results, "value", ValueImpl(value))
        )

    def defFunction(self, paramCount, body, _context, **kwargs):
        return FunctionImpl(paramCount, body)

    def getOperator(self, op, **kwargs):
        return OperatorImpl(op)


def parse_args():
    parser = argparse.ArgumentParser(
        usage="""Runs the server bound to the\
given address/port ADDRESS may be '*' to bind to all local addresses.\
:PORT may be omitted to choose a port automatically. """
    )

    parser.add_argument("address", help="ADDRESS[:PORT]")

    return parser.parse_args()


def main():
    address = parse_args().address

    server = capnp.TwoPartyServer(address, bootstrap=CalculatorImpl())
    while True:
        server.poll_once()
        time.sleep(0.001)


if __name__ == "__main__":
    main()
