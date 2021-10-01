# -*- coding: utf-8 -*-

import pytest
import capnp
import os
import math
import sys

this_dir = os.path.dirname(__file__)

if sys.version_info[0] < 3:
    EXPECT_BYTES = True
else:
    EXPECT_BYTES = False


@pytest.fixture
def addressbook():
    return capnp.load(os.path.join(this_dir, "addressbook.capnp"))


def test_addressbook_message_classes(addressbook):
    def writeAddressBook(fd):
        message = capnp._MallocMessageBuilder()
        addressBook = message.init_root(addressbook.AddressBook)
        people = addressBook.init("people", 2)

        alice = people[0]
        alice.id = 123
        alice.name = "Alice"
        alice.email = "alice@example.com"
        alicePhones = alice.init("phones", 1)
        alicePhones[0].number = "555-1212"
        alicePhones[0].type = "mobile"
        alice.employment.school = "MIT"

        bob = people[1]
        bob.id = 456
        bob.name = "Bob"
        bob.email = "bob@example.com"
        bobPhones = bob.init("phones", 2)
        bobPhones[0].number = "555-4567"
        bobPhones[0].type = "home"
        bobPhones[1].number = "555-7654"
        bobPhones[1].type = "work"
        bob.employment.unemployed = None

        capnp._write_packed_message_to_fd(fd, message)

    def printAddressBook(fd):
        message = capnp._PackedFdMessageReader(f)
        addressBook = message.get_root(addressbook.AddressBook)

        people = addressBook.people

        alice = people[0]
        assert alice.id == 123
        assert alice.name == "Alice"
        assert alice.email == "alice@example.com"
        alicePhones = alice.phones
        assert alicePhones[0].number == "555-1212"
        assert alicePhones[0].type == "mobile"
        assert alice.employment.school == "MIT"

        bob = people[1]
        assert bob.id == 456
        assert bob.name == "Bob"
        assert bob.email == "bob@example.com"
        bobPhones = bob.phones
        assert bobPhones[0].number == "555-4567"
        assert bobPhones[0].type == "home"
        assert bobPhones[1].number == "555-7654"
        assert bobPhones[1].type == "work"
        assert bob.employment.unemployed is None

    f = open("example", "w")
    writeAddressBook(f.fileno())

    f = open("example", "r")
    printAddressBook(f.fileno())


def test_addressbook(addressbook):
    def writeAddressBook(file):
        addresses = addressbook.AddressBook.new_message()
        people = addresses.init("people", 2)

        alice = people[0]
        alice.id = 123
        alice.name = "Alice"
        alice.email = "alice@example.com"
        alicePhones = alice.init("phones", 1)
        alicePhones[0].number = "555-1212"
        alicePhones[0].type = "mobile"
        alice.employment.school = "MIT"

        bob = people[1]
        bob.id = 456
        bob.name = "Bob"
        bob.email = "bob@example.com"
        bobPhones = bob.init("phones", 2)
        bobPhones[0].number = "555-4567"
        bobPhones[0].type = "home"
        bobPhones[1].number = "555-7654"
        bobPhones[1].type = "work"
        bob.employment.unemployed = None

        addresses.write(file)

    def printAddressBook(file):
        addresses = addressbook.AddressBook.read(file)

        people = addresses.people

        alice = people[0]
        assert alice.id == 123
        assert alice.name == "Alice"
        assert alice.email == "alice@example.com"
        alicePhones = alice.phones
        assert alicePhones[0].number == "555-1212"
        assert alicePhones[0].type == "mobile"
        assert alice.employment.school == "MIT"

        bob = people[1]
        assert bob.id == 456
        assert bob.name == "Bob"
        assert bob.email == "bob@example.com"
        bobPhones = bob.phones
        assert bobPhones[0].number == "555-4567"
        assert bobPhones[0].type == "home"
        assert bobPhones[1].number == "555-7654"
        assert bobPhones[1].type == "work"
        assert bob.employment.unemployed is None

    f = open("example", "w")
    writeAddressBook(f)

    f = open("example", "r")
    printAddressBook(f)


