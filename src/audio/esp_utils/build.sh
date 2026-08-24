#!/usr/bin/env bash

mkdir -p build
pushd build

cmake -DBUILD_SHARED_LIBS=ON ..

make
popd

PROJ=$(cd `dirname $0` && pwd)

export LD_LIBRARY_PATH=${PROJ}/build/lib

${PROJ}/build/bin/feat_test
