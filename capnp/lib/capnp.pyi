from __future__ import annotations

from collections.abc import (
    AsyncIterator,
    Awaitable,
    Callable,
    Iterator,
    MutableMapping,
    Sequence,
)
from contextlib import asynccontextmanager
from typing import Any

from capnp._internal import CapnpTypesModule as _CapnpTypesModule
from capnp._internal import (
    EnumType as _EnumType,
)
from capnp._internal import (
    InterfaceType as _InterfaceType,
)
from capnp._internal import SchemaNode as _SchemaNode
from capnp._internal import (
    Server as _Server,
)
from capnp._internal import (
    SlotRuntime as _SlotRuntime,
)
from capnp._internal import (
    StructType as _StructType,
)
from capnp._internal import (
    T,
    TBuilder,
    TInterface,
    TReader,
)

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

class _StructSchema:
    node: _SchemaNode

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def which(self) -> str: ...
    def as_struct(self) -> Any: ...
    def get_nested(self, name: str) -> Any: ...

class _StructModule:
    schema: _StructSchema

    def __init__(self, schema: _StructSchema, name: str) -> None: ...

class _DynamicObjectReader:
    """Reader for Cap'n Proto AnyPointer type.

    This class wraps the Cap'n Proto C++ DynamicObject::Reader.
    AnyPointer can be cast to different pointer types (struct, list, text, interface).
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def as_interface(self, schema: _InterfaceSchema | _InterfaceModule) -> Any:
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

    def as_list(self, schema: _ListSchema) -> Any:
        """Cast this AnyPointer to a list.

        Args:
            schema: The list schema to cast to.

        Returns:
            A list reader.
        """
        ...

    def as_struct(self, schema: _StructSchema | type[_StructModule]) -> Any:
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

class _DynamicObjectBuilder:
    """Builder for Cap'n Proto AnyPointer type.

    This class wraps the Cap'n Proto C++ DynamicObject::Builder.
    AnyPointer can be initialized or cast to different pointer types.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def as_interface(self, schema: _InterfaceSchema | _InterfaceModule) -> Any:
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

    def as_list(self, schema: _ListSchema) -> Any:
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

    def as_struct(self, schema: _StructSchema | type[_StructModule]) -> Any:
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

    def init_as_list(self, schema: Any, size: int) -> _DynamicListBuilder:
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

class _DynamicStructReader:
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

    slot: _SlotRuntime
    schema: _StructSchema
    list: _DynamicListReader
    struct: _StructType
    enum: _EnumType
    interface: _InterfaceType

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    @property
    def name(self) -> str: ...
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

class _DynamicStructBuilder:
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

    schema: _StructSchema

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    @property
    def name(self) -> str: ...
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

    def init_resizable_list(self, field: str) -> _DynamicListBuilder:
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
    Only accessible from capnp.lib.capnp, not from capnp directly.
    """

    enumerants: dict[str, int]
    node: _SchemaNode

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...

class _InterfaceSchema:
    """Schema for interface types, parameterized by the interface type.

    Provides access to interface schema information.
    Only accessible from capnp.lib.capnp, not from capnp directly.
    """

    method_names: tuple[str, ...]
    method_names_inherited: set[str]

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...

class _ListSchema:
    """Schema for list types.

    Can be instantiated to create list schemas for different element types.
    """

    @property
    def elementType(
        self,
    ) -> _StructSchema | _EnumSchema | _InterfaceSchema | _ListSchema:
        """The schema of the element type of this list.

        Returns:
            Schema of the list element type:
            - _StructSchema for struct elements
            - _EnumSchema for enum elements
            - _InterfaceSchema for interface elements
            - _ListSchema for nested list elements

        Raises:
            KjException: When the element type is a primitive type (Int32, Text, Bool, etc.)
                with message "Schema type is unknown"
        """
        ...

    def __init__(
        self,
        schema: (
            _StructSchema
            | _EnumSchema
            | _InterfaceSchema
            | _ListSchema
            | _SchemaType
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

# RPC Request/Response Types
class _Request(_DynamicStructBuilder):
    """RPC request builder.

    Extends DynamicStructBuilder with RPC-specific send() method.
    """
    def send(self) -> _Response:
        """Send the RPC request and return a promise for the response.

        Returns:
            Response promise
        """
        ...

class _Response(_DynamicStructReader):
    """RPC response reader.

    Extends DynamicStructReader for reading RPC responses.
    Response objects are also awaitable promises.
    """

    pass

class _CallContext:
    """Context for an RPC call on the server side.

    Provides methods for handling server-side RPC calls.

    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    @property
    def params(self) -> _DynamicStructReader: ...
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
class _DynamicCapabilityClient:
    """Dynamic capability client.

    Represents a reference to a remote capability.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
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

class _DynamicCapabilityServer:
    """Dynamic capability server base class.

    Implement this to create server-side capability implementations.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...