def test_addressbook_resizable(addressbook):
    def writeAddressBook(file):
        addresses = addressbook.AddressBook.new_message()
        people = addresses.init_resizable_list("people")

        alice = people.add()
        alice.id = 123
        alice.name = "Alice"
        alice.email = "alice@example.com"
        alicePhones = alice.init("phones", 1)
        alicePhones[0].number = "555-1212"
        alicePhones[0].type = "mobile"
        alice.employment.school = "MIT"

        bob = people.add()
        bob.id = 456
        bob.name = "Bob"
        bob.email = "bob@example.com"
        bobPhones = bob.init("phones", 2)
        bobPhones[0].number = "555-4567"
        bobPhones[0].type = "home"
        bobPhones[1].number = "555-7654"
        bobPhones[1].type = "work"
        bob.employment.unemployed = None

        people.finish()

        addresses.write(file)

    def printAddressBook(file):
        addresses = addressbook.AddressBook.read(file)

        people = addresses.people

        alice = people[0]
        assert alice.id == 123
        assert alice.name == "Alice"
        assert alice.email == "alice@example.com"
        alicePhones = alice.phones
        assert alicePhones[0].number == "555-1212"
        assert alicePhones[0].type == "mobile"
        assert alice.employment.school == "MIT"

        bob = people[1]
        assert bob.id == 456
        assert bob.name == "Bob"
        assert bob.email == "bob@example.com"
        bobPhones = bob.phones
        assert bobPhones[0].number == "555-4567"
        assert bobPhones[0].type == "home"
        assert bobPhones[1].number == "555-7654"
        assert bobPhones[1].type == "work"
        assert bob.employment.unemployed is None

    f = open("example", "w")
    writeAddressBook(f)

    f = open("example", "r")
    printAddressBook(f)


def test_addressbook_explicit_fields(addressbook):
    def writeAddressBook(file):
        addresses = addressbook.AddressBook.new_message()
        address_fields = addressbook.AddressBook.schema.fields
        person_fields = addressbook.Person.schema.fields
        phone_fields = addressbook.Person.PhoneNumber.schema.fields
        people = addresses._init_by_field(address_fields["people"], 2)

        alice = people[0]
        alice._set_by_field(person_fields["id"], 123)
        alice._set_by_field(person_fields["name"], "Alice")
        alice._set_by_field(person_fields["email"], "alice@example.com")
        alicePhones = alice._init_by_field(person_fields["phones"], 1)
        alicePhones[0]._set_by_field(phone_fields["number"], "555-1212")
        alicePhones[0]._set_by_field(phone_fields["type"], "mobile")
        employment = alice._get_by_field(person_fields["employment"])
        employment._set_by_field(
            addressbook.Person.Employment.schema.fields["school"], "MIT"
        )

        bob = people[1]
        bob._set_by_field(person_fields["id"], 456)
        bob._set_by_field(person_fields["name"], "Bob")
        bob._set_by_field(person_fields["email"], "bob@example.com")
        bobPhones = bob._init_by_field(person_fields["phones"], 2)
        bobPhones[0]._set_by_field(phone_fields["number"], "555-4567")
        bobPhones[0]._set_by_field(phone_fields["type"], "home")
        bobPhones[1]._set_by_field(phone_fields["number"], "555-7654")
        bobPhones[1]._set_by_field(phone_fields["type"], "work")
        employment = bob._get_by_field(person_fields["employment"])
        employment._set_by_field(
            addressbook.Person.Employment.schema.fields["unemployed"], None
        )

        addresses.write(file)

    def printAddressBook(file):
        addresses = addressbook.AddressBook.read(file)
        address_fields = addressbook.AddressBook.schema.fields
        person_fields = addressbook.Person.schema.fields
        phone_fields = addressbook.Person.PhoneNumber.schema.fields

        people = addresses._get_by_field(address_fields["people"])

        alice = people[0]
        assert alice._get_by_field(person_fields["id"]) == 123
        assert alice._get_by_field(person_fields["name"]) == "Alice"
        assert alice._get_by_field(person_fields["email"]) == "alice@example.com"
        alicePhones = alice._get_by_field(person_fields["phones"])
        assert alicePhones[0]._get_by_field(phone_fields["number"]) == "555-1212"
        assert alicePhones[0]._get_by_field(phone_fields["type"]) == "mobile"
        employment = alice._get_by_field(person_fields["employment"])
        employment._get_by_field(
            addressbook.Person.Employment.schema.fields["school"]
        ) == "MIT"

        bob = people[1]
        assert bob._get_by_field(person_fields["id"]) == 456
        assert bob._get_by_field(person_fields["name"]) == "Bob"
        assert bob._get_by_field(person_fields["email"]) == "bob@example.com"
        bobPhones = bob._get_by_field(person_fields["phones"])
        assert bobPhones[0]._get_by_field(phone_fields["number"]) == "555-4567"
        assert bobPhones[0]._get_by_field(phone_fields["type"]) == "home"
        assert bobPhones[1]._get_by_field(phone_fields["number"]) == "555-7654"
        assert bobPhones[1]._get_by_field(phone_fields["type"]) == "work"
        employment = bob._get_by_field(person_fields["employment"])
        employment._get_by_field(
            addressbook.Person.Employment.schema.fields["unemployed"]
        ) is None

    f = open("example", "w")
    writeAddressBook(f)

    f = open("example", "r")
    printAddressBook(f)


