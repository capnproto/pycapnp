import pytest
import capnp
import os

this_dir = os.path.dirname(__file__)

@pytest.fixture
def addressbook():
     return capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

@pytest.fixture
def foo():
     return capnp.load(os.path.join(this_dir, 'foo.capnp'))

@pytest.fixture
def bar():
     return capnp.load(os.path.join(this_dir, 'bar.capnp'))

def test_basic_load():
    capnp.load(os.path.join(this_dir, 'addressbook.capnp'))

def test_constants(addressbook):
    assert addressbook.qux == 123

def test_classes(addressbook):
    assert addressbook.AddressBook
    assert addressbook.Person

def test_import(foo, bar):
    m = capnp.MallocMessageBuilder()
    foo = m.initRoot(foo.Foo)
    m2 = capnp.MallocMessageBuilder()
    bar = m2.initRoot(bar.Bar)

    foo.name = 'foo'
    bar.foo = foo

    assert bar.foo.name == 'foo'

def test_failed_import():
    s = capnp.SchemaParser()
    s2 = capnp.SchemaParser()

    foo = s.load(os.path.join(this_dir, 'foo.capnp'))
    bar = s2.load(os.path.join(this_dir, 'bar.capnp'))

    m = capnp.MallocMessageBuilder()
    foo = m.initRoot(foo.Foo)
    m2 = capnp.MallocMessageBuilder()
    bar = m2.initRoot(bar.Bar)

    foo.name = 'foo'

    with pytest.raises(ValueError):
        bar.foo = foo
