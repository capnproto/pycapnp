"""Runtime-shape regression tests for the bundled pycapnp stubs."""

from __future__ import annotations

import ast
import enum
import inspect
from pathlib import Path

import capnp

REPO_ROOT = Path(__file__).resolve().parents[2]
CAPNP_STUB = REPO_ROOT / "capnp" / "lib" / "capnp.pyi"
ROOT_STUB = REPO_ROOT / "capnp" / "__init__.pyi"
TYPES_STUB = REPO_ROOT / "capnp" / "types.pyi"

# Cython implementation types that are importable but are not part of the
# Python API exposed by the stubs. Keep this list exact so additions and removals
# in the runtime surface require an explicit decision.
INTENTIONALLY_UNSTUBBED_RUNTIME_CLASSES = {
    "DummyBaseClass",
    "_AsyncMessageReader",
    "_Importer",
    "_InputMessageReader",
    "_KjExceptionWrapper",
    "_Loader",
    "_MultipleBytesMessageReader",
    "_MultipleBytesPackedAnyMessageReader",
    "_MultipleBytesPackedMessageReader",
    "_MultipleMessageReader",
    "_MultiplePackedMessageReader",
    "_PackedMessageReader",
    "_PackedMessageReaderBytes",
    "_PyAsyncIoStreamProtocol",
    "_StringArrayPtr",
    "_StructABCMeta",
    "_TwoPartyVatNetwork",
    "_VoidPromiseFulfiller",
}

INTENTIONALLY_UNSTUBBED_RUNTIME_CALLABLES = {
    "__pyx_unpickle_DummyBaseClass",
    "__pyx_unpickle__BorrowedBufferView",
    "__pyx_unpickle__DynamicCapabilityServer",
    "__pyx_unpickle__DynamicEnumField",
    "__pyx_unpickle__DynamicResizableListBuilder",
    "__pyx_unpickle__MessageSize",
    "__pyx_unpickle__MultipleBytesMessageReader",
    "__pyx_unpickle__SegmentViews",
    "__reduce_cython__",
    "__setstate_cython__",
    "_make_enum",
    "_message_to_packed_bytes",
    "_struct_reducer",
}


def _runtime_source_doc(runtime_object: object, *, is_class: bool) -> str | None:
    """Remove Cython's embedded signature from an authored source docstring."""
    raw_doc = getattr(runtime_object, "__doc__", None)
    if not raw_doc:
        return None

    # Python 3.10 and earlier synthesize this docstring for undocumented Enum
    # subclasses. It is not a docstring authored in capnp.pyx.
    if (
        is_class
        and isinstance(runtime_object, type)
        and issubclass(runtime_object, enum.Enum)
        and raw_doc == "An enumeration."
    ):
        return None

    doc = inspect.cleandoc(raw_doc)
    first_paragraph, separator, remainder = doc.partition("\n\n")
    callable_name, opening_parenthesis, _ = first_paragraph.partition("(")
    starts_with_signature = bool(
        opening_parenthesis
        and callable_name
        and all(name_part.isidentifier() for name_part in callable_name.split("."))
    )

    if starts_with_signature:
        if not separator:
            return None
        doc = inspect.cleandoc(remainder)
    if not is_class and not separator:
        return None
    return "\n".join(line.rstrip() for line in doc.splitlines()) or None


def _stub_declarations(
    body: list[ast.stmt],
    prefix: tuple[str, ...] = (),
) -> list[tuple[tuple[str, ...], ast.ClassDef | ast.FunctionDef | ast.AsyncFunctionDef]]:
    declarations: list[tuple[tuple[str, ...], ast.ClassDef | ast.FunctionDef | ast.AsyncFunctionDef]] = []
    for declaration in body:
        if isinstance(declaration, ast.ClassDef):
            qualified_name = (*prefix, declaration.name)
            declarations.append((qualified_name, declaration))
            declarations.extend(_stub_declarations(declaration.body, qualified_name))
        elif isinstance(declaration, (ast.FunctionDef, ast.AsyncFunctionDef)):
            declarations.append(((*prefix, declaration.name), declaration))
    return declarations


