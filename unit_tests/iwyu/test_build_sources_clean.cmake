# Test: Build with IWYU-clean sources
# Purpose: Verify that C++ sources with correct includes pass IWYU analysis
# Expected: PASS (build always succeeds whether IWYU is installed or not)
# Executable: cmake -P test_build_sources_clean.cmake

cmake_minimum_required(VERSION 3.22)

get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

get_filename_component(test_script_name "${CMAKE_CURRENT_LIST_FILE}" NAME_WE)
string(TIMESTAMP test_timestamp "%Y%m%d%H%M%S")
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_script_name}_${test_timestamp}")
set(build_dir "${test_dir}/build")
file(MAKE_DIRECTORY "${build_dir}/src")

# Source file: no includes at all — definitively no IWYU violations possible
file(WRITE "${build_dir}/src/add.cpp" "int add(int a, int b) { return a + b; }\n")

file(
    WRITE "${build_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(IWYUCleanSources LANGUAGES CXX)

set(CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(IWYU)

add_library(testlib STATIC src/add.cpp)
IWYU_ConfigureTarget(TARGET testlib STATUS ON)
"
)

execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${build_dir}" -B "${build_dir}/cmake_build"
    RESULT_VARIABLE config_result
    OUTPUT_VARIABLE config_output
    ERROR_VARIABLE config_error
)
if(NOT (config_result EQUAL 0))
    file(REMOVE_RECURSE "${test_dir}")
    message(FATAL_ERROR "FAIL: Configure failed: ${config_error}")
endif()

execute_process(
    COMMAND
        ${CMAKE_COMMAND} --build "${build_dir}/cmake_build"
    RESULT_VARIABLE build_result
    OUTPUT_VARIABLE build_output
    ERROR_VARIABLE build_error
)

file(REMOVE_RECURSE "${test_dir}")

if(NOT (build_result EQUAL 0))
    message(
        FATAL_ERROR
        "FAIL: Build failed on clean sources. output=${build_output} error=${build_error}"
    )
endif()

message(STATUS "PASS: Clean sources built successfully")
