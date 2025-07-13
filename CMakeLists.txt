cmake_minimum_required(VERSION 3.22)

project(cmake_toolbox VERSION 0.1)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

if(PROJECT_IS_TOP_LEVEL)
    enable_testing()
    add_subdirectory(examples)
endif()
