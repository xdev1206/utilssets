cmake_minimum_required(VERSION 3.10)

add_executable(feat_test feat_test.cpp)

target_include_directories(kaldi-native-fbank
    PUBLIC
        ${CMAKE_BINARY_DIR}/include
)

target_compile_features(feat_test PRIVATE cxx_std_14)

target_link_libraries(feat_test PRIVATE kaldi-native-fbank)

# 输出到 build/bin
set_target_properties(feat_test PROPERTIES
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)
