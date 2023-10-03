import pytest

import capnp
import test_response_capnp


@pytest.fixture(autouse=True)
async def kj_loop():
    async with capnp.kj_loop():
        yield


class FooServer(test_response_capnp.Foo.Server):
    def __init__(self, val=1):
        self.val = val

    async def foo(self, **kwargs):
        return 1


class BazServer(test_response_capnp.Baz.Server):
    def __init__(self, val=1):
        self.val = val

    async def grault(self, **kwargs):
        return {"foo": FooServer()}


async def test_response_reference():
    baz = test_response_capnp.Baz._new_client(BazServer())

    bar = (await baz.grault()).bar

    foo = bar.foo
    # This used to cause an exception about invalid pointers because the response got garbage collected
    assert (await foo.foo()).val == 1


async def test_response_reference2():
    baz = test_response_capnp.Baz._new_client(BazServer())

    bar = (await baz.grault()).bar

    # This always worked since it saved the intermediate response object
    response = await baz.grault()
    bar = response.bar
    foo = bar.foo
    assert (await foo.foo()).val == 1
