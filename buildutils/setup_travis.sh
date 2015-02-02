#!/bin/bash

set -exo pipefail

sudo add-apt-repository -y ppa:ubuntu-toolchain-r/test
sudo apt-get -qq update
sudo apt-get -qq install g++-4.8 libstdc++-4.8-dev
sudo update-alternatives --quiet --install /usr/bin/gcc  gcc  /usr/bin/gcc-4.8  60 --slave   /usr/bin/g++  g++  /usr/bin/g++-4.8 --slave   /usr/bin/gcov gcov /usr/bin/gcov-4.8
sudo update-alternatives --quiet --set gcc /usr/bin/gcc-4.8

if ! [ -z "${BUILD_CAPNP}" ]; then
  wget https://capnproto.org/capnproto-c++-0.5.1.tar.gz && tar xzvf capnproto-c++-0.5.1.tar.gz && cd capnproto-c++-0.5.1 && ./configure && make -j6 check && sudo make install && sudo ldconfig && cd ..
fi
