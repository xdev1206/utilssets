#!/bin/bash

SCRIPT_PATH=$(cd `dirname $BASH_SOURCE[0]` && /bin/pwd)
source $SCRIPT_PATH/env/env.sh

if [ "${NETWORK}x" == "0x" ]; then
    printf "%s\n" "no network connection, exit..."
    exit 0
fi

ANDROID_ENV_PATH=${ENV_PATH}/android
sdk_dir=sdk

toolsUrlContents=$(curl https://developer.android.com/studio)
cmdlinetools_mac_url=$(echo "${toolsUrlContents}" | grep -o "https:\/\/dl.google.com\/android\/repository\/commandlinetools\-mac\-[0-9]*_latest\.zip")
cmdlinetools_linux_url=$(echo "${toolsUrlContents}" | grep -o "https:\/\/dl.google.com\/android\/repository\/commandlinetools\-linux\-[0-9]*_latest\.zip")

function android_env_dir()
{
    if [ ! -d ${ANDROID_ENV_PATH} ]; then
        mkdir -p ${ANDROID_ENV_PATH}/$sdk_dir
    fi
}

function sdk_setup()
{
  ndk_version=29.0.14206865
  android_env_dir
  pushd ${ANDROID_ENV_PATH}/$sdk_dir

  if [ "x${OS_TYPE}" == "xDarwin" ]; then
      ${SUDO} ${PKG_MANAGER} ${PKG_INSTALL} openjdk@21
      cmdlinetools_zip_url=${cmdlinetools_mac_url}
  elif [ "x${OS_TYPE}" == "xLinux" ]; then
      ${SUDO} ${PKG_MANAGER} ${PKG_UPDATE}
      ${SUDO} ${PKG_MANAGER} ${PKG_INSTALL} openjdk-21-jdk
      cmdlinetools_zip_url=${cmdlinetools_linux_url}
  else
      cmdlinetools_zip_url=${cmdlinetools_linux_url}
  fi

  cmdlinetools_zip=${cmdlinetools_zip_url##*\/}
  printf "%s\n" "cmnlinetools_zip: ${cmdlinetools_zip}"

  if [ ! -f ${cmdlinetools_zip} ]; then
    wget -v $cmdlinetools_zip_url
    unzip -o $cmdlinetools_zip -d ${ANDROID_ENV_PATH}/$sdk_dir
  fi

  ./cmdline-tools/bin/sdkmanager --sdk_root=. "cmake;3.22.1"
  ./cmdline-tools/bin/sdkmanager --sdk_root=. "build-tools;34.0.0"
  ./cmdline-tools/bin/sdkmanager --sdk_root=. "platform-tools"
  ./cmdline-tools/bin/sdkmanager --sdk_root=. "cmdline-tools;latest"
  ./cmdline-tools/bin/sdkmanager --sdk_root=. "ndk;${ndk_version}"
  ./cmdline-tools/bin/sdkmanager --sdk_root=. "platforms;android-25"

  complete_env_path ${ANDROID_ENV_PATH}/$sdk_dir/platform-tools
  complete_env_path ${ANDROID_ENV_PATH}/$sdk_dir/cmdline-tools/bin
  if [ "$?" == "0" ]; then
      export_env ANDROID_SDK_ROOT ${ANDROID_ENV_PATH}/$sdk_dir
      export_env ANDROID_NDK_HOME ${ANDROID_ENV_PATH}/$sdk_dir/ndk/${ndk_version}
      export_env ANDROID_HOME ${ANDROID_ENV_PATH}/$sdk_dir
  fi
  popd
}

sdk_setup
