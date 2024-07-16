cmake_minimum_required(VERSION 3.22)

project(cmake_toolbox VERSION 0.1)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/cmake" CACHE INTERNAL "CMake module path" FORCE)

if(PROJECT_IS_TOP_LEVEL)
    enable_testing()
    add_subdirectory(examples)
endif()