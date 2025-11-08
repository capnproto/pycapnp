from __future__ import annotations

import asyncio
from collections.abc import (
    AsyncIterator,
    Awaitable,
    Callable,
    Iterator,
    Mapping,
    MutableMapping,
    Sequence,
)
from contextlib import asynccontextmanager
from types import ModuleType
from typing import Any, Generic, Protocol, TypeVar, overload

T = TypeVar("T")
T_co = TypeVar("T_co", covariant=True)

# Generic schema types that carry return type information
TReader = TypeVar("TReader")
TBuilder = TypeVar("TBuilder")
TInterface = TypeVar("TInterface")

class KjException(Exception):
    """Exception raised by Cap'n Proto operations.

    KjException is a wrapper of the internal C++ exception type.
    It contains an enum named `Type` and several properties providing
    information about the exception.
    """

    class Type:
        """Exception type enumeration."""

        FAILED: str
        OVERLOADED: str
        DISCONNECTED: str
        UNIMPLEMENTED: str
        OTHER: str
        reverse_mapping: dict[int, str]

    message: str | None
    nature: str | None
    durability: str | None
    wrapper: Any

    @property
    def file(self) -> str:
        """Source file where the exception occurred."""
        ...

    @property
    def line(self) -> int:
        """Line number where the exception occurred."""
        ...

    @property
    def type(self) -> str | None:
        """Exception type (one of the Type enum values)."""
        ...

    @property
    def description(self) -> str:
        """Human-readable description of the exception."""
        ...

    def __init__(
        self,
        message: str | None = None,
        nature: str | None = None,
        durability: str | None = None,
        wrapper: Any = None,
        type: str | None = None,
    ) -> None: ...
    def _to_python(self) -> Exception:
        """Convert to a more specific Python exception if appropriate."""
        ...

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
    """Node representing an interface schema.

    Only accessible when node.which() == 'interface'.
    """

    methods: Sequence[InterfaceMethod]
    superclasses: Sequence[SuperclassNode]

class SuperclassNode(Protocol):
    """Superclass reference in interface inheritance."""

    id: int

class SchemaNode(Protocol):
    """Schema node - a union type.

    This is a union! You must check which() before accessing union fields:
    - node.struct (when which() == 'struct')
    - node.enum (when which() == 'enum')
    - node.interface (when which() == 'interface')
    - node.const (when which() == 'const')
    - node.file (when which() == 'file')
    """

    # Always available fields
    id: int
    scopeId: int
    displayName: str
    displayNamePrefixLength: int
    nestedNodes: Sequence[NestedNode]
    parameters: Sequence[ParameterNode]
    isGeneric: bool

    # Union fields - only ONE is valid at a time based on which()
    struct: StructNode
    enum: EnumNode
    const: ConstNode
    interface: InterfaceNode
    # Note: file, annotation also exist but are less commonly used
    def which(self) -> str:
        """Return which union field is currently set.

        Returns one of: 'file', 'struct', 'enum', 'interface', 'const', 'annotation'
        """
        ...

class DefaultValueReader(Protocol):
    def as_bool(self) -> bool: ...
    def __str__(self) -> str: ...

class StructRuntime(Protocol):
    fields_list: Sequence[_DynamicStructReader]

class StructSchema(Protocol):
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

class _DynamicObjectReader(Protocol):
    """Reader for Cap'n Proto AnyPointer type.

    This class wraps the Cap'n Proto C++ DynamicObject::Reader.
    AnyPointer can be cast to different pointer types (struct, list, text, interface).
    """

    def as_interface(self, schema: _InterfaceSchema[TInterface]) -> TInterface:
        """Cast this AnyPointer to an interface capability.

        The return type matches the interface type parameterized in the schema.

        Args:
            schema: The interface schema to cast to (e.g., MyInterface.schema).

        Returns:
            A capability client of the interface type.

        Example:
            iface = anyptr.as_interface(MyInterface.schema)  # Returns MyInterface
        """
        ...

    def as_list(self, schema: Any) -> _DynamicListReader[Any]:
        """Cast this AnyPointer to a list.

        Args:
            schema: The list schema to cast to.

        Returns:
            A list reader.
        """
        ...

    @overload
    def as_struct(self, schema: _StructSchema[TReader, Any]) -> TReader:
        """Cast this AnyPointer to a struct reader using .schema attribute.

        Args:
            schema: The struct schema (e.g., MyStruct.schema).

        Returns:
            A struct reader of the appropriate type.
        """
        ...

    @overload
    def as_struct(self, schema: type[_StructModule[TReader, Any]]) -> TReader:
        """Cast this AnyPointer to a struct reader using the struct class directly.

        Args:
            schema: The struct class itself (e.g., MyStruct).

        Returns:
            A struct reader of the appropriate type.
        """
        ...

    def as_struct(
        self, schema: _StructSchema[TReader, Any] | type[_StructModule[TReader, Any]]
    ) -> TReader:
        """Cast this AnyPointer to a struct reader.

        The return type matches the Reader type parameterized in the schema.
        Can accept either the .schema attribute or the struct class itself.

        Args:
            schema: The struct schema or class to cast to (e.g., MyStruct.schema or MyStruct).

        Returns:
            A struct reader of the appropriate type.

        Examples:
            reader = anyptr.as_struct(MyStruct.schema)  # Returns MyStructReader
            reader = anyptr.as_struct(MyStruct)         # Also returns MyStructReader
        """
        ...

    def as_text(self) -> str:
        """Cast this AnyPointer to Text (str).

        Returns:
            The text value as a Python string.
        """
        ...

