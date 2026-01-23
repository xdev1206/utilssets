cmake_minimum_required(VERSION 3.10)
project(audio_sdk LANGUAGES C CXX)

option(BUILD_TEST "Build tests" OFF)

add_subdirectory(kissfft)
add_subdirectory(kaldi-native-fbank)

if(BUILD_TEST)
    add_subdirectory(test)
endif()
