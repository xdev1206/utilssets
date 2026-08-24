#!/usr/bin/env bash

export ANDROID_NDK=/data1/xuxin/android/android-ndk-r21d

COMMON_DEFINITION="-DCMAKE_INSTALL_PREFIX=."
ANDROID_COMMON_DEFINITION="-DCMAKE_TOOLCHAIN_FILE=$ANDROID_NDK/build/cmake/android.toolchain.cmake"
ANDROID_ARM_V7A_DEFINITION="-DANDROID_ABI=armeabi-v7a"
ANDROID_ARM_V8A_DEFINITION="-DANDROID_ABI=arm64-v8a -DMNN_ARM82=ON"

##### android armv7
build=build-android-armv7
rm -rf ${build}
mkdir -p ${build}
pushd ${build}
cmake ${COMMON_DEFINITION} ${ANDROID_COMMON_DEFINITION} ${ANDROID_ARM_V7A_DEFINITION} ../MNN
make -j12
make install
popd

##### android aarch64
build=build-android-aarch64
rm -rf ${build}
mkdir -p ${build}
pushd ${build}
cmake ${COMMON_DEFINITION} ${ANDROID_COMMON_DEFINITION} ${ANDROID_ARM_V8A_DEFINITION} ../MNN 2>&1 | tee cmake.log
make -j12 2>&1 | tee make.log
make install 2>&1 | tee make_install.log
popd

build=build-linux-x86
rm ${build} -rf
mkdir -p ${build}
pushd ${build}
cmake ${COMMON_DEFINITION} ../MNN
make -j12
make install
popd