class _DynamicObjectBuilder(Protocol):
    """Builder for Cap'n Proto AnyPointer type.

    This class wraps the Cap'n Proto C++ DynamicObject::Builder.
    AnyPointer can be initialized or cast to different pointer types.
    """

    def as_interface(self, schema: _InterfaceSchema[TInterface]) -> TInterface:
        """Cast this AnyPointer to an interface capability.

        The return type matches the interface type parameterized in the schema.

        Args:
            schema: The interface schema to cast to (e.g., MyInterface.schema).

        Returns:
            A capability client of the interface type.

        Example:
            iface = anyptr.as_interface(MyInterface.schema)  # Returns MyInterface
        """
        ...

    def as_list(self, schema: Any) -> _DynamicListBuilder[Any]:
        """Cast this AnyPointer to a list.

        Args:
            schema: The list schema to cast to.

        Returns:
            A list builder.
        """
        ...

    def as_reader(self) -> _DynamicObjectReader:
        """Get a reader view of this builder.

        Returns:
            A reader for this AnyPointer.
        """
        ...

    @overload
    def as_struct(self, schema: _StructSchema[Any, TBuilder]) -> TBuilder:
        """Cast this AnyPointer to a struct builder using .schema attribute.

        Args:
            schema: The struct schema (e.g., MyStruct.schema).

        Returns:
            A struct builder of the appropriate type.
        """
        ...

    @overload
    def as_struct(self, schema: type[_StructModule[Any, TBuilder]]) -> TBuilder:
        """Cast this AnyPointer to a struct builder using the struct class directly.

        Args:
            schema: The struct class itself (e.g., MyStruct).

        Returns:
            A struct builder of the appropriate type.
        """
        ...

    def as_struct(
        self, schema: _StructSchema[Any, TBuilder] | type[_StructModule[Any, TBuilder]]
    ) -> TBuilder:
        """Cast this AnyPointer to a struct builder.

        The return type matches the Builder type parameterized in the schema.
        Can accept either the .schema attribute or the struct class itself.

        Args:
            schema: The struct schema or class to cast to (e.g., MyStruct.schema or MyStruct).

        Returns:
            A struct builder of the appropriate type.

        Examples:
            builder = anyptr.as_struct(MyStruct.schema)  # Returns MyStructBuilder
            builder = anyptr.as_struct(MyStruct)         # Also returns MyStructBuilder
        """
        ...

    def as_text(self) -> str:
        """Cast this AnyPointer to Text (str).

        Returns:
            The text value as a Python string.
        """
        ...

    def init_as_list(self, schema: Any, size: int) -> _DynamicListBuilder[Any]:
        """Initialize this AnyPointer as a list of the given size.

        Args:
            schema: The list schema.
            size: The number of elements in the list.

        Returns:
            A list builder for the newly initialized list.
        """
        ...

    def set(self, other: _DynamicObjectReader) -> None:
        """Set this AnyPointer to a copy of another AnyPointer.

        Note: Don't use this for structs.

        Args:
            other: The AnyPointer reader to copy from.
        """
        ...

    def set_as_text(self, text: str) -> None:
        """Set this AnyPointer to a Text value.

        Args:
            text: The text value to set.
        """
        ...

