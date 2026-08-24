# dl_fft/CMakeLists.txt

file(GLOB_RECURSE DL_FFT_HEADERS *.h *.hpp)

file(GLOB DL_FFT_SRC *.c base/*.c)

add_library(dl_fft ${DL_FFT_SRC})

target_include_directories(dl_fft PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/base
        ${CMAKE_SOURCE_DIR}/include)

# 编译选项
if (MSVC)
    target_compile_options(dl_fft PRIVATE /W3)
else()
    target_compile_options(dl_fft PRIVATE -Wall -Wextra -Wno-unused-parameter -ffast-math -O2)
endif()

# Linux 下数学库
if (UNIX AND NOT APPLE)
    target_link_libraries(dl_fft m)
endif()

set(DL_FFT_EXPORT_DIR ${EXPORT_INCLUDE_DIR}/dl_fft)

foreach(h ${DL_FFT_HEADERS})
    file(RELATIVE_PATH rel ${CMAKE_CURRENT_SOURCE_DIR} ${h})
    configure_file(${h} ${DL_FFT_EXPORT_DIR}/${rel} COPYONLY)
endforeach()

install(TARGETS dl_fft
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})

install(
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/
    DESTINATION ${INSTALL_INCLUDE_DIR}/dl_fft
    FILES_MATCHING
        PATTERN "*.h"
        PATTERN "*.hpp")