@pytest.fixture
def all_types():
    return capnp.load(os.path.join(this_dir, "all_types.capnp"))


# TODO:  These tests should be extended to:
# - Read each field in Python and assert that it is equal to the expected value.
# - Build an identical message using Python code and compare it to the golden.
#


def init_all_types(builder):
    builder.voidField = None
    builder.boolField = True
    builder.int8Field = -123
    builder.int16Field = -12345
    builder.int32Field = -12345678
    builder.int64Field = -123456789012345
    builder.uInt8Field = 234
    builder.uInt16Field = 45678
    builder.uInt32Field = 3456789012
    builder.uInt64Field = 12345678901234567890
    builder.float32Field = 1234.5
    builder.float64Field = -123e45
    builder.textField = "foo"
    builder.dataField = b"bar"

    subBuilder = builder.structField
    subBuilder.voidField = None
    subBuilder.boolField = True
    subBuilder.int8Field = -12
    subBuilder.int16Field = 3456
    subBuilder.int32Field = -78901234
    subBuilder.int64Field = 56789012345678
    subBuilder.uInt8Field = 90
    subBuilder.uInt16Field = 1234
    subBuilder.uInt32Field = 56789012
    subBuilder.uInt64Field = 345678901234567890
    subBuilder.float32Field = -1.25e-10
    subBuilder.float64Field = 345
    subBuilder.textField = "☃"
    subBuilder.dataField = b"qux"
    subSubBuilder = subBuilder.structField
    subSubBuilder.textField = "nested"
    subSubBuilder.structField.textField = "really nested"
    subBuilder.enumField = "baz"

    subBuilder.voidList = [None, None, None]
    subBuilder.boolList = [False, True, False, True, True]
    subBuilder.int8List = [12, -34, -0x80, 0x7F]
    subBuilder.int16List = [1234, -5678, -0x8000, 0x7FFF]
    subBuilder.int32List = [12345678, -90123456, -0x80000000, 0x7FFFFFFF]
    subBuilder.int64List = [
        123456789012345,
        -678901234567890,
        -0x8000000000000000,
        0x7FFFFFFFFFFFFFFF,
    ]
    subBuilder.uInt8List = [12, 34, 0, 0xFF]
    subBuilder.uInt16List = [1234, 5678, 0, 0xFFFF]
    subBuilder.uInt32List = [12345678, 90123456, 0, 0xFFFFFFFF]
    subBuilder.uInt64List = [123456789012345, 678901234567890, 0, 0xFFFFFFFFFFFFFFFF]
    subBuilder.float32List = [0, 1234567, 1e37, -1e37, 1e-37, -1e-37]
    subBuilder.float64List = [0, 123456789012345, 1e306, -1e306, 1e-306, -1e-306]
    subBuilder.textList = ["quux", "corge", "grault"]
    subBuilder.dataList = [b"garply", b"waldo", b"fred"]
    listBuilder = subBuilder.init("structList", 3)
    listBuilder[0].textField = "x structlist 1"
    listBuilder[1].textField = "x structlist 2"
    listBuilder[2].textField = "x structlist 3"
    subBuilder.enumList = ["qux", "bar", "grault"]

    builder.enumField = "corge"

    builder.init("voidList", 6)
    builder.boolList = [True, False, False, True]
    builder.int8List = [111, -111]
    builder.int16List = [11111, -11111]
    builder.int32List = [111111111, -111111111]
    builder.int64List = [1111111111111111111, -1111111111111111111]
    builder.uInt8List = [111, 222]
    builder.uInt16List = [33333, 44444]
    builder.uInt32List = [3333333333]
    builder.uInt64List = [11111111111111111111]
    builder.float32List = [5555.5, float("inf"), float("-inf"), float("nan")]
    builder.float64List = [7777.75, float("inf"), float("-inf"), float("nan")]
    builder.textList = ["plugh", "xyzzy", "thud"]
    builder.dataList = [b"oops", b"exhausted", b"rfc3092"]
    listBuilder = builder.init("structList", 3)
    listBuilder[0].textField = "structlist 1"
    listBuilder[1].textField = "structlist 2"
    listBuilder[2].textField = "structlist 3"
    builder.enumList = ["foo", "garply"]