class _DynamicStructReader(Protocol):
    """Reader for Cap'n Proto structs.

    This class is almost a 1:1 wrapping of the Cap'n Proto C++ DynamicStruct::Reader.
    The only difference is that instead of a `get` method, __getattr__ is overloaded and the field name
    is passed onto the C++ equivalent `get`. This means you just use . syntax to access any field.
    For field names that don't follow valid python naming convention for fields, use the global function
    getattr()::

        person = addressbook.Person.read(file)  # This returns a _DynamicStructReader
        print(person.name)  # using . syntax
        print(getattr(person, 'field-with-hyphens'))  # for names that are invalid for python
    """

    name: str
    slot: SlotRuntime
    schema: StructSchema
    list: DynamicListReader
    struct: StructType
    enum: EnumType
    interface: InterfaceType

    def which(self) -> str:
        """Return the name of the currently set union field."""
        ...

    def _get(self, field: str) -> Any:
        """Low-level get method for accessing struct fields by name."""
        ...

    def _has(self, field: str) -> bool:
        """Check if a field is set (mainly for unions and pointer fields)."""
        ...

    def _which(self) -> Any:
        """Return the enum corresponding to the union in this struct.

        Returns:
            A string/enum corresponding to what field is set in the union

        Raises:
            KjException: if this struct doesn't contain a union
        """
        ...

    def _which_str(self) -> str:
        """Return the union field name as a string."""
        ...

    def as_builder(
        self,
        num_first_segment_words: int | None = None,
        allocate_seg_callable: Callable[..., Any] | None = None,
    ) -> _DynamicStructBuilder:
        """Convert this reader to a builder (creates a copy).

        Args:
            num_first_segment_words: Size of first segment
            allocate_seg_callable: Custom allocator function

        Returns:
            A builder containing a copy of this struct
        """
        ...

    def to_dict(
        self,
        verbose: bool = False,
        ordered: bool = False,
        encode_bytes_as_base64: bool = False,
    ) -> dict[str, Any]:
        """Convert the struct to a Python dictionary.

        Args:
            verbose: Include more details
            ordered: Use OrderedDict for output
            encode_bytes_as_base64: Encode bytes fields as base64 strings

        Returns:
            Dictionary representation of the struct
        """
        ...

class _DynamicStructBuilder(Protocol):
    """Builder for Cap'n Proto structs.

    This class is almost a 1:1 wrapping of the Cap'n Proto C++ DynamicStruct::Builder.
    The only difference is that instead of `get`/`set` methods, __getattr__/__setattr__ is overloaded
    and the field name is passed onto the C++ equivalent function.

    This means you just use . syntax to access or set any field. For field names that don't follow valid
    python naming convention for fields, use the global functions getattr()/setattr()::

        person = addressbook.Person.new_message()  # This returns a _DynamicStructBuilder

        person.name = 'foo'  # using . syntax
        print(person.name)  # using . syntax

        setattr(person, 'field-with-hyphens', 'foo')  # for invalid python names
        print(getattr(person, 'field-with-hyphens'))
    """

    name: str
    schema: StructSchema

    def which(self) -> str:
        """Return the name of the currently set union field."""
        ...

    def _get(self, field: str) -> Any:
        """Low-level get method for accessing struct fields by name."""
        ...

    def _set(self, field: str, value: Any) -> None:
        """Low-level set method for setting struct fields by name."""
        ...

    def _has(self, field: str) -> bool:
        """Check if a field is set (mainly for unions and pointer fields)."""
        ...

    def _which(self) -> Any:
        """Return the enum corresponding to the union in this struct.

        Returns:
            A string/enum corresponding to what field is set in the union

        Raises:
            KjException: if this struct doesn't contain a union
        """
        ...

    def _which_str(self) -> str:
        """Return the union field name as a string."""
        ...

    def as_reader(self) -> _DynamicStructReader:
        """Convert this builder to a reader (read-only view).

        Returns:
            A reader view of this struct
        """
        ...

    def adopt(self, field: str, orphan: Any) -> None:
        """Adopt an orphaned message into a field.

        Args:
            field: Field name
            orphan: Orphaned message to adopt
        """
        ...

    def disown(self, field: str) -> Any:
        """Disown a field, returning an orphan.

        Args:
            field: Field name

        Returns:
            Orphaned message
        """
        ...

    def init(self, field: str, size: int | None = None) -> Any:
        """Initialize a struct or list field.

        Args:
            field: Field name
            size: Size for list fields

        Returns:
            The initialized field (builder for structs, list builder for lists)
        """
        ...

    def init_resizable_list(self, field: str) -> _DynamicListBuilder[Any]:
        """Initialize a resizable list field (for lists of structs).

        This version of init returns a _DynamicResizableListBuilder that allows
        you to add members one at a time (if you don't know the size for sure).
        This is only meant for lists of Cap'n Proto objects, since for primitive types
        you can just define a normal python list and fill it yourself.

        Warning:
            You need to call finish() on the list object before serializing the
            Cap'n Proto message. Failure to do so will cause your objects not to be
            written out as well as leaking orphan structs into your message.

        Args:
            field: Field name

        Returns:
            Resizable list builder

        Raises:
            KjException: if the field isn't in this struct
        """
        ...

    def from_dict(self, d: dict[str, Any]) -> None:
        """Populate the struct from a dictionary.

        Args:
            d: Dictionary with field values
        """
        ...

    def to_dict(
        self,
        verbose: bool = False,
        ordered: bool = False,
        encode_bytes_as_base64: bool = False,
    ) -> dict[str, Any]:
        """Convert the struct to a Python dictionary.

        Args:
            verbose: Include more details
            ordered: Use OrderedDict for output
            encode_bytes_as_base64: Encode bytes fields as base64 strings

        Returns:
            Dictionary representation of the struct
        """
        ...

    def copy(
        self,
        num_first_segment_words: int | None = None,
        allocate_seg_callable: Callable[..., Any] | None = None,
    ) -> _DynamicStructBuilder:
        """Create a deep copy of this struct.

        Args:
            num_first_segment_words: Size of first segment
            allocate_seg_callable: Custom allocator function

        Returns:
            A new builder containing a copy
        """
        ...

    def clear_write_flag(self) -> None:
        """Clear the write flag for this struct."""
        ...

    def to_bytes(self) -> bytes:
        """Serialize the struct to bytes.

        Returns:
            Serialized message bytes
        """
        ...

    def to_bytes_packed(self) -> bytes:
        """Serialize the struct to packed bytes.

        Returns:
            Serialized message bytes (packed format)
        """
        ...

    def to_segments(self) -> list[bytes]:
        """Serialize the struct to a list of segment bytes.

        Returns:
            List of segment byte arrays
        """
        ...

    def write(self, file: Any) -> None:
        """Write the struct to a file.

        Args:
            file: File-like object to write to
        """
        ...

    def write_packed(self, file: Any) -> None:
        """Write the struct to a file in packed format.

        Args:
            file: File-like object to write to
        """
        ...

    async def write_async(self, stream: AsyncIoStream) -> None:
        """Asynchronously write the struct to a stream.

        Args:
            stream: AsyncIoStream to write to
        """
        ...

