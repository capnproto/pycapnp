import os
import pytest
import capnp
import sys
import gc


@pytest.fixture(scope="module")
def all_types():
    """Load the standard all_types.capnp schema."""
    directory = os.path.dirname(__file__)
    return capnp.load(os.path.join(directory, "all_types.capnp"))


def test_set_bytes_get_bytes(all_types):
    """
    Scenario 1: Set Byte -> Get Byte
    Verify standard behavior: writing bytes results in reading bytes.
    """
    msg = all_types.TestAllTypes.new_message()
    input_data = b"hello_world"

    # Set
    msg.dataField = input_data

    # Get
    output_data = msg.dataField

    # Verify
    assert isinstance(output_data, bytes)
    assert output_data == input_data


def test_set_view_get_bytes(all_types):
    """
    Scenario 2: Set View -> Get Byte
    Verify compatibility: Passing a memoryview sets the data,
    but standard attribute access returns a bytes copy.
    """
    msg = all_types.TestAllTypes.new_message()

    # Create a memoryview source
    raw_source = bytearray(b"view_source")
    view = memoryview(raw_source)

    # Set via memoryview
    msg.dataField = view

    # Get via standard attribute
    output_data = msg.dataField

    # Verify
    assert isinstance(output_data, bytes)
    assert output_data == b"view_source"


def test_set_bytes_get_view_and_modify(all_types):
    """
    Scenario 3: Set Byte -> Get View
    Verify the high-performance API get_data_as_view.
    The view must be writable and modifications must reflect in the message.
    """
    msg = all_types.TestAllTypes.new_message()

    # Initial write
    msg.dataField = b"ABCDE"

    # Get view via new API
    view = msg.get_data_as_view("dataField")

    # Verify view properties
    assert isinstance(view, memoryview)
    assert view.readonly is False
    assert view.tobytes() == b"ABCDE"

    # Verify in-place modification
    view[0] = ord("Z")  # Change 'A' to 'Z'

    # Verify modification is reflected in standard access
    assert msg.dataField == b"ZBCDE"


def test_reader_vs_builder_view(all_types):
    """
    Verify that Builder views are writable, but Reader views are read-only.
    """
    # 1. Builder phase
    builder = all_types.TestAllTypes.new_message()
    builder.dataField = b"test_rw"

    builder_view = builder.get_data_as_view("dataField")
    assert builder_view.readonly is False
    builder_view[0] = ord("T")  # Modification allowed

    # 2. Reader phase
    reader = builder.as_reader()

    # Standard Get
    assert reader.dataField == b"Test_rw"

    # Reader get_data_as_view
    reader_view = reader.get_data_as_view("dataField")
    assert isinstance(reader_view, memoryview)
    assert reader_view.readonly is True

    # Attempting to modify Reader view should raise TypeError
    with pytest.raises(TypeError):
        reader_view[0] = ord("X")


def test_nested_struct_data(all_types):
    """
    Verify that get_data_as_view works correctly on nested structs.
    """
    msg = all_types.TestAllTypes.new_message()

    # Initialize nested struct
    inner = msg.init("structField")
    inner.int32Field = 100
    inner.dataField = b"nested_data"

    # 1. Verify standard access
    assert msg.structField.dataField == b"nested_data"

    # 2. Verify nested get_data_as_view
    view = msg.structField.get_data_as_view("dataField")

    assert isinstance(view, memoryview)
    assert view.tobytes() == b"nested_data"

    # Modify nested data
    view[0] = ord("N")
    assert msg.structField.dataField == b"Nested_data"


def test_corner_cases_values(all_types):
    """
    Test edge cases: Empty bytes and binary data with nulls.
    """
    msg = all_types.TestAllTypes.new_message()

    # Case A: Empty Bytes
    msg.dataField = b""
    assert msg.dataField == b""
    view = msg.get_data_as_view("dataField")
    assert len(view) == 0

    # Case B: Binary data containing null bytes
    binary_data = b"\x00\xff\x00\x01"
    msg.dataField = binary_data
    assert msg.dataField == binary_data
    assert msg.get_data_as_view("dataField").tobytes() == binary_data


def test_error_wrong_type(all_types):
    """
    Test error handling: Calling get_data_as_view on non-Data fields.
    """
    msg = all_types.TestAllTypes.new_message()
    msg.int32Field = 123
    msg.textField = "I am text"

    # Attempt on Int field
    with pytest.raises(TypeError) as excinfo:
        msg.get_data_as_view("int32Field")
    assert "not a DATA field" in str(excinfo.value)

    # Attempt on Text field
    with pytest.raises(TypeError) as excinfo:
        msg.get_data_as_view("textField")
    assert "not a DATA field" in str(excinfo.value)


def test_error_missing_field(all_types):
    """
    Test error handling: Accessing a non-existent field name.
    """
    msg = all_types.TestAllTypes.new_message()

    # Accessing a missing field should raise AttributeError (standard Python behavior)
    with pytest.raises(AttributeError) as excinfo:
        msg.get_data_as_view("non_existent_field")

    # Optional: Verify the error message contains the field name
    assert "non_existent_field" in str(excinfo.value)


def test_view_keeps_message_alive(all_types):
    """
    Verify that a View keeps messages alive.
    """
    msg = all_types.TestAllTypes.new_message()
    expected_data = b"persistence_check"
    msg.dataField = expected_data

    initial_ref_count = sys.getrefcount(msg)
    view = msg.get_data_as_view("dataField")
    new_ref_count = sys.getrefcount(msg)

    assert (
        new_ref_count > initial_ref_count
    ), f"View failed to hold reference to Message! (Old: {initial_ref_count}, New: {new_ref_count})"
    print(
        f"\n[Ref Check] Success: Ref count increased from {initial_ref_count} to {new_ref_count}"
    )

    del msg
    gc.collect()

    assert view.tobytes() == expected_data
