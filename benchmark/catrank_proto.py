#!/usr/bin/env python

from common import rand_int, rand_double, rand_bool, WORDS, from_bytes_helper
from random import choice
from string import ascii_letters

try:
    # Python 2
    from itertools import izip
except ImportError:
    izip = zip
import catrank_pb2


class Benchmark:
    def __init__(self, compression):
        self.Request = catrank_pb2.SearchResultList
        self.Response = catrank_pb2.SearchResultList
        self.from_bytes_request = from_bytes_helper(catrank_pb2.SearchResultList)
        self.from_bytes_response = from_bytes_helper(catrank_pb2.SearchResultList)
        self.to_bytes = lambda x: x.SerializeToString()

    def setup(self, request):
        goodCount = 0
        count = rand_int(1000)

        for i in range(count):
            result = request.result.add()
            result.score = 1000 - i
            url_size = rand_int(100)
            result.url = "http://example.com/" + "".join(
                [choice(ascii_letters) for _ in range(url_size)]
            )

            isCat = rand_bool()
            isDog = rand_bool()
            if isCat and not isDog:
                goodCount += 1

            snippet = [choice(WORDS) for i in range(rand_int(20))]

            if isCat:
                snippet.append(" cat ")
            if isDog:
                snippet.append(" dog ")

            snippet += [choice(WORDS) for i in range(rand_int(20))]

            result.snippet = "".join(snippet)

        return goodCount

    def handle(self, request, response):
        for req in request.result:
            resp = response.result.add()
            score = req.score

            if " cat " in req.snippet:
                score *= 10000
            if " dog " in req.snippet:
                score /= 10000

            resp.score = score
            resp.url = req.url
            resp.snippet = req.snippet

    def check(self, response, expected):
        goodCount = 0

        for result in response.result:
            if result.score > 1001:
                goodCount += 1

        return goodCount == expected
