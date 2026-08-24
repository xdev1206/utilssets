cmake_minimum_required(VERSION 3.10)

project(kaldi_native_fbank
    LANGUAGES CXX
)

option(KALDI_FBANK_BUILD_SHARED "Build shared library" OFF)
option(USE_ESP_FFT "Build shared library" OFF)

set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

set(KALDI_FBANK_SOURCES
    feature-fbank.cc
    feature-functions.cc
    feature-mfcc.cc
    feature-raw-audio-samples.cc
    feature-window.cc
    istft.cc
    kaldi-math.cc
    log.cc
    mel-computations.cc
    online-feature.cc
    stft.cc
    whisper-feature.cc
)

if(USE_ESP_FFT)
    list(APPEND KALDI_FBANK_SOURCES "rfft_esp.cc")
else()
    list(APPEND KALDI_FBANK_SOURCES "rfft.cc")
endif()

# 库类型
if(KALDI_FBANK_BUILD_SHARED)
    add_library(kaldi-native-fbank SHARED ${KALDI_FBANK_SOURCES})
else()
    add_library(kaldi-native-fbank STATIC ${KALDI_FBANK_SOURCES})
endif()

if(USE_ESP_FFT)
    target_link_libraries(kaldi-native-fbank PUBLIC esp_fft)
else()
    target_link_libraries(kaldi-native-fbank PUBLIC kissfft)
endif()

# =========================
# include 路径
# =========================
target_include_directories(kaldi-native-fbank
    PUBLIC
        ${CMAKE_BINARY_DIR}/include
        ${CMAKE_BINARY_DIR}/include/esp_fft
        ${CMAKE_BINARY_DIR}/include/esp_fft/base
        ${CMAKE_CURRENT_SOURCE_DIR}
)

# math lib
if(UNIX AND NOT APPLE)
    target_link_libraries(kaldi-native-fbank PUBLIC m)
endif()

set_target_properties(kaldi-native-fbank PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

# =========================
# build 阶段复制头文件
# =========================
set(KALDI_FBANK_INCLUDE_DIR
    ${CMAKE_BINARY_DIR}/include/kaldi-native-fbank/csrc
)

file(MAKE_DIRECTORY ${KALDI_FBANK_INCLUDE_DIR})

add_custom_target(kaldi_fbank_headers ALL
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_SOURCE_DIR}/feature-fbank.h
        ${CMAKE_CURRENT_SOURCE_DIR}/feature-functions.h
        ${CMAKE_CURRENT_SOURCE_DIR}/feature-mfcc.h
        ${CMAKE_CURRENT_SOURCE_DIR}/feature-raw-audio-samples.h
        ${CMAKE_CURRENT_SOURCE_DIR}/feature-window.h
        ${CMAKE_CURRENT_SOURCE_DIR}/istft.h
        ${CMAKE_CURRENT_SOURCE_DIR}/kaldi-math.h
        ${CMAKE_CURRENT_SOURCE_DIR}/log.h
        ${CMAKE_CURRENT_SOURCE_DIR}/mel-computations.h
        ${CMAKE_CURRENT_SOURCE_DIR}/online-feature.h
        ${CMAKE_CURRENT_SOURCE_DIR}/rfft.h
        ${CMAKE_CURRENT_SOURCE_DIR}/stft.h
        ${CMAKE_CURRENT_SOURCE_DIR}/whisper-feature.h
        ${KALDI_FBANK_INCLUDE_DIR}
)

add_dependencies(kaldi-native-fbank kaldi_fbank_headers)