class _CapabilityClient:
    """Base class for capability clients.

    Wraps Cap'n Proto capability references.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
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

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def cancel(self) -> None:
        """Cancel the promise."""
        ...

class _RemotePromise(_Promise):
    """Remote promise for asynchronous RPC results.

    Extended promise type that provides additional methods for
    accessing pipelined capabilities.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
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

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
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

    def init_root(self, schema: _StructSchema) -> TBuilder:
        """Initialize the message root as a struct of the given type.

        Args:
            schema: The struct schema to use for the root

        Returns:
            A builder for the root struct
        """
        ...

    def get_root(self, schema: _StructSchema) -> TReader:
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

    def new_orphan(self, schema: _StructSchema) -> Any:
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

    def get_root(self, schema: _StructSchema) -> TReader:
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

class _PackedFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in packed format.

    This class reads messages that were written with _write_packed_message_to_fd.
    """

    def __init__(
        self,
        file: Any,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> None:
        """Create a reader from a file object.

        Args:
            file: File object to read from (must have a fileno() method)
            traversal_limit_in_words: Optional limit on pointer dereferences
            nesting_limit: Optional limit on nesting depth
        """
        ...

class _StreamFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in stream format.

    This class reads messages that were written with _write_message_to_fd.
    """

    def __init__(
        self,
        file: Any,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> None:
        """Create a reader from a file object.

        Args:
            file: File object to read from (must have a fileno() method)
            traversal_limit_in_words: Optional limit on pointer dereferences
            nesting_limit: Optional limit on nesting depth
        """
        ...

class _PyCustomMessageBuilder(_MessageBuilder):
    """Custom message builder with user-provided segments.

    This allows building messages with custom memory management.
    """

    def __init__(self, allocate_seg_callable: Callable[[int], bytearray]) -> None:
        """Create a message builder with custom memory allocation.

        Args:
            allocate_seg_callable: A callable that takes the minimum number of 8-byte
                words to allocate (as an int) and returns a bytearray. This is used to
                customize the memory allocation strategy.
        """
        ...

class SchemaParser:
    """Parser for loading Cap'n Proto schema files.

    Do not use this class unless you're sure you know what you're doing.
    Use the convenience method :func:`load` instead.
    """

    modules_by_id: MutableMapping[int, Any]
    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def load(
        self,
        file_name: str,
        display_name: str | None = None,
        imports: Sequence[str] = [],
    ) -> Any:
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
    def get(self, id_: int) -> _StructSchema:
        """Get a schema by its ID.

        Args:
            id_: Schema node ID

        Returns:
            The schema with the given ID
        """
        ...
    def load(self, reader: _DynamicStructReader) -> _StructSchema:
        """Load a schema from a reader.

        Args:
            reader: DynamicStructReader containing schema data

        Returns:
            Loaded schema
        """
        ...
    def load_dynamic(self, reader: _DynamicStructReader) -> _StructSchema:
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
) -> Any:
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

def _write_message_to_fd(fd: int, message: _MessageBuilder) -> None:
    """Write a Cap'n Proto message to a file descriptor.

    Writes the message in unpacked format with a segment table header.

    Args:
        fd: File descriptor to write to
        message: Message to write
    """
    ...

def _write_packed_message_to_fd(fd: int, message: _MessageBuilder) -> None:
    """Write a Cap'n Proto message to a file descriptor in packed format.

    Writes the message using Cap'n Proto's packing algorithm which compresses
    runs of zero bytes.

    Args:
        fd: File descriptor to write to
        message: Message to write
    """
    ...

def fill_context(method_name: str, context: _CallContext, returned_data: Any) -> None:
    """Internal helper for filling RPC call context with returned data.

    Args:
        method_name: Name of the RPC method
        context: Call context to fill
        returned_data: Data to return to the caller
    """
    ...