class _EnumSchema:
    """Schema for enum types.

    Provides access to enum schema information.
    """

    enumerants: dict[str, int]
    node: SchemaNode

class _InterfaceSchema(Generic[TInterface]):
    """Schema for interface types, parameterized by the interface type.

    Provides access to interface schema information.
    """

    method_names: tuple[str, ...]
    method_names_inherited: set[str]

class _ListSchema:
    """Schema for list types.

    Can be instantiated to create list schemas for different element types.
    """

    elementType: (
        TypeReader
        | _StructSchema
        | _EnumSchema
        | _InterfaceSchema
        | _ListSchema
        | _SchemaType
    )

    def __init__(
        self,
        schema: (
            _StructSchema
            | _EnumSchema
            | _InterfaceSchema
            | _ListSchema
            | _SchemaType
            | StructSchema
            | Any
            | None
        ) = None,
    ) -> None:
        """Create a list schema for the given element type.

        Args:
            schema: Element type schema. Can be:
                - A struct schema (_StructSchema or StructSchema)
                - An enum schema (_EnumSchema)
                - An interface schema (_InterfaceSchema)
                - Another list schema (_ListSchema) for nested lists
                - A primitive type (_SchemaType, e.g., capnp.types.Int8)
                - Any object with a .schema attribute
                - None (creates uninitialized schema)
        """
        ...

    def as_struct(self) -> StructRuntime: ...
    def get_nested(self, name: str) -> StructSchema: ...

class _StructSchema(Protocol, Generic[TReader, TBuilder]):
    """Schema for a struct, parameterized by its Reader and Builder types."""

    node: SchemaNode
    def as_struct(self) -> StructRuntime: ...
    def get_nested(self, name: str) -> StructSchema: ...

class _StructModule(Protocol, Generic[TReader, TBuilder]):
    """Module/class for a struct, parameterized by its Reader and Builder types.

    This is what you get when you access the struct class itself (e.g., MyStruct).
    It has a .schema attribute and static methods like .new_message().
    """

    schema: _StructSchema[TReader, TBuilder]

class InterfaceMethod(Protocol):
    param_type: StructSchema
    result_type: StructSchema

class InterfaceSchema(Protocol):
    methods: Mapping[str, InterfaceMethod]

class InterfaceRuntime(Protocol):
    schema: InterfaceSchema

# RPC Request/Response Types
class _Request(_DynamicStructBuilder, Protocol):
    """RPC request builder.

    Extends DynamicStructBuilder with RPC-specific send() method.
    """
    def send(self) -> _Response:
        """Send the RPC request and return a promise for the response.

        Returns:
            Response promise
        """
        ...

class _Response(_DynamicStructReader, Protocol):
    """RPC response reader.

    Extends DynamicStructReader for reading RPC responses.
    Response objects are also awaitable promises.
    """

    pass

class _CallContext(Protocol):
    """Context for an RPC call on the server side.

    Provides methods for handling server-side RPC calls.
    """
    def release_params(self) -> None:
        """Release the parameter struct.

        Call this when you're done reading the parameters to allow
        the message memory to be freed.
        """
        ...

    def tail_call(self, tailRequest: _Request) -> None:
        """Perform a tail call to another capability.

        Args:
            tailRequest: Request to tail call
        """
        ...

