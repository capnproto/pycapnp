from importlib.metadata import version as _pkg_version

from .lib.capnp import _CAPNP_VERSION_MAJOR as LIBCAPNP_VERSION_MAJOR  # noqa: F401
from .lib.capnp import _CAPNP_VERSION_MINOR as LIBCAPNP_VERSION_MINOR  # noqa: F401
from .lib.capnp import _CAPNP_VERSION_MICRO as LIBCAPNP_VERSION_MICRO  # noqa: F401
from .lib.capnp import _CAPNP_VERSION as LIBCAPNP_VERSION  # noqa: F401

version = _pkg_version("pycapnp")
short_version = version
