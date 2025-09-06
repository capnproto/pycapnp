import os
import capnp
import base64
import pytest

this_dir = os.path.dirname(__file__)


@pytest.fixture
def blob_schema():
    return capnp.load(os.path.join(this_dir, "blob_test.capnp"))


def test_blob_to_dict(blob_schema):
    blob_value = b"hello world"
    blob = blob_schema.BlobTest(blob=blob_value)
    blob_dict = blob.to_dict(encode_bytes_as_base64=True)
    assert base64.b64decode(blob_dict["blob"]) == blob_value
    msg = blob_schema.BlobTest.new_message()
    msg.from_dict(blob_dict)
    assert blob.blob == blob_value