def test_stub_classes_match_runtime_names_and_inheritance() -> None:
    """Do not add or lose API classes, or invent inheritance."""
    tree = ast.parse(CAPNP_STUB.read_text(encoding="utf8"))
    runtime_module = capnp.lib.capnp

    stub_classes = {declaration.name for declaration in tree.body if isinstance(declaration, ast.ClassDef)}
    runtime_classes = {
        name
        for name, value in vars(runtime_module).items()
        if isinstance(value, type) and getattr(value, "__module__", None) == runtime_module.__name__
    }
    assert stub_classes.isdisjoint(INTENTIONALLY_UNSTUBBED_RUNTIME_CLASSES)
    assert runtime_classes == stub_classes | INTENTIONALLY_UNSTUBBED_RUNTIME_CLASSES

    for declaration in tree.body:
        if not isinstance(declaration, ast.ClassDef):
            continue

        assert hasattr(runtime_module, declaration.name), f"stub-only class: {declaration.name}"
        runtime_class = getattr(runtime_module, declaration.name)
        stub_bases = [ast.unparse(base).split(".")[-1] for base in declaration.bases]
        runtime_bases = [base.__name__ for base in runtime_class.__bases__ if base is not object]
        assert stub_bases == runtime_bases, f"incorrect bases for {declaration.name}"


def test_stub_functions_match_runtime_names() -> None:
    """Do not add or lose module-level API callables."""
    tree = ast.parse(CAPNP_STUB.read_text(encoding="utf8"))
    runtime_module = capnp.lib.capnp

    stub_functions = {
        declaration.name
        for declaration in tree.body
        if isinstance(declaration, (ast.FunctionDef, ast.AsyncFunctionDef))
    }
    runtime_functions = {
        name
        for name, value in vars(runtime_module).items()
        if callable(value)
        and not isinstance(value, type)
        and getattr(value, "__module__", None) == runtime_module.__name__
    }
    assert stub_functions.isdisjoint(INTENTIONALLY_UNSTUBBED_RUNTIME_CALLABLES)
    assert runtime_functions == stub_functions | INTENTIONALLY_UNSTUBBED_RUNTIME_CALLABLES


def test_stub_docstrings_match_runtime_source_docs() -> None:
    """Keep editor help aligned with the docstrings authored in capnp.pyx."""
    tree = ast.parse(CAPNP_STUB.read_text(encoding="utf8"))
    runtime_module = capnp.lib.capnp

    for qualified_name, declaration in _stub_declarations(tree.body):
        runtime_object: object = runtime_module
        try:
            for name_part in qualified_name:
                runtime_object = getattr(runtime_object, name_part)
        except AttributeError:
            continue

        expected = _runtime_source_doc(runtime_object, is_class=isinstance(declaration, ast.ClassDef))
        actual = ast.get_docstring(declaration, clean=True)
        assert actual == expected, f"docstring mismatch for {'.'.join(qualified_name)}"


def test_corrected_stub_surface_matches_runtime() -> None:
    """Cover public aliases and runtime details that are easy to model incorrectly."""
    root_content = ROOT_STUB.read_text(encoding="utf8")
    content = CAPNP_STUB.read_text(encoding="utf8")

    assert capnp.AsyncIoStream is capnp.lib.capnp._AsyncIoStream
    assert not hasattr(capnp, "_AsyncIoStream")
    assert "from capnp.lib.capnp import _AsyncIoStream\n" in root_content
    assert "AsyncIoStream = _AsyncIoStream" in root_content
    assert "_AsyncIoStream as _AsyncIoStream" not in root_content
    assert "__version__: str" in root_content
    assert "version as _version" not in root_content

    assert "reverse_mapping: dict[str, str]" in content
    assert "class _StructModuleWhich(enum.Enum):" in content
    assert capnp.lib.capnp._StructModuleWhich.__hash__ is None
    assert ") -> _DynamicStructReader | None:" in content
    assert "def to_segment_views(self) -> Sequence[Any]:" in content


def test_types_stub_matches_runtime_schema_singletons() -> None:
    """Expose the real dynamic ``capnp.types`` module without a synthetic wrapper class."""
    tree = ast.parse(TYPES_STUB.read_text(encoding="utf8"))
    declared = {
        statement.target.id
        for statement in tree.body
        if isinstance(statement, ast.AnnAssign) and isinstance(statement.target, ast.Name)
    }
    runtime_names = {name for name in vars(capnp.types) if not name.startswith("_")}

    assert declared == runtime_names
    assert all(type(getattr(capnp.types, name)) is capnp.lib.capnp._SchemaType for name in declared)
