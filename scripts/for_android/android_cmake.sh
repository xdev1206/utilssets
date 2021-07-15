#!/bin/bash

function android_cmake_usage {
    echo -e "  Methods of cmake compiling with Android NDK:"
    echo -e "   optional argument:"
    echo -e "      --ndk=path: specify Android NDK path"
    echo -e "      --api_level=(21|22|...): specify Android API Level"
    echo -e "      --abi=(arm64-v8a|armeabi-v7a): specify Android ABI"
    echo -e "      --stl=(c++_static|c++_shared): specify Android stl library"
    echo -e "  ----"
    echo -e "  Example:"
    echo -e "  android_cmake.sh --ndk=$HOME/android-ndk-r21d --api_level=28 --abi=arm64-v8a --stl=c++_static"
    echo
}

function args_parser {
  NDK="$HOME/android-ndk-r21d"
  API_LEVEL="29"
  ANDROID_STL="c++_static"
  ANDROID_ABI="arm64-v8a"

  for arg in "$@"; do
    case $arg in
      --ndk=*)
        NDK="${arg#*=}"
        ;;
      --api_level=*)
        API_LEVEL="${arg#*=}"
        ;;
      --abi=*)
        echo $arg
        ANDROID_ABI="${arg#*=}"
        ;;
      --stl=*)
        ANDROID_STL="${arg#*=}"
        ;;
      *)
        echo -e "Warning: unknown argument \"${arg}\"\n----"
        ;;
    esac
    shift
  done

  CMAKE_ANDROID_OPTIONS="-DCMAKE_TOOLCHAIN_FILE=$NDK/build/cmake/android.toolchain.cmake \
    -DCMAKE_ANDROID_NDK=$NDK \
    -DANDROID_NATIVE_API_LEVEL=$API_LEVEL \
    -DANDROID_ABI=$ANDROID_ABI \
    -DANDROID_STL=$ANDROID_STL "

  echo -e "CMAKE_ANDROID_OPTIONS: ${CMAKE_ANDROID_OPTIONS}"
}

function parser {
  if [ $# -eq 0 ]; then
    echo -e "Error: needs arguments\n----"
    android_cmake_usage
    exit 1
  fi

  args_parser $@
}
