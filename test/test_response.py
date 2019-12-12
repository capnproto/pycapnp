import test_response_capnp


class FooServer(test_response_capnp.Foo.Server):
    def __init__(self, val=1):
        self.val = val

    def foo(self, **kwargs):
        return 1


class BazServer(test_response_capnp.Baz.Server):
    def __init__(self, val=1):
        self.val = val

    def grault(self, **kwargs):
        return {"foo": FooServer()}


def test_response_reference():
    baz = test_response_capnp.Baz._new_client(BazServer())

    bar = baz.grault().wait().bar

    foo = bar.foo
    # This used to cause an exception about invalid pointers because the response got garbage collected
    assert foo.foo().wait().val == 1


def test_response_reference2():
    baz = test_response_capnp.Baz._new_client(BazServer())

    bar = baz.grault().wait().bar

    # This always worked since it saved the intermediate response object
    response = baz.grault().wait()
    bar = response.bar
    foo = bar.foo
    assert foo.foo().wait().val == 1