def void_task_done_callback(method_name: str, fulfiller: Any, task: Any) -> None:
    """Internal callback for void RPC methods when async task completes.

    Args:
        method_name: Name of the RPC method
        fulfiller: Promise fulfiller to complete
        task: Async task that completed
    """
    ...

# Internal/private module attributes
_global_schema_parser: SchemaParser | None
"""Global schema parser instance used by import hooks and pickling (may be None).

Note: This is actually defined in capnp.lib.capnp but referenced at module level
in some internal code like pickle_helper.py.
"""

class _SchemaType:
    """Internal schema type representation.

    This class represents Cap'n Proto primitive types.
    Instances are used for type comparisons and type checking.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...

types: _CapnpTypesModule

class _DynamicListBuilder:
    """List builder type returned by init() for list fields.

    This class wraps the Cap'n Proto C++ DynamicList::Builder.
    __getitem__, __setitem__, __len__ and __iter__ have been defined properly,
    so you can treat this class mostly like any other iterable class::

        person = addressbook.Person.new_message()

        phones = person.init('phones', 2)  # This returns a _DynamicListBuilder

        phones[0].number = '555-1234'
        phones[1].number = '555-5678'

        for phone in phones:
            print(phone.number)

    For struct element types, both element instances and dict[str, Any] are accepted
    for convenient initialization, e.g.:
        list_builder[0] = {"field": value}
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def __len__(self) -> int: ...
    def __getitem__(self, index: int) -> Any: ...
    def __setitem__(self, index: int, value: Any) -> None: ...
    def __iter__(self) -> Iterator[Any]: ...
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

class _DynamicListReader:
    """List reader type for reading Cap'n Proto list fields.

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

    elementType: Any

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def __len__(self) -> int: ...
    def __getitem__(self, index: int) -> Any: ...
    def __iter__(self) -> Iterator[Any]: ...

class _DynamicOrphan:
    """Orphaned Cap'n Proto message.

    An orphan is a message that has been disowned from its parent.
    Don't use this class unless you know what you're doing.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...

class _DynamicResizableListBuilder:
    """Resizable list builder for Cap'n Proto lists.

    Returned by init_resizable_list(). Allows adding elements one at a time
    without knowing the final size upfront.
    """
    def add(self) -> Any:
        """Add a new element to the list and return a builder for it."""
        ...
    def finish(self) -> None:
        """Finish building the list. Must be called before serialization."""
        ...

class _EventLoop:
    """Cap'n Proto event loop integration.

    Internal class for managing the KJ event loop.
    """

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...

class _InterfaceModule:
    """Module/class for a generated interface.

    This is what you get when you access an interface class from a loaded schema.
    """

    def __init__(self, schema: _InterfaceSchema, name: str) -> None: ...

def _init_capnp_api() -> None:
    """Initialize the Cap'n Proto API.

    Internal function called during module initialization.
    """
    ...

# RPC Classes
class _CastableBootstrap:
    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
    def cast_as(self, interface: type[TInterface]) -> TInterface: ...

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
    def bootstrap(self) -> _CastableBootstrap:
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

    def __init__(self, *args: Any, **kwargs: Any) -> None: ...
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
    ) -> _Server:
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
    ) -> _Server:
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
    # Exception class
    "KjException",
    # Public classes
    "AsyncIoStream",
    "SchemaLoader",
    "SchemaParser",
    "TwoPartyClient",
    "TwoPartyServer",
    # Public functions
    "add_import_hook",
    "cleanup_global_schema_parser",
    "deregister_all_types",
    "fill_context",
    "kj_loop",
    "load",
    "read_multiple_bytes_packed",
    "register_type",
    "remove_import_hook",
    "run",
    "void_task_done_callback",
    # Modules
    "types",
    # Internal classes that are exposed but prefixed with underscore
    "_CapabilityClient",
    "_DynamicCapabilityClient",
    "_DynamicListBuilder",
    "_DynamicListReader",
    "_DynamicOrphan",
    "_DynamicResizableListBuilder",
    "_DynamicStructBuilder",
    "_DynamicStructReader",
    "_EventLoop",
    "_InterfaceModule",
    "_ListSchema",
    "_MallocMessageBuilder",
    "_PackedFdMessageReader",
    "_PyCustomMessageBuilder",
    "_StreamFdMessageReader",
    "_StructModule",
    "_StructSchema",
    "_init_capnp_api",
    "_write_message_to_fd",
    "_write_packed_message_to_fd",
]