# Capability Types
class _DynamicCapabilityClient(Protocol):
    """Dynamic capability client.

    Represents a reference to a remote capability.
    """
    def cast_as(self, schema: type[T]) -> T:
        """Cast this capability to a specific interface type.

        Args:
            schema: Interface type to cast to

        Returns:
            Capability cast to the specified interface
        """
        ...

    def upcast(self, schema: type[T]) -> T:
        """Upcast this capability to a parent interface type.

        Args:
            schema: Parent interface type

        Returns:
            Capability upcast to the parent interface
        """
        ...

class _DynamicCapabilityServer(Protocol):
    """Dynamic capability server base class.

    Implement this to create server-side capability implementations.
    """

    pass

class _CapabilityClient:
    """Base class for capability clients.

    Wraps Cap'n Proto capability references.
    """

    def cast_as(self, schema: type[T]) -> T:
        """Cast this capability to a specific interface type.

        Args:
            schema: Interface schema to cast to

        Returns:
            Capability cast to the specified interface
        """
        ...

class _Promise:
    """Promise for asynchronous RPC results.

    Represents a promise for a future value in Cap'n Proto RPC.
    Can be awaited in async contexts.
    """

    def cancel(self) -> None:
        """Cancel the promise."""
        ...

class _RemotePromise(_Promise):
    """Remote promise for asynchronous RPC results.

    Extended promise type that provides additional methods for
    accessing pipelined capabilities.
    """

    def to_dict(
        self,
        verbose: bool = False,
        ordered: bool = False,
        encode_bytes_as_base64: bool = False,
    ) -> dict[str, Any]:
        """Convert the promise result to a dictionary.

        Args:
            verbose: Include more details
            ordered: Use OrderedDict for output
            encode_bytes_as_base64: Encode bytes fields as base64 strings

        Returns:
            Dictionary representation
        """
        ...

class _DynamicStructPipeline:
    """Pipeline for pipelined RPC calls on struct results.

    This class is almost a 1:1 wrapping of the Cap'n Proto C++ DynamicStruct::Pipeline.
    The only difference is that instead of a `get` method, __getattr__ is overloaded and the
    field name is passed onto the C++ equivalent `get`. This means you just use . syntax to
    access any field. For field names that don't follow valid python naming convention for fields,
    use the global function getattr()::

        # Pipeline calls allow you to call methods on results before they arrive
        result = remote_object.method()
        result.field.another_method()  # Pipelined call
    """

    def to_dict(
        self,
        verbose: bool = False,
        ordered: bool = False,
        encode_bytes_as_base64: bool = False,
    ) -> dict[str, Any]:
        """Convert to dictionary when the pipeline resolves.

        Args:
            verbose: Include more details
            ordered: Use OrderedDict for output
            encode_bytes_as_base64: Encode bytes fields as base64 strings

        Returns:
            Dictionary representation
        """
        ...

# Message Builder/Reader Types
class _MessageBuilder:
    """Abstract base class for building Cap'n Proto messages.

    Warning:
        Don't ever instantiate this class directly. It is only used for inheritance.
    """

    def init_root(self, schema: _StructSchema[Any, TBuilder]) -> TBuilder:
        """Initialize the message root as a struct of the given type.

        Args:
            schema: The struct schema to use for the root

        Returns:
            A builder for the root struct
        """
        ...

    def get_root(self, schema: _StructSchema[TReader, Any]) -> TReader:
        """Get the message root as a struct of the given type.

        Args:
            schema: The struct schema to use for the root

        Returns:
            A reader for the root struct
        """
        ...

    def get_root_as_any(self) -> _DynamicObjectBuilder:
        """Get the message root as an AnyPointer.

        Returns:
            An AnyPointer builder for the root
        """
        ...

    def set_root(self, value: _DynamicStructReader) -> None:
        """Set the message root by copying from a struct reader.

        Args:
            value: The struct reader to copy from
        """
        ...

    def new_orphan(self, schema: _StructSchema[Any, TBuilder]) -> Any:
        """Create a new orphaned struct.

        Don't use this method unless you know what you're doing.

        Args:
            schema: The struct schema for the orphan

        Returns:
            An orphaned struct
        """
        ...

    def get_segments_for_output(self) -> list[bytes]:
        """Get the message segments as a list of bytes.

        Returns:
            List of segment byte arrays
        """
        ...

class _MallocMessageBuilder(_MessageBuilder):
    """The main class for building Cap'n Proto messages.

    You will use this class to handle arena allocation of Cap'n Proto
    messages. You also use this object when you're done assigning to Cap'n
    Proto objects, and wish to serialize them::

        addressbook = capnp.load('addressbook.capnp')
        message = capnp._MallocMessageBuilder()
        person = message.init_root(addressbook.Person)
        person.name = 'alice'
        ...
        f = open('out.txt', 'w')
        capnp._write_message_to_fd(f.fileno(), message)
    """

    def __init__(self, size: int | None = None) -> None:
        """Create a new message builder.

        Args:
            size: Optional initial size for the first segment (in words)
        """
        ...

