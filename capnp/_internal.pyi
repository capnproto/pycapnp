"""Internal types for pycapnp stubs - NOT part of public API.

This module contains all internal type definitions including:
- Protocol classes for schema nodes
- TypeVars used in generic types
- Helper types for type annotations
- Types from imports (asyncio, ModuleType, etc.)

These are imported by __init__.pyi for type annotations but NOT re-exported.
"""

from __future__ import annotations

import asyncio
from collections.abc import Iterator, Mapping, Sequence
from types import ModuleType
from typing import Any, Generic, Protocol, TypeVar

# TypeVars used throughout the stubs
T = TypeVar("T")
T_co = TypeVar("T_co", covariant=True)
TReader = TypeVar("TReader")
TBuilder = TypeVar("TBuilder")
TInterface = TypeVar("TInterface")

# Protocol classes for schema introspection

class NestedNode(Protocol):
    name: str
    id: int

class ParameterNode(Protocol):
    name: str

class Enumerant(Protocol):
    name: str

class EnumNode(Protocol):
    enumerants: Sequence[Enumerant]

class AnyPointerParameter(Protocol):
    parameterIndex: int
    scopeId: int

class AnyPointerType(Protocol):
    def which(self) -> str: ...
    parameter: AnyPointerParameter

class BrandBinding(Protocol):
    type: TypeReader

class BrandScope(Protocol):
    def which(self) -> str: ...
    scopeId: int
    bind: Sequence[BrandBinding]

class Brand(Protocol):
    scopes: Sequence[BrandScope]

class ListElementType(Protocol):
    elementType: TypeReader

class ListType(ListElementType, Protocol): ...

class EnumType(Protocol):
    typeId: int

class StructType(Protocol):
    typeId: int
    brand: Brand

class InterfaceType(Protocol):
    typeId: int

class TypeReader(Protocol):
    def which(self) -> str: ...
    list: ListType
    enum: EnumType
    struct: StructType
    interface: InterfaceType
    anyPointer: AnyPointerType
    elementType: TypeReader

class SlotNode(Protocol):
    type: TypeReader

class FieldNode(Protocol):
    name: str
    slot: SlotNode
    discriminantValue: int
    def which(self) -> str: ...

class StructNode(Protocol):
    fields: Sequence[FieldNode]
    discriminantCount: int

class ConstNode(Protocol):
    type: TypeReader

class InterfaceNode(Protocol):
    methods: Sequence[InterfaceMethod]
    superclasses: Sequence[SuperclassNode]

class SuperclassNode(Protocol):
    id: int

class SchemaNode(Protocol):
    id: int
    scopeId: int
    displayName: str
    displayNamePrefixLength: int
    nestedNodes: Sequence[NestedNode]
    parameters: Sequence[ParameterNode]
    isGeneric: bool
    struct: StructNode
    enum: EnumNode
    const: ConstNode
    interface: InterfaceNode
    def which(self) -> str: ...

class DefaultValueReader(Protocol):
    def as_bool(self) -> bool: ...
    def __str__(self) -> str: ...

class StructRuntime(Protocol):
    fields_list: Sequence[Any]

class StructSchema(Protocol, Generic[TReader, TBuilder]):
    node: SchemaNode
    elementType: TypeReader
    def as_struct(self) -> StructRuntime: ...
    def get_nested(self, name: str) -> StructSchema: ...

class ListSchema(Protocol):
    node: SchemaNode
    elementType: TypeReader
    def as_struct(self) -> StructRuntime: ...
    def get_nested(self, name: str) -> StructSchema: ...

class DynamicListReader(Protocol):
    elementType: TypeReader
    list: DynamicListReader

class SlotRuntime(Protocol):
    type: TypeReader

class InterfaceMethod(Protocol):
    param_type: StructSchema
    result_type: StructSchema

class InterfaceSchema(Protocol):
    methods: Mapping[str, InterfaceMethod]

class InterfaceRuntime(Protocol):
    schema: InterfaceSchema

class CastableBootstrap(Protocol):
    def cast_as(self, interface: type[TInterface]) -> TInterface: ...

class StructModule(Protocol, Generic[TReader, TBuilder]):
    schema: StructSchema[TReader, TBuilder]

# Re-export commonly used types with underscore prefix for internal use
ModuleType = ModuleType
Server = asyncio.Server
