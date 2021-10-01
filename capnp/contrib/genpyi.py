"""
Generates type hints for capnp schemas.

Note: it requires pycapnp from git, or at least post 1.0.0.

Note: capnp interfaces (rpc) are not yet supported

Example usage:

    $ cd examples/
    $ python -m capnp.contrib.genpyi addressbook_capnp
    Wrote /foo/bar/pycapnp/examples/addressbook_capnp.pyi

"""

from __future__ import annotations
from typing import Any, Set
import argparse
import sys
import os.path
import importlib
import logging
import keyword
import dataclasses

try:
    import black
except ImportError:
    black = None  # type: ignore

try:
    from ycecream import y  # noqa
except ImportError:

    def y(*args, **kwargs):
        print(*args, **kwargs, file=sys.stderr)


logger = logging.getLogger()


CAPNP_TYPE_TO_PYTHON = {
    "void": "None",
    "bool": "bool",
    "int8": "int",
    "int16": "int",
    "int32": "int",
    "int64": "int",
    "uint8": "int",
    "uint16": "int",
    "uint32": "int",
    "uint64": "int",
    "float32": "float",
    "float64": "float",
    "text": "str",
    "data": "bytes",
}


@dataclasses.dataclass
class Scope:
    name: str
    id: int
    parent: Scope | None
    return_scope: Scope | None
    lines: list[str] = dataclasses.field(default_factory=list)


@dataclasses.dataclass
class Type:
    schema: Any
    name: str
    scope: Scope
    generic_params: list[str] = dataclasses.field(default_factory=list)

    @property
    def scope_path(self) -> list[Scope]:
        scopes: list[Scope] = []
        scope: Scope | None = self.scope
        while scope is not None and scope.name:
            scopes.insert(0, scope)
            scope = scope.parent
        return scopes


class NoParentError(Exception):
    pass


class Writer:
    def __init__(self, module):
        self.scope = Scope(
            name="", id=module.schema.node.id, parent=None, return_scope=None
        )
        self.scopes_by_id: dict[int, Scope] = {self.scope.id: self.scope}
        self.module = module
        self.indent_level = 0
        self.imports: Set[str] = set()
        self.typing_imports: Set[str] = set()
        self.type_vars: set[str] = set()
        self.type_map: dict[int, Type] = {}

    def check_import(self, schema):
        module_name, def_name = schema.node.displayName.split(":")
        if module_name == self.module.schema.node.displayName:
            return None
        module = "." + module_name.replace(".", "_")
        self.imports.add(f"from {module} import {def_name.split('.')[0]}")

        scope = self.scope
        while scope.parent is not None:
            scope = scope.parent

        return self.register_type(
            schema.node.id, schema, name=def_name, scope=scope
        )

    def register_type_var(self, name: str) -> str:
        names = [name]
        scope = self.scope
        while scope is not None:
            names.append(scope.name)
            scope = scope.parent
        full_name = "_".join(reversed(names))
        self.type_vars.add(full_name)
        return full_name

    def register_type(
        self, type_id, schema, name: str = "", scope: Scope | None = None
    ) -> Type:
        if not name:
            name = schema.node.displayName[
                schema.node.displayNamePrefixLength :
            ]
        if scope is None:
            scope = self.scope.parent
        self.type_map[type_id] = retval = Type(
            schema=schema, name=name, scope=scope
        )
        return retval

    def lookup_type(self, type_id: int) -> Type:
        scope = self.scope
        while scope is not None:
            try:
                return self.type_map[type_id]
            except KeyError:
                pass
            scope = scope.parent
        raise KeyError(type_id)

    def writeln(self, line: str = ""):
        out = " " * self.indent_level + line
        self.scope.lines.append(out)

    def _update_indent_level(self) -> None:
        scope = self.scope
        indent = -4
        while scope is not None:
            indent += 4
            scope = scope.parent
        self.indent_level = indent

    def begin_scope(self, name: str, node, scope_decl: str) -> None:
        try:
            parent_scope = self.scopes_by_id[node.scopeId]
        except KeyError:
            raise NoParentError
        scope = Scope(
            name=name, id=node.id, parent=parent_scope, return_scope=self.scope
        )
        self.scope = parent_scope
        self._update_indent_level()
        scope.lines.append(" " * self.indent_level + scope_decl)
        self.scope = scope
        self.scopes_by_id[node.id] = scope
        self._update_indent_level()

    def end_scope(self):
        scope = self.scope
        assert scope.parent is not None
        scope.parent.lines += scope.lines
        self.scope = self.scope.return_scope
        del self.scopes_by_id[scope.id]
        self._update_indent_level()

    def type_ref(self, type_node) -> str:
        try:
            return CAPNP_TYPE_TO_PYTHON[type_node.which()]
        except KeyError:
            pass
        if type_node.which() == "struct":
            elem_type = self.lookup_type(type_node.struct.typeId)
            type_name = elem_type.name
            generics_params = []
            for brand_scope in type_node.struct.brand.scopes:
                if brand_scope.which() == "inherit":
                    parent_scope = self.lookup_type(brand_scope.scopeId)
                    generics_params.extend(parent_scope.generic_params)
                elif brand_scope.which() == "bind":
                    for bind in brand_scope.bind:
                        generics_params.append(self.type_ref(bind.type))
                else:
                    raise AssertionError
            if generics_params:
                type_name += f"[{', '.join(generics_params)}]"
        elif type_node.which() == "enum":
            elem_type = self.lookup_type(type_node.enum.typeId)
            type_name = elem_type.name
        else:
            raise AssertionError(type_node.which())

        scope_path = elem_type.scope_path
        if len(scope_path) > 0:
            return ".".join([scope.name for scope in scope_path] + [type_name])
        return type_name

    def dumps(self) -> str:
        assert self.scope.name == ""
        out = ["from __future__ import annotations"]
        for imp in sorted(self.imports):
            out.append(imp)
        out.append("")
        if self.typing_imports:
            out.append(
                "from typing import "
                + ", ".join(imp for imp in sorted(self.typing_imports))
            )
            out.append("")

        out.append("")
        if self.type_vars:
            for name in sorted(self.type_vars):
                out.append(f'{name} = TypeVar("{name}")')
            out.append("")

        out.extend(self.scope.lines)
        return "\n".join(out)


