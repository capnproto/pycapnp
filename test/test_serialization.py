import warnings
from contextlib import contextmanager

import pytest
import capnp
import os
import platform
import test_regression
import tempfile
import pickle
import mmap
import sys

this_dir = os.path.dirname(__file__)


@pytest.fixture
def all_types():
    return capnp.load(os.path.join(this_dir, "all_types.capnp"))


def test_roundtrip_file(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write(f)

    f.seek(0)
    msg = all_types.TestAllTypes.read(f)
    test_regression.check_all_types(msg)


def test_roundtrip_file_packed(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write_packed(f)

    f.seek(0)
    msg = all_types.TestAllTypes.read_packed(f)
    test_regression.check_all_types(msg)


def test_roundtrip_bytes(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    message_bytes = msg.to_bytes()

    with all_types.TestAllTypes.from_bytes(message_bytes) as msg:
        test_regression.check_all_types(msg)


@pytest.mark.skipif(
    platform.python_implementation() == "PyPy",
    reason="TODO: Investigate why this works on CPython but fails on PyPy.",
)
def test_roundtrip_segments(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    segments = msg.to_segments()
    msg = all_types.TestAllTypes.from_segments(segments)
    test_regression.check_all_types(msg)


@pytest.mark.skipif(
    sys.version_info[0] < 3,
    reason="mmap doesn't implement the buffer interface under python 2.",
)
def test_roundtrip_bytes_mmap(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)

    with tempfile.TemporaryFile() as f:
        msg.write(f)
        length = f.tell()

        f.seek(0)
        memory = mmap.mmap(f.fileno(), length)

        with all_types.TestAllTypes.from_bytes(memory) as msg:
            test_regression.check_all_types(msg)


@pytest.mark.skipif(
    sys.version_info[0] < 3, reason="memoryview is a builtin on Python 3"
)
def test_roundtrip_bytes_buffer(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)

    b = msg.to_bytes()
    v = memoryview(b)
    try:
        with all_types.TestAllTypes.from_bytes(v) as msg:
            test_regression.check_all_types(msg)
    finally:
        v.release()


def test_roundtrip_bytes_fail(all_types):
    with pytest.raises(TypeError):
        with all_types.TestAllTypes.from_bytes(42) as _:
            pass


@pytest.mark.skipif(
    platform.python_implementation() == "PyPy",
    reason="This works in PyPy 4.0.1 but travisci's version of PyPy has some bug that fails this test.",
)
def test_roundtrip_bytes_packed(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    message_bytes = msg.to_bytes_packed()

    msg = all_types.TestAllTypes.from_bytes_packed(message_bytes)
    test_regression.check_all_types(msg)


@contextmanager
def _warnings(
    expected_count=2, expected_text="This message has already been written once."
):
    with warnings.catch_warnings(record=True) as w:
        yield

        assert len(w) == expected_count
        assert all(issubclass(x.category, UserWarning) for x in w), w
        assert all(expected_text in str(x.message) for x in w), w


def test_roundtrip_file_multiple(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write(f)
    with _warnings(2):
        msg.write(f)
        msg.write(f)

    f.seek(0)
    i = 0
    for msg in all_types.TestAllTypes.read_multiple(f):
        test_regression.check_all_types(msg)
        i += 1
    assert i == 3


def test_roundtrip_bytes_multiple(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)

    msgs = msg.to_bytes()
    with _warnings(2):
        msgs += msg.to_bytes()
        msgs += msg.to_bytes()

    i = 0
    for msg in all_types.TestAllTypes.read_multiple_bytes(msgs):
        test_regression.check_all_types(msg)
        i += 1
    assert i == 3


def test_roundtrip_file_multiple_packed(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write_packed(f)
    with _warnings(2):
        msg.write_packed(f)
        msg.write_packed(f)

    f.seek(0)
    i = 0
    for msg in all_types.TestAllTypes.read_multiple_packed(f):
        test_regression.check_all_types(msg)
        i += 1
    assert i == 3


def test_roundtrip_bytes_multiple_packed(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)

    msgs = msg.to_bytes_packed()
    with _warnings(2):
        msgs += msg.to_bytes_packed()
        msgs += msg.to_bytes_packed()

    i = 0
    for msg in all_types.TestAllTypes.read_multiple_bytes_packed(msgs):
        test_regression.check_all_types(msg)
        i += 1
    assert i == 3


def test_file_and_bytes(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write(f)

    f.seek(0)

    with _warnings(1):
        assert f.read() == msg.to_bytes()


def test_file_and_bytes_packed(all_types):
    f = tempfile.TemporaryFile()
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    msg.write_packed(f)

    f.seek(0)

    with _warnings(1):
        assert f.read() == msg.to_bytes_packed()


def test_pickle(all_types):
    msg = all_types.TestAllTypes.new_message()
    test_regression.init_all_types(msg)
    data = pickle.dumps(msg)
    msg2 = pickle.loads(data)

    test_regression.check_all_types(msg2)


def test_from_bytes_traversal_limit(all_types):
    size = 1024
    bld = all_types.TestAllTypes.new_message()
    bld.init("structList", size)
    data = bld.to_bytes()

    with all_types.TestAllTypes.from_bytes(data) as msg:
        with pytest.raises(capnp.KjException):
            for i in range(0, size):
                msg.structList[i].uInt8Field == 0

    with all_types.TestAllTypes.from_bytes(
        data, traversal_limit_in_words=2**62
    ) as msg:
        for i in range(0, size):
            assert msg.structList[i].uInt8Field == 0


def test_from_bytes_packed_traversal_limit(all_types):
    size = 1024
    bld = all_types.TestAllTypes.new_message()
    bld.init("structList", size)
    data = bld.to_bytes_packed()

    msg = all_types.TestAllTypes.from_bytes_packed(data)
    with pytest.raises(capnp.KjException):
        for i in range(0, size):
            msg.structList[i].uInt8Field == 0

    msg = all_types.TestAllTypes.from_bytes_packed(
        data, traversal_limit_in_words=2**62
    )
    for i in range(0, size):
        assert msg.structList[i].uInt8Field == 0
