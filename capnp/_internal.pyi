"""Internal types for pycapnp stubs - NOT part of public API.

This module contains internal type definitions including:
- Protocol classes for schema nodes that exist in the pycapnp runtime
- TypeVars used in generic types
- Helper types for type annotations

These are imported by lib/capnp.pyi for type annotations but NOT re-exported.
"""

from __future__ import annotations

import asyncio
from typing import Any, Protocol, TypeVar
from capnp.lib.capnp import _SchemaType

# TypeVars used throughout the stubs
T = TypeVar("T")
T_co = TypeVar("T_co", covariant=True)
TReader = TypeVar("TReader")
TBuilder = TypeVar("TBuilder")
TInterface = TypeVar("TInterface")

# Protocol classes for types imported from capnp runtime

class EnumType(Protocol):
    typeId: int

class StructType(Protocol):
    typeId: int
    brand: Any

class InterfaceType(Protocol):
    typeId: int

class SlotRuntime(Protocol):
    type: Any

class SchemaNode(Protocol):
    id: int
    scopeId: int
    displayName: str
    displayNamePrefixLength: int
    isGeneric: bool
    nestedNodes: Any
    parameters: Any
    struct: Any
    enum: Any
    interface: Any
    const: Any
    annotation: Any

class CapnpTypesModule:
    Void: _SchemaType
    Bool: _SchemaType
    Int8: _SchemaType
    Int16: _SchemaType
    Int32: _SchemaType
    Int64: _SchemaType
    UInt8: _SchemaType
    UInt16: _SchemaType
    UInt32: _SchemaType
    UInt64: _SchemaType
    Float32: _SchemaType
    Float64: _SchemaType
    Text: _SchemaType
    Data: _SchemaType
    AnyPointer: _SchemaType

# Re-export commonly used types
Server = asyncio.Server
