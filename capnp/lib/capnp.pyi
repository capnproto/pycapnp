import asyncio
import contextlib
import enum
from collections.abc import Awaitable, Callable, Iterator, Sequence
from types import ModuleType
from typing import IO, Any, Literal, NoReturn, overload

class KjException(Exception):
    """KjException is a wrapper of the internal C++ exception type.

    There is an enum named `Type` listed below, and a bunch of fields.
    """
    class Type:
        FAILED: str
        OVERLOADED: str
        DISCONNECTED: str
        UNIMPLEMENTED: str
        OTHER: str
        reverse_mapping: dict[str, str]

    message: str | None
    nature: str | None
    durability: str | None
    wrapper: Any

    def __init__(
        self,
        message: str | None = None,
        nature: str | None = None,
        durability: str | None = None,
        wrapper: Any = None,
        type: str | None = None,
    ) -> None: ...
    @property
    def file(self) -> str: ...
    @property
    def line(self) -> int: ...
    @property
    def type(self) -> str | None: ...
    @property
    def description(self) -> str: ...
    def _to_python(self) -> Exception: ...

class _NestedNodeReader:
    @property
    def name(self) -> str: ...
    @property
    def id(self) -> int: ...

class _List_NestedNode_Reader:
    def __len__(self) -> int: ...
    def __getitem__(self, index: int, /) -> _NestedNodeReader: ...

class _NodeReader:
    @property
    def displayName(self) -> str: ...
    @property
    def scopeId(self) -> int: ...
    @property
    def id(self) -> int: ...
    @property
    def nestedNodes(self) -> _List_NestedNode_Reader: ...
    @property
    def isStruct(self) -> bool: ...
    @property
    def isConst(self) -> bool: ...
    @property
    def isInterface(self) -> bool: ...
    @property
    def isEnum(self) -> bool: ...
    @property
    def node(self) -> _DynamicStructReader: ...

class _Schema:
    @property
    def node(self) -> _DynamicStructReader: ...
    def as_const_value(self) -> Any: ...
    def as_struct(self) -> _StructSchema: ...
    def as_interface(self) -> _InterfaceSchema: ...
    def as_enum(self) -> _EnumSchema: ...
    def get_proto(self) -> _NodeReader: ...

class _ParsedSchema(_Schema):
    def get_nested(self, name: str) -> _ParsedSchema: ...

class _StructSchema(_Schema):
    @property
    def fieldnames(self) -> tuple[str, ...]: ...
    @property
    def union_fields(self) -> tuple[str, ...]: ...
    @property
    def non_union_fields(self) -> tuple[str, ...]: ...
    @property
    def fields(self) -> dict[str, _StructSchemaField]: ...
    @property
    def fields_list(self) -> list[_StructSchemaField]: ...
    @property
    def node(self) -> _DynamicStructReader: ...

class _StructSchemaField:
    @property
    def proto(self) -> _DynamicStructReader: ...
    @property
    def schema(self) -> _StructSchema | _EnumSchema | _InterfaceSchema | _ListSchema: ...

class _InterfaceMethod:
    @property
    def param_type(self) -> _StructSchema: ...
    @property
    def result_type(self) -> _StructSchema: ...

class _EnumSchema:
    @property
    def enumerants(self) -> dict[str, int]: ...
    @property
    def node(self) -> _DynamicStructReader: ...

class _InterfaceSchema:
    @property
    def method_names(self) -> tuple[str, ...]: ...
    @property
    def method_names_inherited(self) -> set[str]: ...
    @property
    def methods(self) -> dict[str, _InterfaceMethod]: ...
    @property
    def methods_inherited(self) -> dict[str, _InterfaceMethod]: ...
    @property
    def superclasses(self) -> list[_InterfaceSchema]: ...
    @property
    def node(self) -> _DynamicStructReader: ...

class _SchemaType: ...

class _StructModuleWhich(enum.Enum):
    def __eq__(self, other: object) -> bool: ...

class _ListSchema:
    def __init__(
        self,
        schema: _StructSchema | _EnumSchema | _InterfaceSchema | _ListSchema | _SchemaType | None = None,
    ) -> None: ...
    @property
    def elementType(self) -> _StructSchema | _EnumSchema | _InterfaceSchema | _ListSchema: ...

