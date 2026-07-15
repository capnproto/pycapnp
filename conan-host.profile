{% set cibw_arch = os.environ.get("CIBW_ARCHS", "") %}
{% set conan_arch = {"x86_64": "x86_64", "arm64": "armv8", "x86": "x86"}.get(cibw_arch, "") %}
{% set dt = os.environ.get("MACOSX_DEPLOYMENT_TARGET", "").replace(".", "_") %}
include(default)
{% if conan_arch %}

[settings]
arch={{ conan_arch }}
{% endif %}
{% if platform.system() == 'Darwin' and cibw_arch in ("x86_64", "arm64") and dt %}

[buildenv]
WHEEL_ARCH=macosx_{{ dt }}_{{ cibw_arch }}
{% endif %}
