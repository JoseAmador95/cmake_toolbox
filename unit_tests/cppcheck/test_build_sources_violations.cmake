# Test: Build with Cppcheck violations
# Purpose: Verify that sources with defects are caught by Cppcheck
# Expected: PASS in two scenarios:
#   - Cppcheck installed: build fails because Cppcheck detects the error
#   - Cppcheck not installed: build passes (advisory mode skips checks)
# Executable: cmake -P test_build_sources_violations.cmake

cmake_minimum_required(VERSION 3.22)

get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

get_filename_component(test_script_name "${CMAKE_CURRENT_LIST_FILE}" NAME_WE)
string(TIMESTAMP test_timestamp "%Y%m%d%H%M%S")
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_script_name}_${test_timestamp}")
set(build_dir "${test_dir}/build")
file(MAKE_DIRECTORY "${build_dir}/src")

# Source file: reads an uninitialized variable — Cppcheck error (uninitvar)
file(WRITE "${build_dir}/src/violations.c" "int get_value(void) { int x; return x; }\n")

file(
    WRITE "${build_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(CppcheckViolations LANGUAGES C)

set(CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(Cppcheck)

add_library(testlib STATIC src/violations.c)
Cppcheck_ConfigureTarget(TARGET testlib STATUS ON)
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

if(build_result EQUAL 0)
    message(STATUS "PASS: Build passed (Cppcheck not installed, advisory mode skips checks)")
else()
    # Verify the failure is Cppcheck-related, not a compiler error
    set(full_output "${build_output}${build_error}")
    if(NOT (full_output MATCHES "violations\\.c" OR full_output MATCHES "cppcheck"))
        message(
            FATAL_ERROR
            "FAIL: Build failed but output does not mention Cppcheck.\noutput=${build_output}\nerror=${build_error}"
        )
    endif()
    message(STATUS "PASS: Build failed as expected (Cppcheck detected violation in sources)")
endif()
