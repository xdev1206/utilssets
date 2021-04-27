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
${SUDO} apt install python3-dev python3-pip  # or python-dev python-pip

# 安装 TensorFlow pip 软件包依赖项（如果使用虚拟环境，请省略 --user 参数）：

pip3 install -U --user pip six numpy wheel setuptools mock 'future>=0.17.1'
pip3 install -U --user keras_applications --no-deps
pip3 install -U --user keras_preprocessing --no-deps

./configure

export BAZEL_JAVAC_OPTS="-J-Xms2g -J-Xmx3g"
bazel build //tensorflow/tools/pip_package:build_pip_package

# build for linux aarch64 lib
${SUDO} apt install crossbuild-essential-arm64
# download dependencies
./tensorflow/lite/tools/make/download_dependencies.sh
# build
${SUDO} apt-get install crossbuild-essential-arm64