def gen_const(schema, writer):
    name = schema.node.displayName[schema.node.displayNamePrefixLength :]
    python_type = CAPNP_TYPE_TO_PYTHON[schema.node.const.type.which()]
    writer.writeln(f"{name}: {python_type}")


def gen_enum(schema, writer):
    imported = writer.check_import(schema)
    if imported is not None:
        return imported

    name = schema.node.displayName[schema.node.displayNamePrefixLength :]
    writer.imports.add("from enum import Enum")
    writer.begin_scope(name, schema.node, f"class {name}(str, Enum):")
    writer.register_type(schema.node.id, schema, name)
    for enumerant in schema.node.enum.enumerants:
        value = enumerant.name
        name = enumerant.name
        if name in keyword.kwlist:
            name = name + "_"
        writer.writeln(f'{name}: str = "{value}"')
    writer.end_scope()


def gen_struct(schema, writer, name: str = ""):
    imported = writer.check_import(schema)
    if imported is not None:
        return imported
    # y(schema.node.displayName, schema.node.id, schema.node.scopeId)

    if not name:
        name = schema.node.displayName[schema.node.displayNamePrefixLength :]
    if schema.node.isGeneric:
        writer.typing_imports.add("TypeVar")
        writer.typing_imports.add("Generic")
        generic_params = [param.name for param in schema.node.parameters]
        referenced_params = []
        for field, raw_field in zip(
            schema.node.struct.fields, schema.as_struct().fields_list
        ):
            if (
                field.slot.type.which() == "anyPointer"
                and field.slot.type.anyPointer.which() == "parameter"
            ):
                param = field.slot.type.anyPointer.parameter
                param_source = writer.lookup_type(param.scopeId).schema
                source_params = [
                    param.name for param in param_source.node.parameters
                ]
                referenced_params.append(source_params[param.parameterIndex])
    else:
        generic_params = []
        referenced_params = []
    registered_params = []
    if generic_params or referenced_params:
        for param in generic_params + referenced_params:
            registered_params.append(writer.register_type_var(param))
        scope_decl_line = (
            f"class {name}(Generic[{', '.join(registered_params)}]):"
        )
    else:
        scope_decl_line = f"class {name}:"
    writer.begin_scope(name, schema.node, scope_decl_line)
    registered = writer.register_type(schema.node.id, schema, name=name)
    registered.generic_params = registered_params
    name = registered.name
    have_body = False

    init_choices = []
    contructor_kwargs = []

    for field, raw_field in zip(
        schema.node.struct.fields, schema.as_struct().fields_list
    ):
        if field.which() == "slot":
            if field.slot.type.which() == "list":
                if field.slot.type.list.elementType.which() == "struct":
                    try:
                        writer.lookup_type(
                            field.slot.type.list.elementType.struct.typeId
                        )
                    except KeyError:
                        gen_nested(raw_field.schema.elementType, writer)
                elif field.slot.type.list.elementType.which() == "enum":
                    try:
                        writer.lookup_type(
                            field.slot.type.list.elementType.enum.typeId
                        )
                    except KeyError:
                        gen_nested(raw_field.schema.elementType, writer)
                type_name = writer.type_ref(field.slot.type.list.elementType)
                field_py_code = f"{field.name}: List[{type_name}]"
                writer.writeln(field_py_code)
                contructor_kwargs.append(field_py_code)
                have_body = True
                writer.typing_imports.add("List")
            elif field.slot.type.which() in CAPNP_TYPE_TO_PYTHON:
                type_name = CAPNP_TYPE_TO_PYTHON[field.slot.type.which()]
                field_py_code = f"{field.name}: {type_name}"
                writer.writeln(field_py_code)
                contructor_kwargs.append(field_py_code)
                have_body = True
            elif field.slot.type.which() == "enum":
                try:
                    writer.lookup_type(field.slot.type.enum.typeId)
                except KeyError:
                    try:
                        gen_nested(raw_field.schema, writer)
                    except NoParentError:
                        pass
                type_name = writer.type_ref(field.slot.type)
                field_py_code = f"{field.name}: {type_name}"
                writer.writeln(field_py_code)
                contructor_kwargs.append(field_py_code)
                have_body = True
            elif field.slot.type.which() == "struct":
                elem_type = raw_field.schema
                try:
                    writer.lookup_type(elem_type.node.id)
                except KeyError:
                    gen_struct(elem_type, writer)
                type_name = writer.type_ref(field.slot.type)
                field_py_code = f"{field.name}: {type_name}"
                writer.writeln(field_py_code)
                contructor_kwargs.append(field_py_code)
                have_body = True
                init_choices.append((field.name, type_name))

            elif field.slot.type.which() == "anyPointer":
                param = field.slot.type.anyPointer.parameter
                type_name = registered.generic_params[param.parameterIndex]
                field_py_code = f"{field.name}: {type_name}"
                writer.writeln(field_py_code)
                contructor_kwargs.append(field_py_code)
                have_body = True
            else:
                raise AssertionError(
                    f"{schema.node.displayName}: {field.name}: "
                    f"{field.slot.type.which()}"
                )
        elif field.which() == "group":
            group_name = field.name[0].upper() + field.name[1:]
            assert group_name != field.name
            raw_schema = raw_field.schema
            group_name = gen_struct(raw_schema, writer, name=group_name).name
            field_py_code = f"{field.name}: {group_name}"
            writer.writeln(field_py_code)
            contructor_kwargs.append(field_py_code)
            have_body = True
            init_choices.append((field.name, group_name))
        else:
            raise AssertionError(
                f"{schema.node.displayName}: {field.name}: " f"{field.which()}"
            )
    scope_path = registered.scope_path
    if len(scope_path) > 0:
        scoped_name = ".".join([scope.name for scope in scope_path] + [name])
    else:
        scoped_name = name
    writer.writeln("@staticmethod")
    writer.writeln(f"def from_bytes(data: bytes) -> {scoped_name}: ...")
    writer.writeln("def to_bytes(self) -> bytes: ...")
    have_body = True

    if schema.node.struct.discriminantCount:
        literals = ", ".join(
            f'Literal["{field.name}"]'
            for field in schema.node.struct.fields
            if field.discriminantValue != 65535
        )
        writer.typing_imports.add("Literal")
        writer.typing_imports.add("Union")
        writer.writeln(f"def which(self) -> Union[{literals}]: ...")
        have_body = True

    if contructor_kwargs:
        kwargs = ", ".join(f"{kwarg} = ..." for kwarg in contructor_kwargs)
        writer.writeln(f"def __init__(self, *, {kwargs}) -> None: ...")
        have_body = True

    if len(init_choices) > 1:
        writer.typing_imports.add("overload")
        writer.writeln()
        for field_name, field_type in init_choices:
            writer.writeln("@overload")
            writer.writeln(
                f'def init(self, name: Literal["{field_name}"])'
                f" -> {field_type}: ..."
            )
    elif len(init_choices) == 1:
        field_name, field_type = init_choices[0]
        writer.writeln(
            f'def init(self, name: Literal["{field_name}"])'
            f" -> {field_type}: ..."
        )

    if not have_body:
        writer.writeln("pass")
    writer.end_scope()
    return registered


