# dl_fft/CMakeLists.txt

file(GLOB_RECURSE ESP_FFT_HEADERS *.h *.hpp)

file(GLOB ESP_FFT_SRC *.c base/*.c)

if(ESP_FFT_BUILD_SHARED)
    add_library(esp_fft SHARED ${ESP_FFT_SRC})
else()
    add_library(esp_fft STATIC ${ESP_FFT_SRC})
endif()

target_include_directories(esp_fft PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/base
        ${CMAKE_SOURCE_DIR}/include)

# 编译选项
if (MSVC)
    target_compile_options(esp_fft PRIVATE /W3)
else()
    target_compile_options(esp_fft PRIVATE -Wall -Wextra -Wno-unused-parameter -ffast-math -O2)
endif()

# Linux 下数学库
if (UNIX AND NOT APPLE)
    target_link_libraries(esp_fft m)
endif()

set_target_properties(esp_fft PROPERTIES
    POSITION_INDEPENDENT_CODE ON
    ARCHIVE_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/lib
    RUNTIME_OUTPUT_DIRECTORY ${CMAKE_BINARY_DIR}/bin
)

set(ESP_FFT_INCLUDE_DIR ${CMAKE_BINARY_DIR}/include/esp_fft)
file(MAKE_DIRECTORY ${ESP_FFT_INCLUDE_DIR})

foreach(h ${ESP_FFT_HEADERS})
    file(RELATIVE_PATH rel ${CMAKE_CURRENT_SOURCE_DIR} ${h})
    configure_file(${h} ${ESP_FFT_INCLUDE_DIR}/${rel} COPYONLY)
endforeach()
