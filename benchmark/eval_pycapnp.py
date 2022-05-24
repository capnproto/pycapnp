#!/usr/bin/env python

import capnp
import eval_capnp
from common import rand_int, rand_double, rand_bool
from random import choice

MAX_INT = 2**31 - 1
MIN_INT = -(2**31)

OPERATIONS = ["add", "subtract", "multiply", "divide", "modulus"]


def clamp(res):
    if res > MAX_INT:
        return MAX_INT
    elif res < MIN_INT:
        return MIN_INT
    else:
        return res


def div(a, b):
    if b == 0:
        return MAX_INT
    if a == MIN_INT and b == -1:
        return MAX_INT

    return a // b


def mod(a, b):
    if b == 0:
        return MAX_INT
    if a == MIN_INT and b == -1:
        return MAX_INT

    return a % b


def make_expression(exp, depth):
    exp.op = choice(OPERATIONS)

    if rand_int(8) < depth:
        left = rand_int(128) + 1
        exp.left.value = left
    else:
        left = make_expression(exp.left.init("expression"), depth + 1)

    if rand_int(8) < depth:
        right = rand_int(128) + 1
        exp.right.value = right
    else:
        right = make_expression(exp.right.init("expression"), depth + 1)

    op = exp.op
    if op == "add":
        return clamp(left + right)
    elif op == "subtract":
        return clamp(left - right)
    elif op == "multiply":
        return clamp(left * right)
    elif op == "divide":
        return div(left, right)
    elif op == "modulus":
        return mod(left, right)
    raise RuntimeError("op wasn't a valid value: " + str(op))


def evaluate_expression(exp):
    left = 0
    right = 0

    which = exp.left.which()
    if which == "value":
        left = exp.left.value
    elif which == "expression":
        left = evaluate_expression(exp.left.expression)

    which = exp.right.which()
    if which == "value":
        right = exp.right.value
    elif which == "expression":
        right = evaluate_expression(exp.right.expression)

    op = exp.op
    if op == "add":
        return clamp(left + right)
    elif op == "subtract":
        return clamp(left - right)
    elif op == "multiply":
        return clamp(left * right)
    elif op == "divide":
        return div(left, right)
    elif op == "modulus":
        return mod(left, right)
    raise RuntimeError("op wasn't a valid value: " + str(op))


class Benchmark:
    def __init__(self, compression):
        self.Request = eval_capnp.Expression.new_message
        self.Response = eval_capnp.EvaluationResult.new_message
        if compression == "packed":
            self.from_bytes_request = eval_capnp.Expression.from_bytes_packed
            self.from_bytes_response = eval_capnp.EvaluationResult.from_bytes_packed
            self.to_bytes = lambda x: x.to_bytes_packed()
        else:
            self.from_bytes_request = eval_capnp.Expression.from_bytes
            self.from_bytes_response = eval_capnp.EvaluationResult.from_bytes
            self.to_bytes = lambda x: x.to_bytes()

    def setup(self, request):
        return make_expression(request, 0)

    def handle(self, request, response):
        response.value = evaluate_expression(request)

    def check(self, response, expected):
        return response.value == expected
