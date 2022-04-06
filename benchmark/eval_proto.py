#!/usr/bin/env python

from common import rand_int, rand_double, rand_bool, from_bytes_helper
from random import choice
import eval_pb2

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
    exp.op = rand_int(len(OPERATIONS))

    if rand_int(8) < depth:
        left = rand_int(128) + 1
        exp.left_value = left
    else:
        left = make_expression(exp.left_expression, depth + 1)

    if rand_int(8) < depth:
        right = rand_int(128) + 1
        exp.right_value = right
    else:
        right = make_expression(exp.right_expression, depth + 1)

    op = exp.op
    if op == 0:
        return clamp(left + right)
    elif op == 1:
        return clamp(left - right)
    elif op == 2:
        return clamp(left * right)
    elif op == 3:
        return div(left, right)
    elif op == 4:
        return mod(left, right)
    raise RuntimeError("op wasn't a valid value: " + str(op))


def evaluate_expression(exp):
    left = 0
    right = 0

    if exp.HasField("left_value"):
        left = exp.left_value
    else:
        left = evaluate_expression(exp.left_expression)

    if exp.HasField("right_value"):
        right = exp.right_value
    else:
        right = evaluate_expression(exp.right_expression)

    op = exp.op
    if op == 0:
        return clamp(left + right)
    elif op == 1:
        return clamp(left - right)
    elif op == 2:
        return clamp(left * right)
    elif op == 3:
        return div(left, right)
    elif op == 4:
        return mod(left, right)
    raise RuntimeError("op wasn't a valid value: " + str(op))


class Benchmark:
    def __init__(self, compression):
        self.Request = eval_pb2.Expression
        self.Response = eval_pb2.EvaluationResult
        self.from_bytes_request = from_bytes_helper(eval_pb2.Expression)
        self.from_bytes_response = from_bytes_helper(eval_pb2.EvaluationResult)
        self.to_bytes = lambda x: x.SerializeToString()

    def setup(self, request):
        return make_expression(request, 0)

    def handle(self, request, response):
        response.value = evaluate_expression(request)

    def check(self, response, expected):
        return response.value == expected
