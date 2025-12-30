#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import pytest
import capnp
import os
import struct

# ==========================================
# 1. 动态生成测试用的 Schema
# ==========================================

TEST_SCHEMA = """
@0x934efea7f017fff0;

struct Inner {
  val @0 :Int32;
  dataField @1 :Data;
}

struct TestAllTypes {
  # 基础 Data 字段
  dataField @0 :Data;

  # 用于测试类型检查的非 Data 字段
  intField @1 :Int32;
  textField @2 :Text;

  # 嵌套结构
  inner @3 :Inner;
}
"""


@pytest.fixture(scope="module")
def dynamic_schema():
    """在当前目录生成临时 capnp 文件，测试结束后清理"""
    schema_filename = "temp_test_schema.capnp"
    with open(schema_filename, "w") as f:
        f.write(TEST_SCHEMA)

    # 加载 Schema
    try:
        loaded_schema = capnp.load(schema_filename)
        yield loaded_schema
    finally:
        # 清理
        if os.path.exists(schema_filename):
            os.remove(schema_filename)


# ==========================================
# 2. 核心组合测试 (Core Combinations)
# ==========================================

def test_set_bytes_get_bytes(dynamic_schema):
    """
    场景 1: Set Byte -> Get Byte
    验证：标准用法，写入 bytes，读取回来必须是 bytes 类型
    """
    msg = dynamic_schema.TestAllTypes.new_message()
    input_data = b"hello_world"

    # Set
    msg.dataField = input_data

    # Get
    output_data = msg.dataField

    # 验证
    assert isinstance(output_data, bytes), "默认读取属性必须返回 bytes (拷贝副本)"
    assert output_data == input_data

    # 验证数据独立性 (修改读取出来的 bytes 不应影响底层)
    # output_data 是 bytes，本身不可变，所以这一条天然满足 Python 特性


def test_set_view_get_bytes(dynamic_schema):
    """
    场景 2: Set View -> Get Byte
    验证：兼容性用法。用户传入 memoryview (触发 _setMemoryviewField)，
    读取时依然得到 bytes (触发 to_python 返回 bytes)
    """
    msg = dynamic_schema.TestAllTypes.new_message()

    # 创建一个 memoryview 数据源
    raw_source = bytearray(b"view_source")
    view = memoryview(raw_source)

    # Set: 传入 memoryview
    msg.dataField = view

    # Get: 普通属性访问
    output_data = msg.dataField

    # 验证
    assert isinstance(output_data, bytes), "即使 Set 的是 view，Get 也必须统一返回 bytes"
    assert output_data == b"view_source"


def test_set_bytes_get_view(dynamic_schema):
    """
    场景 3: Set Byte -> Get View
    验证：Builder 模式下的高性能 API get_data_as_view
    关键点：View 应该是可写 (Writable) 的，且修改能反映到底层
    """
    msg = dynamic_schema.TestAllTypes.new_message()

    # 初始写入 bytes
    msg.dataField = b"ABCDE"

    # 调用新 API 获取 View
    view = msg.get_data_as_view("dataField")

    # 验证 View 属性
    assert isinstance(view, memoryview)
    assert view.readonly is False, "Builder 获取的 View 必须是可写的"
    assert view.tobytes() == b"ABCDE"

    # 验证原地修改 (In-place modification)
    view[0] = ord('Z')  # 把 'A' 改成 'Z'

    # 再次读取验证修改是否生效
    assert msg.dataField == b"ZBCDE", "View 的修改未能同步到底层数据"


def test_set_view_get_view(dynamic_schema):
    """
    场景 4: Set View -> Get View
    验证：全链路零拷贝逻辑 (逻辑上)
    """
    msg = dynamic_schema.TestAllTypes.new_message()

    # 输入 View
    src = memoryview(b"12345")
    msg.dataField = src

    # 输出 View
    view = msg.get_data_as_view("dataField")

    assert isinstance(view, memoryview)
    assert view.tobytes() == b"12345"
    assert view.readonly is False


# ==========================================
# 3. Reader 与 Builder 的差异测试
# ==========================================

