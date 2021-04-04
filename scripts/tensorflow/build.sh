sudo apt install python3-dev python3-pip  # or python-dev python-pip

# 安装 TensorFlow pip 软件包依赖项（如果使用虚拟环境，请省略 --user 参数）：

pip3 install -U --user pip six numpy wheel setuptools mock 'future>=0.17.1'
pip3 install -U --user keras_applications --no-deps
pip3 install -U --user keras_preprocessing --no-deps

./configure

export BAZEL_JAVAC_OPTS="-J-Xms2g -J-Xmx3g"
bazel build //tensorflow/tools/pip_package:build_pip_package

# tensorflow lite static library
sudo apt-get install crossbuild-essential-arm64
./tensorflow/lite/tools/make/download_dependencies.sh
./tensorflow/lite/tools/make/build_aarch64_lib.sh
