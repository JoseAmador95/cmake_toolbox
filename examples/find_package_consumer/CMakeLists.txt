cmake_minimum_required(VERSION 3.22)

project(cmake_toolbox_find_package_consumer LANGUAGES C)

find_package(cmake_toolbox CONFIG REQUIRED)

include(Policy)
include(ClangFormat)

add_library(consumer_example STATIC consumer_example.c)
