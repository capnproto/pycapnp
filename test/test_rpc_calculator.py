import gc
import os
import pytest
import socket
import sys  # add examples dir to sys.path

import capnp

examples_dir = os.path.join(os.path.dirname(__file__), "..", "examples")
sys.path.append(examples_dir)

import calculator_client  # noqa: E402
import calculator_server  # noqa: E402

# Uses run_subprocesses function
import test_examples  # noqa: E402

processes = []


@pytest.fixture
def cleanup():
    yield
    for p in processes:
        p.kill()


def test_calculator():
    read, write = socket.socketpair()

    _ = capnp.TwoPartyServer(write, bootstrap=calculator_server.CalculatorImpl())
    calculator_client.main(read)


@pytest.mark.xfail(
    reason="Some versions of python don't like to share ports, don't worry if this fails"
)
def test_calculator_tcp(cleanup):
    address = "localhost:36431"
    test_examples.run_subprocesses(
        address, "calculator_server.py", "calculator_client.py", wildcard_server=True
    )


@pytest.mark.xfail(
    reason="Some versions of python don't like to share ports, don't worry if this fails"
)
@pytest.mark.skipif(os.name == "nt", reason="socket.AF_UNIX not supported on Windows")
def test_calculator_unix(cleanup):
    path = "/tmp/pycapnp-test"
    try:
        os.unlink(path)
    except OSError:
        pass

    address = "unix:" + path
    test_examples.run_subprocesses(
        address, "calculator_server.py", "calculator_client.py"
    )


def test_calculator_gc():
    def new_evaluate_impl(old_evaluate_impl):
        def call(*args, **kwargs):
            gc.collect()
            return old_evaluate_impl(*args, **kwargs)

        return call

    read, write = socket.socketpair()

    # inject a gc.collect to the beginning of every evaluate_impl call
    evaluate_impl_orig = calculator_server.evaluate_impl
    calculator_server.evaluate_impl = new_evaluate_impl(evaluate_impl_orig)

    _ = capnp.TwoPartyServer(write, bootstrap=calculator_server.CalculatorImpl())
    calculator_client.main(read)

    calculator_server.evaluate_impl = evaluate_impl_orig