class _MessageReader:
    """Abstract base class for reading Cap'n Proto messages.

    Warning:
        Don't ever instantiate this class. It is only used for inheritance.
    """

    def get_root(self, schema: _StructSchema[TReader, Any]) -> TReader:
        """Get the message root as a struct of the given type.

        Args:
            schema: The struct schema to use for the root

        Returns:
            A reader for the root struct
        """
        ...

    def get_root_as_any(self) -> _DynamicObjectReader:
        """Get the message root as an AnyPointer.

        Returns:
            An AnyPointer reader for the root
        """
        ...

class GeneratedModule(ModuleType):
    schema: StructSchema
    __file__: str | None

class SchemaParser:
    """Parser for loading Cap'n Proto schema files.

    Do not use this class unless you're sure you know what you're doing.
    Use the convenience method :func:`load` instead.
    """

    modules_by_id: MutableMapping[int, GeneratedModule]
    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def load(
        self,
        file_name: str,
        display_name: str | None = None,
        imports: Sequence[str] = [],
    ) -> GeneratedModule:
        """Load a Cap'n Proto schema file.

        Args:
            file_name: Path to the .capnp file
            display_name: Optional display name for the module
            imports: List of import paths for resolving imports

        Returns:
            Loaded GeneratedModule
        """
        ...

class SchemaLoader:
    """Class for constructing Schema objects from schema::Nodes.

    Wraps capnproto/c++/src/capnp/schema-loader.h directly.
    """
    def __init__(self) -> None: ...
    def get(self, id_: int) -> StructSchema:
        """Get a schema by its ID.

        Args:
            id_: Schema node ID

        Returns:
            The schema with the given ID
        """
        ...
    def load(self, reader: _DynamicStructReader) -> StructSchema:
        """Load a schema from a reader.

        Args:
            reader: DynamicStructReader containing schema data

        Returns:
            Loaded schema
        """
        ...
    def load_dynamic(self, reader: _DynamicStructReader) -> StructSchema:
        """Load a schema dynamically from a reader.

        Args:
            reader: DynamicStructReader containing schema data

        Returns:
            Loaded schema
        """
        ...

# Module loading and import hooks
def add_import_hook() -> None:
    """Add a hook to the Python import system.

    After calling this, Cap'n Proto modules can be directly imported
    like regular Python modules.
    """
    ...

def remove_import_hook() -> None:
    """Remove the import hook and return Python's import to normal."""
    ...

def load(
    file_name: str,
    display_name: str | None = None,
    imports: Sequence[str] = [],
) -> GeneratedModule:
    """Load a Cap'n Proto schema from a file.

    Args:
        file_name: Path to the .capnp file
        display_name: Optional display name for the module
        imports: List of import paths for resolving imports

    Returns:
        Loaded GeneratedModule with generated types
    """
    ...

def register_type(id: int, klass: type) -> None:
    """Register a type with the given schema ID.

    Args:
        id: Schema node ID
        klass: Python class to register
    """
    ...

def cleanup_global_schema_parser() -> None:
    """Unload all schemas from the current context."""
    ...

def deregister_all_types() -> None:
    """Deregister all registered types."""
    ...

def read_multiple_bytes_packed(
    buf: bytes,
    traversal_limit_in_words: int | None = None,
    nesting_limit: int | None = None,
) -> Iterator[_DynamicStructReader]:
    """Read multiple packed Cap'n Proto messages from a buffer.

    Returns an iterable that yields Readers for AnyPointer messages.

    Args:
        buf: Buffer containing packed messages
        traversal_limit_in_words: Optional limit on pointer dereferences
        nesting_limit: Optional limit on nesting depth

    Yields:
        DynamicStructReader for each message
    """
    ...

