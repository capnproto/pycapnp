import sys
import sysconfig

from conan import ConanFile
from conan.tools.cmake import CMake, CMakeDeps, CMakeToolchain, cmake_layout


class PycapnpConan(ConanFile):
    name = "pycapnp"
    settings = "os", "compiler", "build_type", "arch"

    def requirements(self):
        self.requires("capnproto/1.3.0")

    def layout(self):
        cmake_layout(self)

    def generate(self):
        tc = CMakeToolchain(self)
        tc.cache_variables["Python3_EXECUTABLE"] = sys.executable
        tc.cache_variables["Python3_INCLUDE_DIR"] = sysconfig.get_path("include")
        tc.cache_variables["Python3_SOABI"] = sysconfig.get_config_var("SOABI")
        tc.generate()
        CMakeDeps(self).generate()

    def build(self):
        cmake = CMake(self)
        cmake.configure()
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()
