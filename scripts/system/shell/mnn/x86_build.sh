#!/usr/bin/env bash

dir=$(pwd)
kernel_name=$(uname -s)
machine=$(uname -m)

build=build_${kernel_name}_${machine}
install=${build}/install

rm -rf ${build}
mkdir -p ${install}
pushd ${build}

cmake -DCMAKE_INSTALL_PREFIX=${dir}/${install} ../MNN
make -j4
make install
popd
