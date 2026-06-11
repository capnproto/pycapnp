from conan import ConanFile
from conan.tools.cmake import CMake, cmake_layout


class PycapnpConan(ConanFile):
    name = "pycapnp"
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeToolchain", "CMakeDeps"

    def requirements(self):
        self.requires("capnproto/1.3.0")

    def layout(self):
        cmake_layout(self)

    def build(self):
        import sys
        cmake = CMake(self)
        cmake.configure(variables={"Python3_EXECUTABLE": sys.executable})
        cmake.build()

    def package(self):
        cmake = CMake(self)
        cmake.install()