class _CapnpLibCapnpModule:
    """The capnp.lib.capnp submodule containing implementation classes.

    This module contains the low-level C++ wrapper classes.
    """

    # Dynamic types
    _DynamicStructReader: type[_DynamicStructReader]
    _DynamicStructBuilder: type[_DynamicStructBuilder]
    _DynamicListReader: type[_DynamicListReader]
    _DynamicListBuilder: type[_DynamicListBuilder]
    _DynamicObjectReader: type[_DynamicObjectReader]
    _DynamicObjectBuilder: type[_DynamicObjectBuilder]

    # Schema types
    _EnumSchema: type[_EnumSchema]
    _InterfaceSchema: type[_InterfaceSchema]
    _ListSchema: type[_ListSchema]
    _SchemaType: type[_SchemaType]
    _StructSchema: type[_StructSchema]

    # RPC types
    _Request: type[_Request]
    _Response: type[_Response]
    _CallContext: type[_CallContext]
    _DynamicCapabilityClient: type[_DynamicCapabilityClient]
    _DynamicCapabilityServer: type[_DynamicCapabilityServer]
    _CapabilityClient: type[_CapabilityClient]

    # Promise and Pipeline types
    _Promise: type[_Promise]
    _RemotePromise: type[_RemotePromise]
    _DynamicStructPipeline: type[_DynamicStructPipeline]

    # Message types
    _MessageBuilder: type[_MessageBuilder]
    _MallocMessageBuilder: type[_MallocMessageBuilder]
    _MessageReader: type[_MessageReader]

    # Exception types
    KjException: type[KjException]

    # Parser types
    SchemaParser: type[SchemaParser]
    SchemaLoader: type[SchemaLoader]

    # RPC classes
    TwoPartyClient: type[TwoPartyClient]
    TwoPartyServer: type[TwoPartyServer]
    AsyncIoStream: type[AsyncIoStream]

class _CapnpLibModule:
    """The capnp.lib submodule."""

    capnp: _CapnpLibCapnpModule

class _CapnpLib:
    """The capnp.lib namespace.

    Provides access to low-level Cap'n Proto implementation classes.
    """

    capnp: _CapnpLibCapnpModule

lib: _CapnpLib

class _SchemaType:
    """Internal schema type representation.

    This class represents Cap'n Proto primitive types.
    Instances are used for type comparisons and type checking.
    """

    pass

class _CapnpTypesModule:
    """The capnp.types module.

    Provides singleton instances of _SchemaType for each primitive Cap'n Proto type.
    These are used for type checking and comparison.
    """

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

types: _CapnpTypesModule

class _DynamicListBuilder(Generic[T]):
    """Generic list builder type returned by init() for list fields.

    This class wraps the Cap'n Proto C++ DynamicList::Builder.
    __getitem__, __setitem__, __len__ and __iter__ have been defined properly,
    so you can treat this class mostly like any other iterable class::

        person = addressbook.Person.new_message()

        phones = person.init('phones', 2)  # This returns a _DynamicListBuilder

        phones[0].number = '555-1234'
        phones[1].number = '555-5678'

        for phone in phones:
            print(phone.number)

    For struct element types, both T instances and dict[str, Any] are accepted
    for convenient initialization, e.g.:
        list_builder[0] = {"field": value}
    """
    def __len__(self) -> int: ...
    def __getitem__(self, index: int) -> T: ...
    def __setitem__(self, index: int, value: T | dict[str, Any]) -> None: ...
    def __iter__(self) -> Iterator[T]: ...
    def adopt(self, index: int, orphan: Any) -> None:
        """Adopt an orphaned message at the given index.

        Don't use this method unless you know what you're doing.
        """
        ...
    def disown(self, index: int) -> Any:
        """Disown the element at the given index, returning an orphan.

        Don't use this method unless you know what you're doing.
        """
        ...
    def init(self, index: int, size: int) -> Any:
        """Initialize a struct or list element at the given index with the given size.

        Args:
            index: Index of the element to initialize
            size: Size parameter (for nested lists)

        Returns:
            The initialized element (builder for structs, list builder for lists)
        """
        ...

class _DynamicListReader(Generic[T_co]):
    """Generic list reader type for reading Cap'n Proto list fields.

    This class thinly wraps the C++ Cap'n Proto DynamicList::Reader class.
    __getitem__ and __len__ have been defined properly, so you can treat this
    class mostly like any other iterable class::

        person = addressbook.Person.read(file)

        phones = person.phones  # This returns a _DynamicListReader

        phone = phones[0]
        print(phone.number)

        for phone in phones:
            print(phone.number)

    Provides read-only list-like interface.
    """
    def __len__(self) -> int: ...
    def __getitem__(self, index: int) -> T_co: ...
    def __iter__(self) -> Iterator[T_co]: ...

# RPC Classes
I_co = TypeVar("I_co")

class CastableBootstrap(Protocol):
    def cast_as(self, interface: type[I_co]) -> I_co: ...

