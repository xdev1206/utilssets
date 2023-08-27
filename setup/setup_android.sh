#!/bin/bash

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)
source $SCRIPT_PATH/env.sh

ANDROID_ENV_PATH=${ENV_PATH}/android

cmdlinetools_mac_url='https://dl.google.com/android/repository/commandlinetools-mac-8512546_latest.zip'
cmdlinetools_linux_url='https://dl.google.com/android/repository/commandlinetools-linux-10406996_latest.zip'

platformtools_linux_url='https://dl.google.com/android/repository/platform-tools_r34.0.4-linux.zip'

cmdline_tools_zip=${cmdlinetools_linux_url##*\/}
sdk_dir=sdk

function android_env_dir()
{
  if [ ! -d ${ANDROID_ENV_PATH}/$sdk_dir ]; then
    mkdir -p ${ANDROID_ENV_PATH}/$sdk_dir
  fi
}

function sdk_setup()
{
  rm -rf ${cmdline_tools_zip}* > /dev/null
  sudo apt install openjdk-17-jdk
  wget -v $cmdline_tools_zip_url
  unzip $cmdline_tools_zip -d ${ANDROID_ENV_PATH}/$sdk_dir
  rm -rf $cmdline_tools_zip

  pushd ${ANDROID_ENV_PATH}/$sdk_dir

  ./cmdline-tools/bin/sdkmanager --sdk_root=. "cmake;3.22.1"
  ./cmdline-tools/bin/sdkmanager --sdk_root=. "build-tools;34.0.0"
  ./cmdline-tools/bin/sdkmanager --sdk_root=. "platform-tools"
  ./cmdline-tools/bin/sdkmanager --sdk_root=. "cmdline-tools;latest"
  #./cmdline-tools/bin/sdkmanager --sdk_root=. "ndk;23.2.8568313"
  #./cmdline-tools/bin/sdkmanager --sdk_root=. "platforms;android-25"

  complete_env_path ${ANDROID_ENV_PATH}/$sdk_dir/platform-tools
  popd
}

# alread downloaded sdk-tools-linux
android_env_dir
sdk_setup
