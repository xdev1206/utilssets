#!/bin/bash

# bazel
uid=`id -u`
if [ $uid -ne 0 ]; then
  SUDO=sudo
fi

${SUDO} apt install curl gnupg g++ unzip zip

curl -fsSL https://bazel.build/bazel-release.pub.gpg | gpg --dearmor > bazel.gpg
${SUDO} mv bazel.gpg /etc/apt/trusted.gpg.d/
echo "deb [arch=amd64] https://storage.googleapis.com/bazel-apt stable jdk1.8" | ${SUDO} tee /etc/apt/sources.list.d/bazel.list

${SUDO} apt update
${SUDO} apt install bazel-3.1.0

./configure

# build aar
bazel build -c opt --fat_apk_cpu=arm64-v8a,armeabi-v7a \
    --host_crosstool_top=@bazel_tools//tools/cpp:toolchain \
    //tensorflow/lite/java:tensorflow-lite

# build so for android
bazel build -c opt --crosstool_top=//external:android/crosstool              \
  --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --cxxopt="-std=c++14" \
  --fat_apk_cpu=armeabi-v7a --config=android_arm                               \
  //tensorflow/lite:libtensorflowlite.so

bazel build -c opt --crosstool_top=//external:android/crosstool              \
  --host_crosstool_top=@bazel_tools//tools/cpp:toolchain --cxxopt="-std=c++14" \
  --fat_apk_cpu=arm64-v8a --config=android_arm64                               \
  //tensorflow/lite:libtensorflowlite.so

bazel build -c dbg --crosstool_top=//external:android/crosstool \
  --host_crosstool_top=@bazel_tools//tools/cpp:toolchain \
  --cxxopt="-std=c++14" --cpu=arm64-v8a --config=android_arm64 \
  //tensorflow/lite/tools/benchmark:benchmark_model
