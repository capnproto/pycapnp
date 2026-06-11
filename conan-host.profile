{% set cibw_arch = os.environ.get("CIBW_ARCHS", "") %}
{% set arch_map = {"x86_64": "x86_64", "arm64": "armv8", "x86": "x86"} %}
{% set arch = arch_map.get(cibw_arch, "") %}
{% if arch %}
[settings]
arch={{ arch }}
{% endif %}