def gen_nested(schema, writer):
    if schema.node.id in writer.type_map:
        return  # already generated type hints for this type
    which = schema.node.which()
    if which == "const":
        gen_const(schema, writer)
    elif which == "struct":
        gen_struct(schema, writer)
    elif which == "enum":
        gen_enum(schema, writer)
    elif which == "interface":
        logger.warning("Skipping interface: not implemented")
    else:
        raise AssertionError(schema.node.which())


def gen_pyi(module, writer):
    for node in module.schema.node.nestedNodes:
        gen_nested(module.schema.get_nested(node.name), writer)


def main():
    logging.basicConfig(level=logging.INFO)
    parser = argparse.ArgumentParser(
        description="Generate type hints for a capnp module."
    )
    parser.add_argument(
        "modules",
        metavar="MODULE",
        type=str,
        nargs="+",
        help="a capnp schema python module name",
    )
    parser.add_argument(
        "-o",
        "--output-dir",
        dest="output_dir",
        default=None,
        help="override directory where to write the .pyi file",
    )
    args = parser.parse_args()
    for name in args.modules:
        module = importlib.import_module(name)
        writer = Writer(module)
        gen_pyi(module, writer)
        assert writer.indent_level == 0
        if args.output_dir is not None:
            outdir = args.output_dir
        else:
            outdir = os.path.dirname(module.__file__)
        file_path = os.path.join(outdir, module.__name__ + ".pyi")
        contents = writer.dumps()
        if black is not None:
            contents = black.format_str(
                contents, mode=black.Mode(is_pyi=True, line_length=79)
            )
        with open(file_path, "w") as outfile:
            outfile.write(contents)
        print(f"Wrote {file_path}", file=sys.stderr)


if __name__ == "__main__":
    main()