class _StructModule:
    schema: _StructSchema

    def __init__(self, schema: _StructSchema, name: str) -> None: ...
    def __call__(self, num_first_segment_words: int | None = None, **kwargs: Any) -> _DynamicStructBuilder: ...
    def new_message(
        self,
        num_first_segment_words: int | None = None,
        allocate_seg_callable: Callable[[int], Any] | None = None,
        **kwargs: Any,
    ) -> _DynamicStructBuilder:
        """Returns a newly allocated builder message.

        :type num_first_segment_words: int
        :param num_first_segment_words: Size of the first segment to allocate (in words ie. 8 byte increments)

        :type allocate_seg_callable: Callable[[int], bytearray]
        :param allocate_seg_callable: A python callable object that takes the minimum number of 8-byte
        words to allocate (as an `int`) and returns a `bytearray`. This is used to customize the memory
        allocation strategy.

        :type kwargs: dict
        :param kwargs: A list of fields and their values to initialize in the struct.

        Note, kwargs is not an actual argument, but refers to Python's ability to pass keyword arguments.
        ie. new_message(my_field=100)

        :rtype: :class:`_DynamicStructBuilder`
        """
    def read(
        self,
        file: IO[Any],
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> _DynamicStructReader | None:
        """Returns a Reader for the unpacked object read from file.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`
        """
    async def read_async(
        self,
        stream: _AsyncIoStream,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> _DynamicStructReader:
        """Async version of read(). Returns either a message, or None in case of EOF.

        :type file: AsyncIoStream
        :param file: A AsyncIoStream

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`
        """
    def read_multiple(
        self,
        file: IO[Any],
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
        skip_copy: bool = False,
    ) -> Iterator[_DynamicStructReader]:
        """Returns an iterable, that when traversed will return Readers for messages.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type skip_copy: bool
        :param skip_copy: By default, each message is copied because the file needs to advance, even if the message is
                          never read completely. Skip this only if you know what you're doing.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`
        """
    def read_packed(
        self,
        file: IO[Any],
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> _DynamicStructReader:
        """Returns a Reader for the packed object read from file.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`
        """
    def read_multiple_packed(
        self,
        file: IO[Any],
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
        skip_copy: bool = False,
    ) -> Iterator[_DynamicStructReader]:
        """Returns an iterable, that when traversed will return Readers for messages.

        :type file: file
        :param file: A python file-like object. It must be a "real" file, with a `fileno()` method.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type skip_copy: bool
        :param skip_copy: By default, each message is copied because the file needs to advance, even if the message is
                          never read completely. Skip this only if you know what you're doing.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`
        """
    def read_multiple_bytes(
        self,
        buf: Any,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> Iterator[_DynamicStructReader]:
        """Returns an iterable, that when traversed will return Readers for messages.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`
        """
    def read_multiple_bytes_packed(
        self,
        buf: Any,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> Iterator[_DynamicStructReader]:
        """Returns an iterable, that when traversed will return Readers for messages.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: Iterable with elements of :class:`_DynamicStructReader`
        """
    @overload
    def from_bytes(
        self,
        buf: Any,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> contextlib.AbstractContextManager[_DynamicStructReader]:
        """Returns a Reader for the unpacked object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type builder: bool
        :param builder: If true, return a builder object.

        Enabling `builder` will allow you to change the contents of `buf`, so do this with care.

        :rtype: :class:`_DynamicStructReader` or :class:`_DynamicStructBuilder`
        """
    @overload
    def from_bytes(
        self,
        buf: Any,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
        builder: Literal[False] = False,
    ) -> contextlib.AbstractContextManager[_DynamicStructReader]:
        """Returns a Reader for the unpacked object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type builder: bool
        :param builder: If true, return a builder object.

        Enabling `builder` will allow you to change the contents of `buf`, so do this with care.

        :rtype: :class:`_DynamicStructReader` or :class:`_DynamicStructBuilder`
        """
    @overload
    def from_bytes(
        self,
        buf: Any,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
        *,
        builder: Literal[True],
    ) -> contextlib.AbstractContextManager[_DynamicStructBuilder]:
        """Returns a Reader for the unpacked object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type builder: bool
        :param builder: If true, return a builder object.

        Enabling `builder` will allow you to change the contents of `buf`, so do this with care.

        :rtype: :class:`_DynamicStructReader` or :class:`_DynamicStructBuilder`
        """
    @overload
    def from_bytes(
        self,
        buf: Any,
        traversal_limit_in_words: int | None,
        nesting_limit: int | None,
        builder: Literal[True],
    ) -> contextlib.AbstractContextManager[_DynamicStructBuilder]:
        """Returns a Reader for the unpacked object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :type builder: bool
        :param builder: If true, return a builder object.

        Enabling `builder` will allow you to change the contents of `buf`, so do this with care.

        :rtype: :class:`_DynamicStructReader` or :class:`_DynamicStructBuilder`
        """
    def from_segments(
        self,
        segments: Sequence[Any],
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> _DynamicStructReader:
        """Returns a Reader for a list of segment bytes.

        This avoids making copies.

        NB: This is not currently supported on PyPy.

        :rtype: list
        """
    def from_bytes_packed(
        self,
        buf: Any,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> _DynamicStructReader:
        """Returns a Reader for the packed object in buf.

        :type buf: buffer
        :param buf: Any Python object that supports the readable buffer interface.

        :type traversal_limit_in_words: int
        :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                         Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

        :type nesting_limit: int
        :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

        :rtype: :class:`_DynamicStructReader`
        """

class _EnumModule:
    schema: _EnumSchema

    def __init__(self, schema: _EnumSchema, name: str) -> None: ...

class _InterfaceModule:
    schema: _InterfaceSchema

    def __init__(self, schema: _InterfaceSchema, name: str) -> None: ...
    def _new_client(self, server: _DynamicCapabilityServer) -> _DynamicCapabilityClient: ...

class _DynamicEnum:
    _parent: Any

    @property
    def raw(self) -> int: ...
    def _as_str(self) -> str: ...

class _DynamicEnumField:
    @property
    def raw(self) -> int: ...
    def _str(self) -> str: ...
    def __call__(self, *args: NoReturn, **kwargs: NoReturn) -> str: ...

class _DynamicObjectReader:
    _parent: Any

    def as_struct(self, schema: _StructSchema | _StructModule) -> _DynamicStructReader: ...
    def as_interface(self, schema: _InterfaceSchema | _InterfaceModule) -> _DynamicCapabilityClient: ...
    def as_list(self, schema: _ListSchema) -> _DynamicListReader: ...
    def as_text(self) -> str: ...

class _DynamicObjectBuilder:
    _parent: Any

    def as_struct(self, schema: _StructSchema | _StructModule) -> _DynamicStructBuilder: ...
    def as_interface(self, schema: _InterfaceSchema | _InterfaceModule) -> _DynamicCapabilityClient: ...
    def as_list(self, schema: _ListSchema) -> _DynamicListBuilder: ...
    def set(self, other: Any) -> None:
        """Set value of this object with the value of another AnyPointer::Reader. Don't use this for structs"""
    def set_as_text(self, text: str) -> None: ...
    def init_as_list(self, schema: _ListSchema, size: int) -> _DynamicListBuilder: ...
    def as_text(self) -> str: ...
    def as_reader(self) -> _DynamicObjectReader: ...

class _MessageSize:
    word_count: int
    cap_count: int

    def __init__(self, word_count: int, cap_count: int) -> None: ...

class _DynamicStructReader:
    """Reads Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Reader.
    The only difference is that instead of a `get` method, __getattr__ is overloaded and the field name
    is passed onto the C++ equivalent `get`. This means you just use . syntax to access any field.
    For field names that don't follow valid python naming convention for fields, use the global function
    :py:func:`getattr`::

        person = addressbook.Person.read(file) # This returns a _DynamicStructReader
        print person.name # using . syntax
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """

    _parent: Any
    is_root: bool

    def __getattr__(self, field: str, /) -> Any: ...
    @property
    def which(self) -> _DynamicEnumField:
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
    @property
    def schema(self) -> _StructSchema: ...
    @property
    def total_size(self) -> _MessageSize: ...
    def _get(self, field: str) -> Any: ...
    def _get_by_field(self, field: _StructSchemaField) -> Any: ...
    def _has(self, field: str) -> bool: ...
    def _has_by_field(self, field: _StructSchemaField) -> bool: ...
    def get_data_as_view(self, field: str) -> memoryview:
        """Efficiently get a read-only memoryview for a DATA field without copying.

        .. warning::
            The returned memoryview *borrows* memory owned by this message. It stays valid while
            the memoryview (and any object derived from it) is alive; an internal exporter pins
            this reader for that duration. Do not let the message be mutated underneath an
            outstanding view.

        An unset/empty DATA field yields a valid, zero-length view (it does not raise).
        """
    def _which_str(self) -> str: ...
    def _which(self) -> _DynamicEnumField:
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
    def as_builder(
        self,
        num_first_segment_words: int | None = None,
        allocate_seg_callable: Callable[[int], Any] | None = None,
    ) -> _DynamicStructBuilder:
        """A method for casting this Reader to a Builder

        This is a copying operation with respect to the message's buffer.
        Changes in the new builder will not reflect in the original reader.

        :type num_first_segment_words: int
        :param num_first_segment_words: Size of the first segment to allocate (in words ie. 8 byte increments)

        :type allocate_seg_callable: Callable[[int], Buffer]
        :param allocate_seg_callable: A python callable object that takes the minimum number of 8-byte
        words to allocate (as an `int`) and returns any object supporting the writable buffer protocol
        (e.g., `bytearray`, `memoryview`, `numpy.ndarray`). This enables custom memory allocation
        strategies including shared memory.

        :rtype: :class:`_DynamicStructBuilder`
        """
    def to_dict(
        self,
        verbose: bool = False,
        ordered: bool = False,
        encode_bytes_as_base64: bool = False,
    ) -> dict[str, Any]: ...

class _DynamicStructBuilder:
    """Builds Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Builder.
    The only difference is that instead of a `get`/`set` method, __getattr__/__setattr__ is overloaded
    and the field name is passed onto the C++ equivalent function.

    This means you just use . syntax to access or set any field. For field names that don't follow valid
    python naming convention for fields, use the global functions :py:func:`getattr`/:py:func:`setattr`::

        person = addressbook.Person.new_message() # This returns a _DynamicStructBuilder

        person.name = 'foo' # using . syntax
        print person.name # using . syntax

        setattr(person, 'field-with-hyphens', 'foo') # for names that are invalid for python, use setattr
        print getattr(person, 'field-with-hyphens') # for names that are invalid for python, use getattr
    """

    _parent: Any
    is_root: bool
    _is_written: bool

    def __getattr__(self, field: str, /) -> Any: ...
    def __setattr__(self, field: str, value: Any, /) -> None: ...
    @property
    def which(self) -> _DynamicEnumField:
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
    @property
    def schema(self) -> _StructSchema: ...
    @property
    def total_size(self) -> _MessageSize: ...
    def _get(self, field: str) -> Any: ...
    def _get_by_field(self, field: _StructSchemaField) -> Any: ...
    def _set(self, field: str, value: Any) -> None: ...
    def _set_by_field(self, field: _StructSchemaField, value: Any) -> None: ...
    def _has(self, field: str) -> bool: ...
    def _has_by_field(self, field: _StructSchemaField) -> bool: ...
    def init(self, field: str, size: int | None = None) -> Any:
        """Method for initializing fields that are of type union/struct/list

        Typically, you don't have to worry about initializing structs/unions, so this method is mainly for lists.

        :type field: str
        :param field: The field name to initialize

        :type size: int
        :param size: The size of the list to initiialize. This should be None for struct/union initialization.

        :rtype: :class:`_DynamicStructBuilder` or :class:`_DynamicListBuilder`

        :Raises: :exc:`KjException` if the field isn't in this struct
        """
    def _init_by_field(self, field: _StructSchemaField, size: int | None = None) -> Any:
        """Method for initializing fields that are of type union/struct/list

        Typically, you don't have to worry about initializing structs/unions, so this method is mainly for lists.

        :type field: str
        :param field: The field name to initialize

        :type size: int
        :param size: The size of the list to initiialize. This should be None for struct/union initialization.

        :rtype: :class:`_DynamicStructBuilder` or :class:`_DynamicListBuilder`

        :Raises: :exc:`KjException` if the field isn't in this struct
        """
    def init_resizable_list(self, field: str) -> _DynamicResizableListBuilder:
        """Method for initializing fields that are of type list (of structs)

        This version of init returns a :class:`_DynamicResizableListBuilder` that allows
        you to add members one at a time (ie. if you don't know the size for sure).
        This is only meant for lists of Cap'n Proto objects, since for primitive types
        you can just define a normal python list and fill it yourself.

        .. warning::
            You need to call :meth:`_DynamicResizableListBuilder.finish` on the
            list object before serializing the Cap'n Proto message. Failure to do
            so will cause your objects not to be written out as well as leaking
            orphan structs into your message.

        :type field: str
        :param field: The field name to initialize

        :rtype: :class:`_DynamicResizableListBuilder`

        :Raises: :exc:`KjException` if the field isn't in this struct
        """
    def _which_str(self) -> str: ...
    def _which(self) -> _DynamicEnumField:
        """Returns the enum corresponding to the union in this struct

        :rtype: :class:`_DynamicEnumField`
        :return: A string/enum corresponding to what field is set in the union

        :Raises: :exc:`KjException` if this struct doesn't contain a union
        """
    def adopt(self, field: str, orphan: _DynamicOrphan) -> None:
        """A method for adopting Cap'n Proto orphans

        Don't use this method unless you know what you're doing.
        Orphans are useful for dynamically allocating objects for an unknown sized list.

        :type field: str
        :param field: The field name in the struct

        :type orphan: :class:`_DynamicOrphan`
        :param orphan: A Cap'n proto orphan to adopt. It will be unusable after this operation.

        :rtype: void
        """
    def disown(self, field: str) -> _DynamicOrphan:
        """A method for disowning Cap'n Proto orphans

        Don't use this method unless you know what you're doing.

        :type field: str
        :param field: The field name in the struct

        :rtype: :class:`_DynamicOrphan`
        """
    def get_data_as_view(self, field: str) -> memoryview:
        """Efficiently get a writable memoryview for a DATA field without copying.

        This allows in-place modification of the underlying buffer::

            msg.get_data_as_view('myField')[0] = 0xFF

        .. warning::
            The returned memoryview *borrows* mutable memory owned by this message builder. It is
            valid while the memoryview (and any object derived from it) is alive; an internal
            exporter pins this builder for that duration. Do NOT mutate, re-set, reset, or reuse the
            builder while a view is outstanding -- including calls that may allocate (e.g. getting
            an unset pointer/struct/list field), since those can relocate or stale the borrowed
            memory. Sharing a view across threads or ``await`` points while the builder may change
            is a data race.

        An unset/empty DATA field yields a valid but zero-length view (writes are no-ops); to write
        into the field, initialize it to the desired size first.
        """
    def as_reader(self) -> _DynamicStructReader:
        """A method for casting this Builder to a Reader

        This is a non-copying operation with respect to the message's buffer.
        This means changes to the fields in the original struct will carry over to the new reader.

        :rtype: :class:`_DynamicStructReader`
        """
    def copy(
        self,
        num_first_segment_words: int | None = None,
        allocate_seg_callable: Callable[[int], Any] | None = None,
    ) -> _DynamicStructBuilder:
        """A method for copying this Builder

        This is a copying operation with respect to the message's buffer.
        Changes in the new builder will not reflect in the original reader.

        :type num_first_segment_words: int
        :param num_first_segment_words: Size of the first segment to allocate (in words ie. 8 byte increments)

        :type allocate_seg_callable: Callable[[int], Buffer]
        :param allocate_seg_callable: A python callable object that takes the minimum number of 8-byte
        words to allocate (as an `int`) and returns any object supporting the writable buffer protocol
        (e.g., `bytearray`, `memoryview`, `numpy.ndarray`). This enables custom memory allocation
        strategies including shared memory.

        :rtype: :class:`_DynamicStructBuilder`
        """
    def to_dict(
        self,
        verbose: bool = False,
        ordered: bool = False,
        encode_bytes_as_base64: bool = False,
    ) -> dict[str, Any]: ...
    def from_dict(self, d: dict[str, Any]) -> None: ...
    def clear_write_flag(self) -> None:
        """A method used to clear the _is_written flag.

        This allows you to write the struct more than once without seeing any warnings.
        """
    def to_bytes(self) -> bytes:
        """Returns the struct's containing message as a Python bytes object in the unpacked binary format.

        This is inefficient; it makes several copies.

        :rtype: bytes

        :Raises: :exc:`KjException` if this isn't the message's root struct.
        """
    def to_segments(self) -> list[bytes]:
        """Returns the struct's containing message as a Python list of Python bytes objects.

        This copies each output segment into a Python-owned bytes object. Use
        to_segment_views() for zero-copy, read-only borrowed segment views.

        NB: This is not currently supported on PyPy.

        :rtype: list
        """
    def to_segment_views(self) -> Sequence[Any]:
        """Returns the struct's containing message as zero-copy, read-only segment views.

        The returned object is a sequence of read-only buffer-protocol views, one per output
        segment. Each view borrows memory owned by the message builder; the segment pointers and
        sizes are captured eagerly at call time (a snapshot).

        .. warning::
            The views (and any buffer exported from them, e.g. by ``memoryview()`` or by a
            consumer that holds them) keep the builder pinned and remain valid only while no
            mutation happens. Do NOT mutate, re-set, reset, or reuse the builder while any view or
            exported buffer is still alive -- this includes calls that may allocate (e.g. getting
            an unset pointer/struct/list field). Mutating after the snapshot can grow/relocate
            segments, leaving the views pointing at stale or truncated data. Sharing the views
            across threads or ``await`` points while the builder may change is a data race.

            Lifetime is enforced only by buffer-protocol reference counting (memory is not freed
            while a view is held); correctness of the *contents* is the caller's responsibility.

        :rtype: sequence
        """
    def _to_bytes_packed_helper(self, word_count: int) -> bytes: ...
    def to_bytes_packed(self) -> bytes: ...
    def write(self, file: IO[Any]) -> None:
        """Writes the struct's containing message to the given file object in unpacked binary format.

        This is a shortcut for calling capnp._write_message_to_fd().  This can only be called on the
        message's root struct.

        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.

        :rtype: void

        :Raises: :exc:`KjException` if this isn't the message's root struct.
        """
    async def write_async(self, stream: _AsyncIoStream) -> None:
        """Async version of of write().

        This is a shortcut for calling capnp._write_message_to_fd().  This can only be called on the
        message's root struct.

        :type file: AsyncIoStream
        :param file: The AsyncIoStream to write the message to

        :rtype: void

        :Raises: :exc:`KjException` if this isn't the message's root struct.
        """
    def write_packed(self, file: IO[Any]) -> None:
        """Writes the struct's containing message to the given file object in packed binary format.

        This is a shortcut for calling capnp._write_packed_message_to_fd().  This can only be called on
        the message's root struct.

        :type file: file
        :param file: A file or socket object (or anything with a fileno() method), open for write.

        :rtype: void

        :Raises: :exc:`KjException` if this isn't the message's root struct.
        """

class _Request(_DynamicStructBuilder):
    is_consumed: bool

    def send(self) -> _RemotePromise: ...

class _Response(_DynamicStructReader): ...

class _CallContext:
    @property
    def params(self) -> _DynamicStructReader: ...
    @property
    def results(self) -> _DynamicStructBuilder: ...
    def _get_results(self, word_count: int = 0) -> _DynamicStructBuilder: ...
    def release_params(self) -> None: ...
    def tail_call(self, tailRequest: _Request) -> _Promise: ...

class _DynamicCapabilityClient:
    _parent: Any
    _cached_schema: _InterfaceSchema | None

    def __getattr__(self, name: str, /) -> Any: ...
    @property
    def schema(self) -> _InterfaceSchema: ...
    def _find_method_args(self, method_name: str) -> Any: ...
    def _send_helper(
        self,
        name: str,
        word_count: int | None,
        args: tuple[Any, ...],
        kwargs: dict[str, Any],
    ) -> _RemotePromise: ...
    def _request_helper(
        self,
        name: str,
        firstSegmentWordSize: int | None,
        args: tuple[Any, ...],
        kwargs: dict[str, Any],
    ) -> _Request: ...
    def _request(self, name: str, *args: Any, word_count: int | None = None, **kwargs: Any) -> _Request: ...
    def _send(self, name: str, *args: Any, word_count: int | None = None, **kwargs: Any) -> _RemotePromise: ...
    def upcast(self, schema: _InterfaceSchema | _InterfaceModule) -> _DynamicCapabilityClient: ...
    def cast_as(self, schema: _InterfaceSchema | _InterfaceModule) -> _DynamicCapabilityClient: ...

class _DynamicCapabilityServer: ...

class _CapabilityClient:
    _parent: Any

    def cast_as(self, schema: _InterfaceSchema | _InterfaceModule) -> _DynamicCapabilityClient: ...

class _Promise:
    def cancel(self) -> None: ...

class _RemotePromise:
    def __getattr__(self, field: str, /) -> _DynamicStructPipeline: ...
    def __await__(self) -> Iterator[Any]: ...
    @property
    def schema(self) -> _StructSchema: ...
    def _get(self, field: str) -> _DynamicStructPipeline: ...
    def to_dict(
        self,
        verbose: bool = False,
        ordered: bool = False,
        encode_bytes_as_base64: bool = False,
    ) -> dict[str, Any]: ...
    def cancel(self) -> None: ...

class _DynamicStructPipeline:
    """Reads Cap'n Proto structs

    This class is almost a 1 for 1 wrapping of the Cap'n Proto C++ DynamicStruct::Pipeline.
    The only difference is that instead of a `get` method, __getattr__ is overloaded and the
    field name is passed onto the C++ equivalent `get`. This means you just use . syntax to
    access any field. For field names that don't follow valid python naming convention for fields,
    use the global function :py:func:`getattr`::
    """

    _parent: Any

    def __getattr__(self, field: str, /) -> Any: ...
    @property
    def schema(self) -> _StructSchema: ...
    def _get(self, field: str) -> Any: ...
    def to_dict(
        self,
        verbose: bool = False,
        ordered: bool = False,
        encode_bytes_as_base64: bool = False,
    ) -> dict[str, Any]: ...

class _MessageBuilder:
    """An abstract base class for building Cap'n Proto messages

    .. warning:: Don't ever instantiate this class directly. It is only used for inheritance.
    """
    def __init__(self, *args: NoReturn, **kwargs: NoReturn) -> None: ...
    def init_root(self, schema: _StructModule) -> _DynamicStructBuilder:
        """A method for instantiating Cap'n Proto structs

        You will need to pass in a schema to specify which struct to
        instantiate. Schemas are available in a loaded Cap'n Proto module::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.init_root(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructBuilder`
        :return: An object where you will set all the members
        """
    def get_root(self, schema: _StructModule) -> _DynamicStructBuilder:
        """A method for instantiating Cap'n Proto structs, from an already pre-written buffer

        Don't use this method unless you know what you're doing. You probably
        want to use init_root instead::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.init_root(addressbook.Person)
            ...
            person = message.get_root(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructBuilder`
        :return: An object where you will set all the members
        """
    def get_root_as_any(self) -> _DynamicObjectBuilder:
        """A method for getting a Cap'n Proto AnyPointer, from an already pre-written buffer

        Don't use this method unless you know what you're doing.

        :rtype: :class:`_DynamicObjectBuilder`
        :return: An AnyPointer that you can set fields in
        """
    def set_root(self, value: Any) -> None:
        """A method for instantiating Cap'n Proto structs by copying from an existing struct

        :type value: :class:`_DynamicStructReader`
        :param value: A Cap'n Proto struct value to copy

        :rtype: void
        """
    def get_segments_for_output(self) -> list[bytes]: ...
    def new_orphan(self, schema: _StructModule) -> _DynamicOrphan:
        """A method for instantiating Cap'n Proto orphans

        Don't use this method unless you know what you're doing.
        Orphans are useful for dynamically allocating objects for an unknown sized list, ie::

            addressbook = capnp.load('addressbook.capnp')
            m = capnp._MallocMessageBuilder()
            alice = m.new_orphan(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicOrphan`
        :return: An orphan representing a :class:`_DynamicStructBuilder`
        """

class _MallocMessageBuilder(_MessageBuilder):
    """The main class for building Cap'n Proto messages

    You will use this class to handle arena allocation of the Cap'n Proto
    messages. You also use this object when you're done assigning to Cap'n
    Proto objects, and wish to serialize them::

        addressbook = capnp.load('addressbook.capnp')
        message = capnp._MallocMessageBuilder()
        person = message.init_root(addressbook.Person)
        person.name = 'alice'
        ...
        f = open('out.txt', 'w')
        _write_message_to_fd(f.fileno(), message)
    """
    def __init__(self, size: int | None = None) -> None: ...

class _PyCustomMessageBuilder(_MessageBuilder):
    """The class for building Cap'n Proto messages,
    with customised memory allocation strategy

    You will use this class if you want to customise the allocateSegment method,
    and define your own memory allocation strategy.
    """
    def __init__(self, allocate_seg_callable: Callable[[int], Any], size: int | None = None) -> None:
        """The constructor requires you to provide a Python callable object as a parameter.
        This callable object will be invoked in the allocateSegment method of the MessageBuilder
        to allocate memory. The allocated memory will be managed within the MessageBuilder.

        :type allocate_seg_callable: Callable[[int], Buffer]
        :param allocate_seg_callable: A python callable object that takes the minimum number of 8-byte
        words to allocate (as an `int`) and returns any object supporting the writable buffer protocol
        (e.g., `bytearray`, `memoryview`, `numpy.ndarray`). This enables custom memory allocation
        strategies including shared memory.

        Required function signature is like this:
        def __call__(self, minimum_size: int) -> Buffer:

        Where `Buffer` is any object that:
          - Supports the Python buffer protocol (PyObject_GetBuffer)
          - Is writable
        Note that the unit of minimum_size is words, ie. 8 byte increments.

        The underlying memory must remain valid for the lifetime of the MessageBuilder.
        If returning a view (e.g., `memoryview`, `numpy.ndarray`) that wraps external memory,
        the allocator is responsible for properly managing the memory lifecycle。

        Examples:

            # Example 1: Simple bytearray allocator
            class Allocator:
                def __init__(self):
                    self.cur_size = 0
                def __call__(self, minimum_size: int) -> bytearray:
                    size = max(minimum_size, self.cur_size)
                    self.cur_size += size
                    WORD_SIZE = 8
                    byte_count = size * WORD_SIZE
                    return bytearray(byte_count)

            addressbook = capnp.load('addressbook.capnp')
            allocator = Allocator()
            message = capnp._PyCustomMessageBuilder(allocator)
            person = message.init_root(addressbook.Person)

            # Example 2: Shared memory allocator (zero-copy)
            import ctypes

            class ShmAllocator:
                def __init__(self, shm_pool):
                    self.shm = shm_pool
                    self.buffers = []

                def __call__(self, minimum_size: int) -> memoryview:
                    size = minimum_size * 8
                    ptr = self.shm.allocate(size)
                    buffer = (ctypes.c_uint8 * size).from_address(ptr)
                    self.buffers.append(buffer)
                    return memoryview(buffer)

                def release(self):
                    for buffer in self.buffers:
                        ptr = ctypes.addressof(buffer)
                        size = ctypes.sizeof(buffer)
                        self.shm.deallocate(ptr, size)
                    self.buffers.clear()

        :type size: int
        :param size: Size of the first segment to allocate (in words ie. 8 byte increments)
        """

class _MessageReader:
    """An abstract base class for reading Cap'n Proto messages

    .. warning:: Don't ever instantiate this class. It is only used for inheritance.
    """

    _parent: Any

    def __init__(self, *args: NoReturn, **kwargs: NoReturn) -> None: ...
    def get_root(self, schema: _StructModule) -> _DynamicStructReader:
        """A method for instantiating Cap'n Proto structs

        You will need to pass in a schema to specify which struct to
        instantiate. Schemas are available in a loaded Cap'n Proto module::

            addressbook = capnp.load('addressbook.capnp')
            ...
            person = message.get_root(addressbook.Person)

        :type schema: Schema
        :param schema: A Cap'n proto schema specifying which struct to instantiate

        :rtype: :class:`_DynamicStructReader`
        :return: An object with all the data of the read Cap'n Proto message.
            Access members with . syntax.
        """
    def get_root_as_any(self) -> _DynamicObjectReader:
        """A method for getting a Cap'n Proto AnyPointer, from an already pre-written buffer

        Don't use this method unless you know what you're doing.

        :rtype: :class:`_DynamicObjectReader`
        :return: An AnyPointer that you can read from
        """

class _PackedFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor in a packed manner

    You use this class to for reading message(s) from a file. It's analagous to the inverse of
    :func:`_write_packed_message_to_fd` and :class:`_MessageBuilder`, but in one class.::

        f = open('out.txt')
        message = _PackedFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(
        self,
        file: IO[Any],
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> None: ...

class _StreamFdMessageReader(_MessageReader):
    """Read a Cap'n Proto message from a file descriptor

    You use this class to for reading message(s) from a file. It's analagous to the inverse of
    :func:`_write_message_to_fd` and :class:`_MessageBuilder`, but in one class::

        f = open('out.txt')
        message = _StreamFdMessageReader(f)
        person = message.get_root(addressbook.Person)
        print person.name

    :Parameters: - fd (`int`) - A file descriptor
    """
    def __init__(
        self,
        file: IO[Any],
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> None: ...

class SchemaLoader:
    """Class which can be used to construct Schema objects from schema::Nodes as defined in
    schema.capnp.

    This class wraps capnproto/c++/src/capnp/schema-loader.h directly.
    """
    def load(self, reader: _NodeReader) -> _Schema:
        """Loads the given schema node.  Validates the node and throws an exception if invalid.  This
        makes a copy of the schema, so the object passed in can be destroyed after this returns.
        """
    def load_dynamic(self, reader: _DynamicStructReader) -> _Schema:
        """Loads the given schema node with self.load, but converts from a _DynamicStructReader
        first.
        """
    def get(self, id_: int) -> _Schema:
        """Gets the schema for the given ID, throwing an exception if it isn't present."""

class SchemaParser:
    """A class for loading Cap'n Proto schema files.

    Do not use this class unless you're sure you know what you're doing.
    Use the convenience method :func:`load` instead.
    """

    modules_by_id: dict[int, ModuleType]

    def load(
        self,
        file_name: str,
        display_name: str | None = None,
        imports: Sequence[str] = [],
    ) -> ModuleType:
        """Load a Cap'n Proto schema from a file

        You will have to load a schema before you can begin doing anything
        meaningful with this library. Loading a schema is much like loading
        a Python module (and load even returns a `ModuleType`). Once it's been
        loaded, you use it much like any other Module::

            parser = capnp.SchemaParser()
            addressbook = parser.load('addressbook.capnp')
            print addressbook.qux # qux is a top level constant
            # 123
            person = addressbook.Person.new_message()

        :type file_name: str
        :param file_name: A relative or absolute path to a Cap'n Proto schema

        :type display_name: str
        :param display_name: The name internally used by the Cap'n Proto library
            for the loaded schema. By default, it's just os.path.basename(file_name)

        :type imports: list
        :param imports: A list of str directories to add to the import path.

        :rtype: ModuleType
        :return: A module corresponding to the loaded schema. You can access
            parsed schemas and constants with . syntax

        :Raises:
            - :exc:`exceptions.IOError` if `file_name` doesn't exist
            - :exc:`KjException` if the Cap'n Proto C++ library has any problems loading the schema
        """
    def _parse_disk_file(
        self,
        displayName: str,
        diskPath: str,
        imports: Sequence[str],
    ) -> _ParsedSchema: ...

class _DynamicListBuilder:
    """Class for building Cap'n Proto Lists

    This class thinly wraps the C++ Cap'n Proto DynamicList::Bulder class. __getitem__, __setitem__, and __len__
    have been defined properly, so you can treat this class mostly like any other iterable class::

        ...
        person = addressbook.Person.new_message()

        phones = person.init('phones', 2) # This returns a _DynamicListBuilder

        phone = phones[0]
        phone.number = 'foo'
        phone = phones[1]
        phone.number = 'bar'

        for phone in phones:
            print phone.number
    """

    _parent: Any

    def __len__(self) -> int: ...
    def __getitem__(self, index: int, /) -> Any: ...
    def __setitem__(self, index: int, value: Any, /) -> None: ...
    def _get(self, index: int) -> Any: ...
    def _set(self, index: int, value: Any) -> None: ...
    def adopt(self, index: int, orphan: _DynamicOrphan) -> None:
        """A method for adopting Cap'n Proto orphans

        Don't use this method unless you know what you're doing.
        Orphans are useful for dynamically allocating objects for an unknown sized list.

        :type index: int
        :param index: The index of the element in the list to replace with the newly adopted object

        :type orphan: :class:`_DynamicOrphan`
        :param orphan: A Cap'n proto orphan to adopt. It will be unusable after this operation.

        :rtype: void
        """
    def disown(self, index: int) -> _DynamicOrphan:
        """A method for disowning Cap'n Proto orphans

        Don't use this method unless you know what you're doing.

        :type index: int
        :param index: The index of the element in the list to disown

        :rtype: :class:`_DynamicOrphan`
        """
    def init(self, index: int, size: int) -> Any:
        """A method for initializing an element in a list

        :type index: int
        :param index: The index of the element in the list

        :type size: int
        :param size: Size of the element to be initialized.
        """

class _DynamicListReader:
    """Class for reading Cap'n Proto Lists

    This class thinly wraps the C++ Cap'n Proto DynamicList::Reader class. __getitem__ and __len__
    have been defined properly, so you can treat this class mostly like any other iterable class::

        ...
        person = addressbook.Person.read(file)

        phones = person.phones # This returns a _DynamicListReader

        phone = phones[0]
        print phone.number

        for phone in phones:
            print phone.number
    """

    _parent: Any

    def __len__(self) -> int: ...
    def __getitem__(self, index: int, /) -> Any: ...
    def _get(self, index: int) -> Any: ...

class _DynamicOrphan:
    _parent: Any

    def get(self) -> Any:
        """Returns a python object corresponding to the DynamicValue owned by this orphan

        Use this DynamicValue to set fields inside the orphan
        """

class _DynamicResizableListBuilder:
    """Class for building growable Cap'n Proto Lists

    .. warning::
        You need to call :meth:`finish` on this object before serializing the
        Cap'n Proto message. Failure to do so will cause your objects not to be
        written out as well as leaking orphan structs into your message.

    This class works much like :class:`_DynamicListBuilder`, but it allows growing the list dynamically.
    It is meant for lists of structs, since for primitive types like int or float, you're much better off
    using a normal python list and then serializing straight to a Cap'n Proto list.
    It has __getitem__ and __len__ defined, but not __setitem__::

        ...
        person = addressbook.Person.new_message()

        phones = person.init_resizable_list('phones') # This returns a _DynamicResizableListBuilder

        phone = phones.add()
        phone.number = 'foo'
        phone = phones.add()
        phone.number = 'bar'

        phones.finish()

        f = open('example', 'w')
        person.write(f)
    """

    _parent: Any

    def __init__(self, parent: _DynamicStructBuilder, field: Any, schema: Any) -> None: ...
    def __len__(self) -> int: ...
    def __getitem__(self, index: int, /) -> Any: ...
    def _get(self, index: int) -> Any: ...
    def add(self) -> Any:
        """A method for adding a new struct to the list

        This will return a struct, in which you can set fields that will be reflected in the serialized
        Cap'n Proto message.

        :rtype: :class:`_DynamicStructBuilder`
        """
    def finish(self) -> None:
        """A method for closing this list and serializing all its members to the message

        If you don't call this method, the items you previously added from this object will leak into the message,
        ie. inaccessible but still taking up space.
        """

class _EventLoop: ...

class TwoPartyClient:
    """TwoPartyClient for RPC Communication

    :param socket: AsyncIoStream
    :param traversal_limit_in_words: Pointer derefence limit (see https://capnproto.org/cxx.html).
    :param nesting_limit: Recursive limit when reading types (see https://capnproto.org/cxx.html).
    """
    def __init__(
        self,
        socket: _AsyncIoStream | None = None,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> None: ...
    def close(self) -> None: ...
    def bootstrap(self) -> _CapabilityClient: ...
    def on_disconnect(self) -> Awaitable[None]: ...

class TwoPartyServer:
    """TwoPartyServer for RPC Communication

    :param socket: AsyncIoStream
    :param bootstrap: Class object defining the implementation of the Cap'n'proto interface.
    :param traversal_limit_in_words: Pointer derefence limit (see https://capnproto.org/cxx.html).
    :param nesting_limit: Recursive limit when reading types (see https://capnproto.org/cxx.html).
    """
    def __init__(
        self,
        socket: _AsyncIoStream | None = None,
        bootstrap: Any = None,
        traversal_limit_in_words: int | None = None,
        nesting_limit: int | None = None,
    ) -> None: ...
    def close(self) -> None: ...
    def bootstrap(self) -> _CapabilityClient: ...
    def on_disconnect(self) -> Awaitable[None]: ...

class _AsyncIoStream:
    def __init__(self, *args: NoReturn, **kwargs: NoReturn) -> None: ...
    @staticmethod
    async def create_connection(host: str | None = None, port: int | None = None, **kwargs: Any) -> _AsyncIoStream:
        """Create a TCP connection.

        All parameters given to this function are passed to `asyncio.get_running_loop().create_connection()`.
        See that function for documentation on the possible arguments.
        """
    @staticmethod
    async def create_unix_connection(path: str | None = None, **kwargs: Any) -> _AsyncIoStream:
        """Create a Unix socket connection.

        All parameters given to this function are passed to `asyncio.get_running_loop().create_unix_connection()`.
        See that function for documentation on the possible arguments.
        """
    @staticmethod
    async def create_server(
        callback: Callable[[_AsyncIoStream], Awaitable[None]],
        host: str | None = None,
        port: int | None = None,
        **kwargs: Any,
    ) -> asyncio.Server:
        """Create a TCP connection server.

        The `callback` parameter will be called whenever a new connection is made. It receives a `AsyncIoStream`
        instance as its only argument. If the result of `callback` is a coroutine, it will be scheduled as a task.

        This function behaves similarly to `asyncio.get_running_loop().create_server()`. All arguments except
        for `callback` will be passed directly to that function, and the server returned is similar as well.
        See that function for documentation on the possible arguments.
        """
    @staticmethod
    async def create_unix_server(
        callback: Callable[[_AsyncIoStream], Awaitable[None]],
        path: str | None = None,
        **kwargs: Any,
    ) -> asyncio.Server:
        """Create a unix connection server.

        The `callback` parameter will be called whenever a new connection is made. It receives a `AsyncIoStream`
        instance as its only argument. If the result of `callback` is a coroutine, it will be scheduled as a task.

        This function behaves similarly to `asyncio.get_running_loop().create_server()`. All arguments except
        for `callback` will be passed directly to that function, and the server returned is similar as well.
        See that function for documentation on the possible arguments.
        """
    def close(self) -> None: ...
    async def wait_closed(self) -> None: ...

types: ModuleType
_global_schema_parser: SchemaParser | None

def register_type(id: int, klass: type[Any]) -> None: ...
def deregister_all_types() -> None: ...
def void_task_done_callback(method_name: str, fulfiller: Any, task: Any) -> None: ...
def fill_context(method_name: str, context: _CallContext, returned_data: Any) -> None: ...
def add_import_hook() -> None:
    """Add a hook to the python import system, so that Cap'n Proto modules are directly importable

    After calling this function, you can use the python import syntax to directly import capnproto schemas.
    This function is automatically called upon first import of `capnp`,
    so you will typically never need to use this function.::

        import capnp
        capnp.add_import_hook()

        import addressbook_capnp
        # equivalent to capnp.load('addressbook.capnp', 'addressbook', sys.path),
        # except it will search for 'addressbook.capnp' in all directories of sys.path
    """

def remove_import_hook() -> None:
    """Remove the import hook, and return python's import to normal"""

def load(
    file_name: str,
    display_name: str | None = None,
    imports: Sequence[str] = [],
) -> ModuleType:
    """Load a Cap'n Proto schema from a file

    You will have to load a schema before you can begin doing anything
    meaningful with this library. Loading a schema is much like loading
    a Python module (and load even returns a `ModuleType`). Once it's been
    loaded, you use it much like any other Module::

        addressbook = capnp.load('addressbook.capnp')
        print addressbook.qux # qux is a top level constant in the addressbook.capnp schema
        # 123
        person = addressbook.Person.new_message()

    :type file_name: str
    :param file_name: A relative or absolute path to a Cap'n Proto schema

    :type display_name: str
    :param display_name: The name internally used by the Cap'n Proto library
        for the loaded schema. By default, it's just os.path.basename(file_name)

    :type imports: list
    :param imports: A list of str directories to add to the import path.

    :rtype: ModuleType
    :return: A module corresponding to the loaded schema. You can access
        parsed schemas and constants with . syntax

    :Raises: :exc:`KjException` if `file_name` doesn't exist
    """

def cleanup_global_schema_parser() -> None:
    """Unloads all of the schema from the current context"""

def read_multiple_bytes_packed(
    buf: Any,
    traversal_limit_in_words: int | None = None,
    nesting_limit: int | None = None,
) -> Iterator[_DynamicStructReader]:
    """Returns an iterable, that when traversed will return Readers for AnyPointer messages.

    :type buf: buffer
    :param buf: Any Python object that supports the buffer interface.

    :type traversal_limit_in_words: int
    :param traversal_limit_in_words: Limits how many total words of data are allowed to be traversed.
                                        Is actually a uint64_t, and values can be up to 2^64-1. Default is 8*1024*1024.

    :type nesting_limit: int
    :param nesting_limit: Limits how many total words of data are allowed to be traversed. Default is 64.

    :rtype: Iterable with elements of :class:`_DynamicStructReader`
    """

def _write_message_to_fd(fd: int, message: _MessageBuilder) -> None:
    """Serialize a Cap'n Proto message to a file descriptor

    You use this method to serialize your message to a file. Please note that
    you must pass a file descriptor (ie. an int), not a file object. Make sure
    you use the proper reader to match this (ie. don't use _PackedFdMessageReader)::

        message = capnp._MallocMessageBuilder()
        ...
        f = open('out.txt', 'w')
        _write_message_to_fd(f.fileno(), message)
        ...
        f = open('out.txt')
        _StreamFdMessageReader(f)

    :type fd: int
    :param fd: A file descriptor

    :type message: :class:`_MessageBuilder`
    :param message: The Cap'n Proto message to serialize

    :rtype: void
    """

def _write_packed_message_to_fd(fd: int, message: _MessageBuilder) -> None:
    """Serialize a Cap'n Proto message to a file descriptor in a packed manner

    You use this method to serialize your message to a file. Please note that
    you must pass a file descriptor (ie. an int), not a file object. Also, note
    the difference in names with _write_message_to_fd. This method uses a different
    serialization specification, and your reader will need to match.::

        message = capnp._MallocMessageBuilder()
        ...
        f = open('out.txt', 'w')
        _write_packed_message_to_fd(f.fileno(), message)
        ...
        f = open('out.txt')
        _PackedFdMessageReader(f)

    :type fd: int
    :param fd: A file descriptor

    :type message: :class:`_MessageBuilder`
    :param message: The Cap'n Proto message to serialize

    :rtype: void
    """

async def run(coro: Awaitable[Any]) -> Any:
    """Ensure that the coroutine runs while the KJ event loop is running

    This is a shortcut for wrapping the coroutine in a :py:meth:`capnp.kj_loop` context manager.

    :param coro: Coroutine to run
    """

def kj_loop() -> contextlib.AbstractAsyncContextManager[None]:
    """Context manager for running the KJ event loop

    As long as the context manager is active it is guaranteed that the KJ event
    loop is running. When the context manager is exited, the KJ event loop is
    shut down properly and pending tasks are cancelled.

    :raises [RuntimeError]: If the KJ event loop is already running (on this thread).

    .. warning:: Every capnp rpc call required a running KJ event loop.
    """

def _init_capnp_api() -> None:
    """Initialize static function pointers for cdef api functions."""
