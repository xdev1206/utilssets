cmake_minimum_required(VERSION 2.8)

# This variable holds the name of the project as specified
# in the top level CMakeLists.txt file by a project() command.
project(cmake_example)

option(BUILD_DEMO "enable demo" ON)

if (BUILD_DEMO)
    add_subdirectory(demo)
endif()

# if DEBUG in c/c++
add_definitions(-DDEBUG)

if(CMAKE_SYSTEM_NAME MATCHES "Android")
    message("cmake system name: ${CMAKE_SYSTEM_NAME}")
endif()

if (CMAKE_BUILD_TYPE MATCHES "Debug")
    message("cmake build type: ${CMAKE_BUILD_TYPE}")
endif()

# set shell env value to cmake variable
set(DEP_PATH $ENV{example_variable})

# header files path
include_directories(
    ${DEP_PATH}/include
    )

# libraries path
link_directories(
    ${DEP_PATH}/libs
    )
