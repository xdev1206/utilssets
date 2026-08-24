#cmake -DBUILD_SHARED_LIBS=ON ..

cmake_minimum_required(VERSION 3.10)

project(esp_utils LANGUAGES C CXX)

set(CMAKE_C_STANDARD 99)
set(CMAKE_CXX_STANDARD 14)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

option(BUILD_SHARED_LIBS "Build shared libraries (.so/.dll)" ON)

set(BUILD_INCLUDE_DIR ${CMAKE_BINARY_DIR}/include)
set(EXPORT_INCLUDE_DIR ${BUILD_INCLUDE_DIR})

set(CMAKE_ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib)
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin)

add_custom_target(export_root_headers ALL
    COMMAND ${CMAKE_COMMAND} -E copy_directory
            ${CMAKE_SOURCE_DIR}/include
            ${EXPORT_INCLUDE_DIR})

add_subdirectory(dl_fft)
add_subdirectory(audio)
add_subdirectory(test)

add_dependencies(dl_fft export_root_headers)
add_dependencies(audio export_root_headers)