def assert_almost(float1, float2):
    if float1 != float2:
        assert abs((float1 - float2) / float1) < 0.00001


def check_list(reader, expected):
    assert len(reader) == len(expected)
    for (i, v) in enumerate(expected):
        if type(v) is float:
            assert_almost(reader[i], v)
        else:
            assert reader[i] == v


def check_all_types(reader):
    assert reader.voidField is None
    assert reader.boolField
    assert reader.int8Field == -123
    assert reader.int16Field == -12345
    assert reader.int32Field == -12345678
    assert reader.int64Field == -123456789012345
    assert reader.uInt8Field == 234
    assert reader.uInt16Field == 45678
    assert reader.uInt32Field == 3456789012
    assert reader.uInt64Field == 12345678901234567890
    assert reader.float32Field == 1234.5
    assert_almost(reader.float64Field, -123e45)
    assert reader.textField == "foo"
    assert reader.dataField == b"bar"

    subReader = reader.structField
    assert subReader.voidField is None
    assert subReader.boolField
    assert subReader.int8Field == -12
    assert subReader.int16Field == 3456
    assert subReader.int32Field == -78901234
    assert subReader.int64Field == 56789012345678
    assert subReader.uInt8Field == 90
    assert subReader.uInt16Field == 1234
    assert subReader.uInt32Field == 56789012
    assert subReader.uInt64Field == 345678901234567890
    assert_almost(subReader.float32Field, -1.25e-10)
    assert subReader.float64Field == 345

    assert subReader.textField == "☃"
    # This assertion highlights the encoding we expect to see here, since
    # otherwise this appears a bit magical...
    if EXPECT_BYTES:
        assert len(subReader.textField) == 3
    else:
        assert len(subReader.textField) == 1

    assert subReader.dataField == b"qux"

    subSubReader = subReader.structField
    assert subSubReader.textField == "nested"
    assert subSubReader.structField.textField == "really nested"

    assert subReader.enumField == "baz"
    # Check that enums are hashable and can be used as keys in dicts
    # interchangably with their string version.
    assert hash(subReader.enumField) == hash("baz")
    assert {subReader.enumField: 17}.get(subReader.enumField) == 17
    assert {subReader.enumField: 17}.get("baz") == 17
    assert {"baz": 17}.get(subReader.enumField) == 17

    check_list(subReader.voidList, [None, None, None])
    check_list(subReader.boolList, [False, True, False, True, True])
    check_list(subReader.int8List, [12, -34, -0x80, 0x7F])
    check_list(subReader.int16List, [1234, -5678, -0x8000, 0x7FFF])
    check_list(subReader.int32List, [12345678, -90123456, -0x80000000, 0x7FFFFFFF])
    check_list(
        subReader.int64List,
        [123456789012345, -678901234567890, -0x8000000000000000, 0x7FFFFFFFFFFFFFFF],
    )
    check_list(subReader.uInt8List, [12, 34, 0, 0xFF])
    check_list(subReader.uInt16List, [1234, 5678, 0, 0xFFFF])
    check_list(subReader.uInt32List, [12345678, 90123456, 0, 0xFFFFFFFF])
    check_list(
        subReader.uInt64List, [123456789012345, 678901234567890, 0, 0xFFFFFFFFFFFFFFFF]
    )
    check_list(subReader.float32List, [0.0, 1234567.0, 1e37, -1e37, 1e-37, -1e-37])
    check_list(
        subReader.float64List, [0.0, 123456789012345.0, 1e306, -1e306, 1e-306, -1e-306]
    )
    check_list(subReader.textList, ["quux", "corge", "grault"])
    check_list(subReader.dataList, [b"garply", b"waldo", b"fred"])

    listReader = subReader.structList
    assert len(listReader) == 3
    assert listReader[0].textField == "x structlist 1"
    assert listReader[1].textField == "x structlist 2"
    assert listReader[2].textField == "x structlist 3"

    check_list(subReader.enumList, ["qux", "bar", "grault"])

    assert reader.enumField == "corge"

    assert len(reader.voidList) == 6
    check_list(reader.boolList, [True, False, False, True])
    check_list(reader.int8List, [111, -111])
    check_list(reader.int16List, [11111, -11111])
    check_list(reader.int32List, [111111111, -111111111])
    check_list(reader.int64List, [1111111111111111111, -1111111111111111111])
    check_list(reader.uInt8List, [111, 222])
    check_list(reader.uInt16List, [33333, 44444])
    check_list(reader.uInt32List, [3333333333])
    check_list(reader.uInt64List, [11111111111111111111])

    listReader = reader.float32List
    assert len(listReader) == 4
    assert listReader[0] == 5555.5
    assert listReader[1] == float("inf")
    assert listReader[2] == -float("inf")
    assert math.isnan(listReader[3])

    listReader = reader.float64List
    len(listReader) == 4
    assert listReader[0] == 7777.75
    assert listReader[1] == float("inf")
    assert listReader[2] == -float("inf")
    assert math.isnan(listReader[3])

    check_list(reader.textList, ["plugh", "xyzzy", "thud"])
    check_list(reader.dataList, [b"oops", b"exhausted", b"rfc3092"])

    listReader = reader.structList
    len(listReader) == 3
    assert listReader[0].textField == "structlist 1"
    assert listReader[1].textField == "structlist 2"
    assert listReader[2].textField == "structlist 3"

    check_list(reader.enumList, ["foo", "garply"])


