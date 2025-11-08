from __future__ import annotations

# Import submodules
from capnp import lib as lib
from capnp import version as version
from capnp.lib.capnp import (
    # Public classes
    AsyncIoStream as AsyncIoStream,
)

# Re-export everything from lib.capnp that's part of the public API
from capnp.lib.capnp import (
    # Exception classes
    KjException as KjException,
)
from capnp.lib.capnp import (
    SchemaLoader as SchemaLoader,
)
from capnp.lib.capnp import (
    SchemaParser as SchemaParser,
)
from capnp.lib.capnp import (
    TwoPartyClient as TwoPartyClient,
)
from capnp.lib.capnp import (
    TwoPartyServer as TwoPartyServer,
)
from capnp.lib.capnp import (
    # Internal classes that are re-exported
    _CapabilityClient as _CapabilityClient,
)
from capnp.lib.capnp import (
    _DynamicCapabilityClient as _DynamicCapabilityClient,
)
from capnp.lib.capnp import (
    _DynamicListBuilder as _DynamicListBuilder,
)
from capnp.lib.capnp import (
    _DynamicListReader as _DynamicListReader,
)
from capnp.lib.capnp import (
    _DynamicOrphan as _DynamicOrphan,
)
from capnp.lib.capnp import (
    _DynamicResizableListBuilder as _DynamicResizableListBuilder,
)
from capnp.lib.capnp import (
    _DynamicStructBuilder as _DynamicStructBuilder,
)
from capnp.lib.capnp import (
    _DynamicStructReader as _DynamicStructReader,
)
from capnp.lib.capnp import (
    _EventLoop as _EventLoop,
)
from capnp.lib.capnp import (
    _init_capnp_api as _init_capnp_api,
)
from capnp.lib.capnp import (
    _InterfaceModule as _InterfaceModule,
)
from capnp.lib.capnp import (
    _ListSchema as _ListSchema,
)
from capnp.lib.capnp import (
    _MallocMessageBuilder as _MallocMessageBuilder,
)
from capnp.lib.capnp import (
    _PackedFdMessageReader as _PackedFdMessageReader,
)
from capnp.lib.capnp import (
    _PyCustomMessageBuilder as _PyCustomMessageBuilder,
)
from capnp.lib.capnp import (
    _StreamFdMessageReader as _StreamFdMessageReader,
)
from capnp.lib.capnp import (
    _StructModule as _StructModule,
)
from capnp.lib.capnp import (
    _write_message_to_fd as _write_message_to_fd,
)
from capnp.lib.capnp import (
    _write_packed_message_to_fd as _write_packed_message_to_fd,
)
from capnp.lib.capnp import (
    # Public functions
    add_import_hook as add_import_hook,
)
from capnp.lib.capnp import (
    cleanup_global_schema_parser as cleanup_global_schema_parser,
)
from capnp.lib.capnp import (
    deregister_all_types as deregister_all_types,
)
from capnp.lib.capnp import (
    fill_context as fill_context,
)
from capnp.lib.capnp import (
    kj_loop as kj_loop,
)
from capnp.lib.capnp import (
    load as load,
)
from capnp.lib.capnp import (
    read_multiple_bytes_packed as read_multiple_bytes_packed,
)
from capnp.lib.capnp import (
    register_type as register_type,
)
from capnp.lib.capnp import (
    remove_import_hook as remove_import_hook,
)
from capnp.lib.capnp import (
    run as run,
)

# Import the types module from lib.capnp where it's actually defined
from capnp.lib.capnp import types as types
from capnp.lib.capnp import (
    void_task_done_callback as void_task_done_callback,
)

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
