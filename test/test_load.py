import pytest
import capnp
import os
import sys

this_dir = os.path.dirname(__file__)


@pytest.fixture
def addressbook():
    return capnp.load(os.path.join(this_dir, "addressbook.capnp"))


@pytest.fixture
def foo():
    return capnp.load(os.path.join(this_dir, "foo.capnp"))


@pytest.fixture
def bar():
    return capnp.load(os.path.join(this_dir, "bar.capnp"))


def test_basic_load():
    capnp.load(os.path.join(this_dir, "addressbook.capnp"))


def test_constants(addressbook):
    assert addressbook.qux == 123


def test_classes(addressbook):
    assert addressbook.AddressBook
    assert addressbook.Person


def test_import(foo, bar):
    m = capnp._MallocMessageBuilder()
    foo = m.init_root(foo.Foo)
    m2 = capnp._MallocMessageBuilder()
    bar = m2.init_root(bar.Bar)

    foo.name = "foo"
    bar.foo = foo

    assert bar.foo.name == "foo"


def test_failed_import():
    s = capnp.SchemaParser()
    s2 = capnp.SchemaParser()

    foo = s.load(os.path.join(this_dir, "foo.capnp"))
    bar = s2.load(os.path.join(this_dir, "bar.capnp"))

    m = capnp._MallocMessageBuilder()
    foo = m.init_root(foo.Foo)
    m2 = capnp._MallocMessageBuilder()
    bar = m2.init_root(bar.Bar)

    foo.name = "foo"

    with pytest.raises(Exception):
        bar.foo = foo


def test_defualt_import_hook():
    # Make sure any previous imports of addressbook_capnp are gone
    capnp.cleanup_global_schema_parser()

    import addressbook_capnp  # noqa: F401


def test_dash_import():
    import addressbook_with_dashes_capnp  # noqa: F401


def test_spaces_import():
    import addressbook_with_spaces_capnp  # noqa: F401


def test_add_import_hook():
    capnp.add_import_hook([this_dir])

    # Make sure any previous imports of addressbook_capnp are gone
    capnp.cleanup_global_schema_parser()

    import addressbook_capnp

    addressbook_capnp.AddressBook.new_message()


def test_multiple_add_import_hook():
    capnp.add_import_hook()
    capnp.add_import_hook()
    capnp.add_import_hook([this_dir])

    # Make sure any previous imports of addressbook_capnp are gone
    capnp.cleanup_global_schema_parser()

    import addressbook_capnp

    addressbook_capnp.AddressBook.new_message()


def test_remove_import_hook():
    capnp.add_import_hook([this_dir])
    capnp.remove_import_hook()

    if "addressbook_capnp" in sys.modules:
        # hack to deal with it being imported already
        del sys.modules["addressbook_capnp"]

    with pytest.raises(ImportError):
        import addressbook_capnp  # noqa: F401


def test_bundled_import_hook():
    # stream.capnp should be bundled, or provided by the system capnproto
    capnp.add_import_hook()
    import stream_capnp  # noqa: F401
