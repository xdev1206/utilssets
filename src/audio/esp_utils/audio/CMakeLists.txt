# audio/CMakeLists.txt

file(GLOB_RECURSE AUDIO_HEADERS *.h *.hpp)

file(GLOB_RECURSE AUDIO_SRC
    common/*.c
    common/*.cpp
    speech_features/*.c
    speech_features/*.cpp)

add_library(audio  ${AUDIO_SRC})

target_include_directories(audio PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/common
        ${CMAKE_CURRENT_SOURCE_DIR}/speech_features
        ${CMAKE_SOURCE_DIR}/include)

target_link_libraries(audio PUBLIC dl_fft)

# 编译选项
if (MSVC)
    target_compile_options(audio PRIVATE /W3)
else()
    target_compile_options(audio PRIVATE -Wall -Wextra -Wno-unused-parameter)
endif()

set(AUDIO_EXPORT_DIR ${EXPORT_INCLUDE_DIR}/audio)

foreach(h ${AUDIO_HEADERS})
    file(RELATIVE_PATH rel ${CMAKE_CURRENT_SOURCE_DIR} ${h})
    configure_file(${h} ${AUDIO_EXPORT_DIR}/${rel} COPYONLY)
endforeach()

install(TARGETS audio
    ARCHIVE DESTINATION ${CMAKE_INSTALL_LIBDIR}
    LIBRARY DESTINATION ${CMAKE_INSTALL_LIBDIR}
    RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR}
)

install(
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/
    DESTINATION ${INSTALL_INCLUDE_DIR}/audio
    FILES_MATCHING
        PATTERN "*.h"
        PATTERN "*.hpp"
)
