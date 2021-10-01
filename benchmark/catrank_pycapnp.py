#!/usr/bin/env python

import capnp
import catrank_capnp
from common import rand_int, rand_double, rand_bool, WORDS
from random import choice
from string import ascii_letters

try:
    # Python 2
    from itertools import izip
except ImportError:
    izip = zip


class Benchmark:
    def __init__(self, compression):
        self.Request = catrank_capnp.SearchResultList.new_message
        self.Response = catrank_capnp.SearchResultList.new_message
        if compression == "packed":
            self.from_bytes_request = catrank_capnp.SearchResultList.from_bytes_packed
            self.from_bytes_response = catrank_capnp.SearchResultList.from_bytes_packed
            self.to_bytes = lambda x: x.to_bytes_packed()
        else:
            self.from_bytes_request = catrank_capnp.SearchResultList.from_bytes
            self.from_bytes_response = catrank_capnp.SearchResultList.from_bytes
            self.to_bytes = lambda x: x.to_bytes()

    def setup(self, request):
        goodCount = 0
        count = rand_int(1000)

        results = request.init("results", count)

        for i, result in enumerate(results):
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
        results = response.init("results", len(request.results))

        for req, resp in izip(request.results, results):
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

        for result in response.results:
            if result.score > 1001:
                goodCount += 1

        return goodCount == expected
