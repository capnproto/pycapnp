from __future__ import annotations

# Re-export everything from lib.capnp that's part of the public API
from capnp.lib.capnp import (
    # Exception classes
    KjException as KjException,
    # Public classes
    AsyncIoStream as AsyncIoStream,
    SchemaLoader as SchemaLoader,
    SchemaParser as SchemaParser,
    TwoPartyClient as TwoPartyClient,
    TwoPartyServer as TwoPartyServer,
    # Public functions
    add_import_hook as add_import_hook,
    cleanup_global_schema_parser as cleanup_global_schema_parser,
    deregister_all_types as deregister_all_types,
    fill_context as fill_context,
    kj_loop as kj_loop,
    load as load,
    read_multiple_bytes_packed as read_multiple_bytes_packed,
    register_type as register_type,
    remove_import_hook as remove_import_hook,
    run as run,
    void_task_done_callback as void_task_done_callback,
    # Internal classes that are re-exported
    _CapabilityClient as _CapabilityClient,
    _DynamicCapabilityClient as _DynamicCapabilityClient,
    _DynamicListBuilder as _DynamicListBuilder,
    _DynamicListReader as _DynamicListReader,
    _DynamicOrphan as _DynamicOrphan,
    _DynamicResizableListBuilder as _DynamicResizableListBuilder,
    _DynamicStructBuilder as _DynamicStructBuilder,
    _DynamicStructReader as _DynamicStructReader,
    _EventLoop as _EventLoop,
    _InterfaceModule as _InterfaceModule,
    _ListSchema as _ListSchema,
    _MallocMessageBuilder as _MallocMessageBuilder,
    _PackedFdMessageReader as _PackedFdMessageReader,
    _PyCustomMessageBuilder as _PyCustomMessageBuilder,
    _StreamFdMessageReader as _StreamFdMessageReader,
    _StructModule as _StructModule,
    _init_capnp_api as _init_capnp_api,
    _write_message_to_fd as _write_message_to_fd,
    _write_packed_message_to_fd as _write_packed_message_to_fd,
)

# Import the types module from lib.capnp where it's actually defined
from capnp.lib.capnp import types as types

# Import submodules
from capnp import lib as lib
from capnp import version as version

# Version string
from capnp.version import version as __version__


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
    "lib",
    "types",
    "version",
    # Version string
    "__version__",
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
    "_init_capnp_api",
    "_write_message_to_fd",
    "_write_packed_message_to_fd",
]
