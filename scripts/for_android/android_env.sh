#!/bin/bash

commandlinetools_mac='https://dl.google.com/android/repository/commandlinetools-mac-8512546_latest.zip'

env_root=$HOME/env/android
sdk_tools_zip_url='https://dl.google.com/android/repository/sdk-tools-linux-4333796.zip'
sdk_tools_zip=${sdk_tools_zip_url##*\/}
sdk_dir=sdk

function android_env_dir()
{
  if [ ! -d $env_root/$sdk_dir ]; then
    mkdir -p $env_root/$sdk_dir
  fi
}

function sdk_setup()
{
  wget $sdk_tools_zip_url
  unzip $sdk_tools_zip -d $env_root/$sdk_dir
  rm -rf $sdk_tools_zip

  pushd $env_root/$sdk_dir

  ./tools/bin/sdkmanager "cmake;3.6.4111459"
  ./tools/bin/sdkmanager "build-tools;27.0.3"
  ./tools/bin/sdkmanager "platforms;android-25"
  ./tools/bin/sdkmanager "platform-tools"
  ./tools/bin/sdkmanager "ndk-bundle"

  popd

  echo -e "\nPATH=$env_root/$sdk_dir/platform-tools:$PATH" >> ~/.bashrc
}

# alread downloaded sdk-tools-linux
android_env_dir
sdk_setup
