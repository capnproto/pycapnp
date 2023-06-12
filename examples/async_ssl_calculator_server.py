#!/usr/bin/env python3

import argparse
import asyncio
import logging
import os
import ssl
import socket

import capnp
import calculator_capnp


logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)

this_dir = os.path.dirname(os.path.abspath(__file__))


async def evaluate_impl(expression, params=None):
    """Implementation of CalculatorImpl::evaluate(), also shared by
    FunctionImpl::call().  In the latter case, `params` are the parameter
    values passed to the function; in the former case, `params` is just an
    empty list."""

    which = expression.which()

    if which == "literal":
        return expression.literal
    elif which == "previousResult":
        return (await expression.previousResult.read()).value
    elif which == "parameter":
        assert expression.parameter < len(params)
        return params[expression.parameter]
    elif which == "call":
        call = expression.call
        func = call.function

        # Evaluate each parameter.
        paramPromises = [evaluate_impl(param, params) for param in call.params]
        vals = await asyncio.gather(*paramPromises)

        # When the parameters are complete, call the function.
        result = await func.call(vals)
        return result.value
    else:
        raise ValueError("Unknown expression type: " + which)


class ValueImpl(calculator_capnp.Calculator.Value.Server):
    "Simple implementation of the Calculator.Value Cap'n Proto interface."

    def __init__(self, value):
        self.value = value

    async def read(self, **kwargs):
        return self.value


class FunctionImpl(calculator_capnp.Calculator.Function.Server):

    """Implementation of the Calculator.Function Cap'n Proto interface, where the
    function is defined by a Calculator.Expression."""

    def __init__(self, paramCount, body):
        self.paramCount = paramCount
        self.body = body.as_builder()

    async def call(self, params, _context, **kwargs):
        """Note that we're returning a Promise object here, and bypassing the
        helper functionality that normally sets the results struct from the
        returned object. Instead, we set _context.results directly inside of
        another promise"""

        assert len(params) == self.paramCount
        return await evaluate_impl(self.body, params)


class OperatorImpl(calculator_capnp.Calculator.Function.Server):

    """Implementation of the Calculator.Function Cap'n Proto interface, wrapping
    basic binary arithmetic operators."""

    def __init__(self, op):
        self.op = op

    async def call(self, params, **kwargs):
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

    async def evaluate(self, expression, _context, **kwargs):
        return ValueImpl(await evaluate_impl(expression))

    async def defFunction(self, paramCount, body, _context, **kwargs):
        return FunctionImpl(paramCount, body)

    async def getOperator(self, op, **kwargs):
        return OperatorImpl(op)


def parse_args():
    parser = argparse.ArgumentParser(
        usage="""Runs the server bound to the given address/port ADDRESS. """
    )

    parser.add_argument("address", help="ADDRESS:PORT")

    return parser.parse_args()


async def new_connection(stream):
    await capnp.TwoPartyServer(stream, bootstrap=CalculatorImpl()).on_disconnect()


async def main():
    host, port = parse_args().address.split(":")

    # Setup SSL context
    ctx = ssl.create_default_context(ssl.Purpose.CLIENT_AUTH)
    ctx.load_cert_chain(
        os.path.join(this_dir, "selfsigned.cert"),
        os.path.join(this_dir, "selfsigned.key"),
    )

    # Handle both IPv4 and IPv6 cases
    try:
        print("Try IPv4")
        server = await capnp.AsyncIoStream.create_server(
            new_connection, host, port, ssl=ctx, family=socket.AF_INET
        )
    except Exception:
        print("Try IPv6")
        server = await capnp.AsyncIoStream.create_server(
            new_connection, host, port, ssl=ctx, family=socket.AF_INET6
        )

    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    asyncio.run(main())
