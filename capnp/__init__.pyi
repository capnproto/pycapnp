from __future__ import annotations

# Import submodules
from capnp import lib, version

# Import the types module from lib.capnp where it's actually defined
from capnp.lib.capnp import (
    # Public classes
    AsyncIoStream,
    # Exception classes
    KjException,
    SchemaLoader,
    SchemaParser,
    TwoPartyClient,
    TwoPartyServer,
    # Internal classes and functions that are re-exported
    _CapabilityClient,
    _DynamicCapabilityClient,
    _DynamicListBuilder,
    _DynamicListReader,
    _DynamicOrphan,
    _DynamicResizableListBuilder,
    _DynamicStructBuilder,
    _DynamicStructReader,
    _EventLoop,
    _init_capnp_api,
    _InterfaceModule,
    _ListSchema,
    _MallocMessageBuilder,
    _PackedFdMessageReader,
    _PyCustomMessageBuilder,
    _StreamFdMessageReader,
    _StructModule,
    _write_message_to_fd,
    _write_packed_message_to_fd,
    # Public functions
    add_import_hook,
    cleanup_global_schema_parser,
    deregister_all_types,
    fill_context,
    kj_loop,
    load,
    read_multiple_bytes_packed,
    register_type,
    remove_import_hook,
    run,
    types,
    void_task_done_callback,
)

# Re-export everything from lib.capnp that's part of the public API
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
