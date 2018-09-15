#!/bin/bash

set -exo pipefail

CAPNP_VERSION=0.5.2

sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get -qq update
sudo apt-get -qq install g++-5 libstdc++-5-dev
sudo update-alternatives --quiet --install /usr/bin/gcc  gcc  /usr/bin/gcc-5  60 --slave   /usr/bin/g++  g++  /usr/bin/g++-5 --slave   /usr/bin/gcov gcov /usr/bin/gcov-5
sudo update-alternatives --quiet --set gcc /usr/bin/gcc-5

if ! [ -z "${BUILD_CAPNP}" ]; then
  wget https://capnproto.org/capnproto-c++-${CAPNP_VERSION}.tar.gz && tar xzvf capnproto-c++-${CAPNP_VERSION}.tar.gz && cd capnproto-c++-${CAPNP_VERSION} && ./configure && make -j6 && sudo make install && sudo ldconfig && cd ..
fi