def test_build(all_types):
    root = all_types.TestAllTypes.new_message()
    init_all_types(root)
    expectedText = open(
        os.path.join(this_dir, "all-types.txt"), "r", encoding="utf8"
    ).read()
    assert str(root) + "\n" == expectedText


def test_build_first_segment_size(all_types):
    root = all_types.TestAllTypes.new_message(1)
    init_all_types(root)
    expectedText = open(
        os.path.join(this_dir, "all-types.txt"), "r", encoding="utf8"
    ).read()
    assert str(root) + "\n" == expectedText

    root = all_types.TestAllTypes.new_message(1024 * 1024)
    init_all_types(root)
    expectedText = open(
        os.path.join(this_dir, "all-types.txt"), "r", encoding="utf8"
    ).read()
    assert str(root) + "\n" == expectedText


def test_binary_read(all_types):
    f = open(os.path.join(this_dir, "all-types.binary"), "r", encoding="utf8")
    root = all_types.TestAllTypes.read(f)
    check_all_types(root)

    expectedText = open(
        os.path.join(this_dir, "all-types.txt"), "r", encoding="utf8"
    ).read()
    assert str(root) + "\n" == expectedText

    # Test set_root().
    builder = capnp._MallocMessageBuilder()
    builder.set_root(root)
    check_all_types(builder.get_root(all_types.TestAllTypes))

    builder2 = capnp._MallocMessageBuilder()
    builder2.set_root(builder.get_root(all_types.TestAllTypes))
    check_all_types(builder2.get_root(all_types.TestAllTypes))


def test_packed_read(all_types):
    f = open(os.path.join(this_dir, "all-types.packed"), "r", encoding="utf8")
    root = all_types.TestAllTypes.read_packed(f)
    check_all_types(root)

    expectedText = open(
        os.path.join(this_dir, "all-types.txt"), "r", encoding="utf8"
    ).read()
    assert str(root) + "\n" == expectedText


def test_binary_write(all_types):
    root = all_types.TestAllTypes.new_message()
    init_all_types(root)
    root.write(open("example", "w"))

    check_all_types(all_types.TestAllTypes.read(open("example", "r")))


def test_packed_write(all_types):
    root = all_types.TestAllTypes.new_message()
    init_all_types(root)
    root.write_packed(open("example", "w"))

    check_all_types(all_types.TestAllTypes.read_packed(open("example", "r")))
