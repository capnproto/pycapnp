import os
import sys

from jinja2 import Environment, PackageLoader

import capnp
import schema_capnp


def find_type(code, id):
    for node in code["nodes"]:
        if node["id"] == id:
            return node

    return None


def main():
    env = Environment(loader=PackageLoader("capnp", "templates"))
    env.filters["format_name"] = lambda name: name[name.find(":") + 1 :]

    code = schema_capnp.CodeGeneratorRequest.read(sys.stdin)
    code = code.to_dict()
    code["nodes"] = [
        node for node in code["nodes"] if "struct" in node and node["scopeId"] != 0
    ]
    for node in code["nodes"]:
        displayName = node["displayName"]
        parent, path = displayName.split(":")
        node["module_path"] = (
            parent.replace(".", "_")
            + "."
            + ".".join([x[0].upper() + x[1:] for x in path.split(".")])
        )
        node["module_name"] = path.replace(".", "_")
        node["c_module_path"] = "::".join(
            [x[0].upper() + x[1:] for x in path.split(".")]
        )
        node["schema"] = "_{}_Schema".format(node["module_name"])
        is_union = False
        for field in node["struct"]["fields"]:
            if field["discriminantValue"] != 65535:
                is_union = True
            field["c_name"] = field["name"][0].upper() + field["name"][1:]
            if "slot" in field:
                field["type"] = list(field["slot"]["type"].keys())[0]
                if not isinstance(field["slot"]["type"][field["type"]], dict):
                    continue
                sub_type = field["slot"]["type"][field["type"]].get("typeId", None)
                if sub_type:
                    field["sub_type"] = find_type(code, sub_type)
                sub_type = field["slot"]["type"][field["type"]].get("elementType", None)
                if sub_type:
                    field["sub_type"] = sub_type
            else:
                field["type"] = find_type(code, field["group"]["typeId"])
        node["is_union"] = is_union

    include_dir = os.path.abspath(os.path.join(os.path.dirname(capnp.__file__), ".."))
    module = env.get_template("module.pyx")

    for f in code["requestedFiles"]:
        filename = f["filename"].replace(".", "_") + "_cython.pyx"

        file_code = dict(code)
        file_code["nodes"] = [
            node
            for node in file_code["nodes"]
            if node["displayName"].startswith(f["filename"])
        ]
        with open(filename, "w") as out:
            out.write(module.render(code=file_code, file=f, include_dir=include_dir))

    setup = env.get_template("setup.py.tmpl")
    with open("setup_capnp.py", "w") as out:
        out.write(setup.render(code=code))
    print(
        "You now need to build the cython module by running `python setup_capnp.py build_ext --inplace`."
    )
    print()