def test_reader_vs_builder_view(dynamic_schema):
    """
    验证：Builder 的 View 可写，Reader 的 View 只读
    """
    # 1. Builder 阶段
    builder = dynamic_schema.TestAllTypes.new_message()
    builder.dataField = b"test_rw"

    builder_view = builder.get_data_as_view("dataField")
    assert builder_view.readonly is False
    builder_view[0] = ord('T')  # 修改通过

    # 2. 转为 Reader 阶段
    reader = builder.as_reader()

    # 普通 Get
    assert reader.dataField == b"Test_rw"
    assert isinstance(reader.dataField, bytes)

    # Reader 的 get_data_as_view
    reader_view = reader.get_data_as_view("dataField")
    assert isinstance(reader_view, memoryview)
    assert reader_view.readonly is True, "Reader 获取的 View 必须是只读的"

    # 尝试修改 Reader View 应该报错
    with pytest.raises(TypeError):
        reader_view[0] = ord('X')


# ==========================================
# 4. 嵌套结构测试 (Nested Structs)
# ==========================================

def test_nested_struct_data(dynamic_schema):
    """
    验证：嵌套在内部 Struct 中的 Data 字段能否正常工作
    """
    msg = dynamic_schema.TestAllTypes.new_message()

    # 初始化嵌套结构
    inner = msg.init("inner")
    inner.val = 100
    inner.dataField = b"nested_data"

    # 1. 验证普通读取
    assert msg.inner.dataField == b"nested_data"

    # 2. 验证嵌套结构的 get_data_as_view
    # 注意：调用是在 inner 对象上，而不是 msg 对象上
    view = msg.inner.get_data_as_view("dataField")

    assert isinstance(view, memoryview)
    assert view.tobytes() == b"nested_data"

    # 修改嵌套数据
    view[0] = ord('N')
    assert msg.inner.dataField == b"Nested_data"


# ==========================================
# 5. Corner Cases & Error Handling
# ==========================================

def test_corner_cases_values(dynamic_schema):
    """
    测试边界值：空数据、大以数据
    """
    msg = dynamic_schema.TestAllTypes.new_message()

    # Case A: 空 Bytes
    msg.dataField = b""
    assert msg.dataField == b""
    view = msg.get_data_as_view("dataField")
    assert len(view) == 0

    # Case B: 包含 Null 字节的二进制数据
    binary_data = b"\x00\xff\x00\x01"
    msg.dataField = binary_data
    assert msg.dataField == binary_data
    assert msg.get_data_as_view("dataField").tobytes() == binary_data


def test_error_wrong_type(dynamic_schema):
    """
    测试错误处理：对非 Data 类型的字段调用 get_data_as_view
    预期：TypeError
    """
    msg = dynamic_schema.TestAllTypes.new_message()
    msg.intField = 123
    msg.textField = "I am text"

    # 尝试对 Int 字段调用
    with pytest.raises(TypeError) as excinfo:
        msg.get_data_as_view("intField")
    assert "not a DATA field" in str(excinfo.value)

    # 尝试对 Text 字段调用 (Text 底层也是指针，但类型 ID 不同)
    with pytest.raises(TypeError) as excinfo:
        msg.get_data_as_view("textField")
    assert "not a DATA field" in str(excinfo.value)


def test_error_missing_field(dynamic_schema):
    """
    测试错误处理：调用不存在的字段名
    预期：KjException (由 C++ 抛出) 转换为 Python 异常
    """
    msg = dynamic_schema.TestAllTypes.new_message()

    with pytest.raises(capnp.KjException):
        msg.get_data_as_view("non_existent_field")


# ==========================================
# 6. 自定义 Allocator 测试 (参考你原本的测试)
# ==========================================

def test_custom_allocator_integration(dynamic_schema):
    """
    验证：自定义分配器与新特性的结合
    """

    class Allocator:
        def __call__(self, size):
            return bytearray(size * 8)

    msg = capnp._PyCustomMessageBuilder(Allocator())
    struct_builder = msg.init_root(dynamic_schema.TestAllTypes)

    # 即使在自定义分配器下，Data 行为也应一致
    struct_builder.dataField = b"allocator_test"

    assert struct_builder.dataField == b"allocator_test"

    view = struct_builder.get_data_as_view("dataField")
    view[0] = ord('A')

    assert struct_builder.dataField == b"Allocator_test"


if __name__ == "__main__":
    import sys

    sys.exit(pytest.main(["-v", __file__]))