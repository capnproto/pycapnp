"""Internal types for pycapnp stubs - NOT part of public API.

This module contains internal type definitions including:
- Protocol classes for schema nodes that exist in the pycapnp runtime
- TypeVars used in generic types
- Helper types for type annotations

These are imported by lib/capnp.pyi for type annotations but NOT re-exported.
"""

from __future__ import annotations

import asyncio
from collections.abc import Mapping
from types import ModuleType
from typing import Any, Generic, Protocol, TypeVar

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

class InterfaceType(Protocol):
    typeId: int

class SlotRuntime(Protocol): ...

class SchemaNode(Protocol):
    id: int
    scopeId: int
    displayName: str
    displayNamePrefixLength: int
    isGeneric: bool
    def which(self) -> str: ...

class StructSchema(Protocol, Generic[TReader, TBuilder]): ...

# Protocol classes for types that exist in pycapnp runtime but are accessed
# as attributes or return values (not directly imported)

class DynamicListReader(Protocol): ...

class InterfaceSchema(Protocol):
    methods: Mapping[str, Any]

class ListSchema(Protocol): ...

class StructModule(Protocol, Generic[TReader, TBuilder]):
    schema: StructSchema[TReader, TBuilder]

# Re-export commonly used types
ModuleType = ModuleType
Server = asyncio.Server
