from random import random
import pyximport

importers = pyximport.install()
from common_fast import rand_int, rand_double, rand_bool

pyximport.uninstall(*importers)

WORDS = [
    "foo ",
    "bar ",
    "baz ",
    "qux ",
    "quux ",
    "corge ",
    "grault ",
    "garply ",
    "waldo ",
    "fred ",
    "plugh ",
    "xyzzy ",
    "thud ",
]


def from_bytes_helper(klass):
    def helper(text):
        obj = klass()
        obj.ParseFromString(text)
        return obj

    return helper


def pass_by_object(reuse, iters, benchmark):
    for _ in range(iters):
        request = benchmark.Request()
        expected = benchmark.setup(request)

        response = benchmark.Response()
        benchmark.handle(request, response)

        if not benchmark.check(response, expected):
            raise ValueError("Expected {}".format(expected))


def pass_by_bytes(reuse, iters, benchmark):
    for _ in range(iters):
        request = benchmark.Request()
        expected = benchmark.setup(request)
        req_bytes = benchmark.to_bytes(request)

        request2 = benchmark.from_bytes_request(req_bytes)
        response = benchmark.Response()
        benchmark.handle(request2, response)
        resp_bytes = benchmark.to_bytes(response)

        response2 = benchmark.from_bytes_response(resp_bytes)
        if not benchmark.check(response2, expected):
            raise ValueError("Expected {}".format(expected))


def do_benchmark(mode, *args, **kwargs):
    if mode == "client":
        pass
    elif mode == "object":
        return pass_by_object(*args, **kwargs)
    elif mode == "bytes":
        return pass_by_bytes(*args, **kwargs)
    else:
        raise ValueError("Unknown mode: " + str(mode))


#   typedef typename BenchmarkTypes::template BenchmarkMethods<TestCase, Reuse, Compression>
#       BenchmarkMethods;
#   if (mode == "client") {
#     return BenchmarkMethods::syncClient(STDIN_FILENO, STDOUT_FILENO, iters);
#   } else if (mode == "server") {
#     return BenchmarkMethods::server(STDIN_FILENO, STDOUT_FILENO, iters);
#   } else if (mode == "object") {
#     return BenchmarkMethods::passByObject(iters, false);
#   } else if (mode == "object-size") {
#     return BenchmarkMethods::passByObject(iters, true);
#   } else if (mode == "bytes") {
#     return BenchmarkMethods::passByBytes(iters);
#   } else if (mode == "pipe") {
#     return passByPipe<BenchmarkMethods>(BenchmarkMethods::syncClient, iters);
#   } else if (mode == "pipe-async") {
#     return passByPipe<BenchmarkMethods>(BenchmarkMethods::asyncClient, iters);
#   } else {
#     fprintf(stderr, "Unknown mode: %s\n", mode.c_str());
#     exit(1);
#   }
# }