class TwoPartyClient:
    """Two-party RPC client for Cap'n Proto.

    Args:
        socket: AsyncIoStream connection
        traversal_limit_in_words: Optional limit on pointer dereferences
        nesting_limit: Optional limit on nesting depth
    """
    def __init__(
        self,
        socket: AsyncIoStream | None = None,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> None: ...
    def bootstrap(self) -> CastableBootstrap:
        """Get the bootstrap interface for this client."""
        ...
    def close(self) -> None:
        """Close the client connection."""
        ...
    async def on_disconnect(self) -> None:
        """Wait until the connection is disconnected."""
        ...

class TwoPartyServer:
    """Two-party RPC server for Cap'n Proto.

    Args:
        socket: AsyncIoStream connection
        bootstrap: Bootstrap interface implementation
        traversal_limit_in_words: Optional limit on pointer dereferences
        nesting_limit: Optional limit on nesting depth
    """
    def __init__(
        self,
        socket: AsyncIoStream | None = None,
        bootstrap: Any = None,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> None: ...
    def close(self) -> None:
        """Close the server connection."""
        ...
    async def on_disconnect(self) -> None:
        """Wait until the connection is disconnected."""
        ...

class AsyncIoStream:
    """Async I/O stream wrapper for Cap'n Proto RPC.

    Provides async I/O operations for Cap'n Proto RPC over TCP and Unix domain sockets.
    """
    @staticmethod
    async def create_connection(
        host: str | None = None, port: int | None = None, **kwargs: Any
    ) -> AsyncIoStream:
        """Create an async TCP connection.

        Args:
            host: Hostname to connect to
            port: Port number to connect to
            **kwargs: Additional connection options

        Returns:
            AsyncIoStream connected to the server
        """
        ...

    @staticmethod
    async def create_unix_connection(
        path: str | None = None, **kwargs: Any
    ) -> AsyncIoStream:
        """Create an async Unix domain socket connection.

        Args:
            path: Path to Unix domain socket
            **kwargs: Additional connection options

        Returns:
            AsyncIoStream connected to the server
        """
        ...

    @staticmethod
    async def create_server(
        callback: Callable[[AsyncIoStream], Awaitable[None]],
        host: str | None = None,
        port: int | None = None,
        **kwargs: Any,
    ) -> asyncio.Server:
        """Create an async TCP server.

        Args:
            callback: Async callback function for each new connection
            host: Hostname to bind to
            port: Port number to bind to
            **kwargs: Additional server options

        Returns:
            Server instance
        """
        ...

    @staticmethod
    async def create_unix_server(
        callback: Callable[[AsyncIoStream], Awaitable[None]],
        path: str | None = None,
        **kwargs: Any,
    ) -> asyncio.Server:
        """Create an async Unix domain socket server.

        Args:
            callback: Async callback function for each new connection
            path: Path for Unix domain socket
            **kwargs: Additional server options

        Returns:
            Server instance
        """
        ...

    def close(self) -> None:
        """Close the stream."""
        ...

    async def wait_closed(self) -> None:
        """Wait until the stream is closed."""
        ...

# Async utilities
async def run(coro: Awaitable[T]) -> T:
    """Run an async coroutine with Cap'n Proto event loop.

    Ensures that the coroutine runs while the KJ event loop is running.

    Args:
        coro: Coroutine to run

    Returns:
        The result of the coroutine
    """
    ...

@asynccontextmanager
def kj_loop() -> AsyncIterator[None]:
    """Context manager for running the KJ event loop.

    Usage:
        with capnp.kj_loop():
            # Run async code
            pass
    """
    ...

__all__ = [
    # Schema types
    "AnyPointerParameter",
    "AnyPointerType",
    "Brand",
    "BrandBinding",
    "BrandScope",
    "ConstNode",
    "DefaultValueReader",
    "DynamicListReader",
    "Enumerant",
    "EnumNode",
    "EnumType",
    "FieldNode",
    "GeneratedModule",
    "InterfaceMethod",
    "InterfaceRuntime",
    "InterfaceSchema",
    "ListElementType",
    "ListSchema",
    "ListType",
    "NestedNode",
    "ParameterNode",
    "SchemaNode",
    "SchemaParser",
    "SchemaLoader",
    "SlotNode",
    "SlotRuntime",
    "StructNode",
    "StructRuntime",
    "StructSchema",
    "StructType",
    "TypeReader",
    # Dynamic types
    "_DynamicListBuilder",
    "_DynamicListReader",
    "_DynamicObjectBuilder",
    "_DynamicObjectReader",
    "_DynamicStructBuilder",
    "_DynamicStructReader",
    "_EnumSchema",
    "_InterfaceSchema",
    "_ListSchema",
    "_SchemaType",
    "_StructSchema",
    # RPC types
    "_Request",
    "_Response",
    "_CallContext",
    "_DynamicCapabilityClient",
    "_DynamicCapabilityServer",
    "_CapabilityClient",
    "_Promise",
    "_RemotePromise",
    "_DynamicStructPipeline",
    "CastableBootstrap",
    "TwoPartyClient",
    "TwoPartyServer",
    "AsyncIoStream",
    # Message types
    "_MessageBuilder",
    "_MallocMessageBuilder",
    "_MessageReader",
    # Exceptions
    "KjException",
    # Functions
    "add_import_hook",
    "cleanup_global_schema_parser",
    "deregister_all_types",
    "kj_loop",
    "load",
    "read_multiple_bytes_packed",
    "register_type",
    "remove_import_hook",
    "run",
    # Modules
    "lib",
    "types",
]
