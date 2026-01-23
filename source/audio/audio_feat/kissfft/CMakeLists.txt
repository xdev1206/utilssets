cmake_minimum_required(VERSION 3.10)

project(kissfft
    VERSION 1.0
    LANGUAGES C CXX
)

option(KISSFFT_FIXED_POINT "Use fixed-point arithmetic" OFF)
option(KISSFFT_BUILD_SHARED "Build kissfft as shared library" OFF)

set(KISSFFT_SOURCES
    kiss_fft.c
    kiss_fftnd.c
    kiss_fftndr.c
    kiss_fftr.c
    kfc.c
)

# 库类型
if(KISSFFT_BUILD_SHARED)
    add_library(kissfft SHARED ${KISSFFT_SOURCES})
else()
    add_library(kissfft STATIC ${KISSFFT_SOURCES})
endif()

# =========================
# include 路径（对外暴露）
# =========================
target_include_directories(kissfft
    PUBLIC
        ${CMAKE_BINARY_DIR}/include        # <build>/include
        ${CMAKE_CURRENT_SOURCE_DIR}        # 内部编译用
)

if(KISSFFT_FIXED_POINT)
    target_compile_definitions(kissfft PUBLIC FIXED_POINT)
endif()

if(UNIX AND NOT APPLE)
    target_link_libraries(kissfft PUBLIC m)
endif()

set_target_properties(kissfft PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

# =========================
# build 阶段复制头文件
# =========================
set(KISSFFT_INCLUDE_DIR ${CMAKE_BINARY_DIR}/include/kissfft)
file(MAKE_DIRECTORY ${KISSFFT_INCLUDE_DIR})

add_custom_target(kissfft_headers ALL
    COMMAND ${CMAKE_COMMAND} -E copy_if_different
        ${CMAKE_CURRENT_SOURCE_DIR}/kiss_fft.h
        ${CMAKE_CURRENT_SOURCE_DIR}/kiss_fftr.h
        ${CMAKE_CURRENT_SOURCE_DIR}/kiss_fftnd.h
        ${CMAKE_CURRENT_SOURCE_DIR}/kiss_fftndr.h
        ${CMAKE_CURRENT_SOURCE_DIR}/kiss_fft_log.h
        ${CMAKE_CURRENT_SOURCE_DIR}/kfc.h
        ${CMAKE_CURRENT_SOURCE_DIR}/kissfft.hh
        ${CMAKE_CURRENT_SOURCE_DIR}/kissfft_i32.hh
        ${KISSFFT_INCLUDE_DIR}
)

add_dependencies(kissfft kissfft_headers)

