{% set cibw_arch = os.environ.get("CIBW_ARCHS", "") %}
{% set arch_map = {"x86_64": "x86_64", "arm64": "armv8", "x86": "x86"} %}
{% set conan_arch = arch_map.get(cibw_arch, "") %}
{% if conan_arch %}
[settings]
arch={{ conan_arch }}
{% endif %}
{% set is_macos = os.path.isdir('/System') %}
{% set wheel_mac_arch = {"x86_64": "x86_64", "arm64": "arm64"}.get(cibw_arch, "") %}
{% if is_macos and wheel_mac_arch %}
{% set dt = os.environ.get("MACOSX_DEPLOYMENT_TARGET", "").replace(".", "_") or ("10_9" if cibw_arch == "x86_64" else "11_0") %}
[buildenv]
WHEEL_ARCH=macosx_{{ dt }}_{{ wheel_mac_arch }}
{% endif %}
