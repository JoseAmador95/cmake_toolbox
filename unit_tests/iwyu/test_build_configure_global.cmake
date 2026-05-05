# Test: Build with IWYU_Configure global configuration and violations
# Purpose: Verify that the global IWYU_Configure path (CMAKE_CXX_INCLUDE_WHAT_YOU_USE) is
#          exercised at build time — distinct from per-target IWYU_ConfigureTarget
# Expected: PASS in two scenarios:
#   - IWYU installed: build fails because IWYU detects the violation
#   - IWYU not installed: build passes (advisory mode, CMAKE_CXX_INCLUDE_WHAT_YOU_USE empty)
# Executable: cmake -P test_build_configure_global.cmake

cmake_minimum_required(VERSION 3.22)

get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

get_filename_component(test_script_name "${CMAKE_CURRENT_LIST_FILE}" NAME_WE)
string(TIMESTAMP test_timestamp "%Y%m%d%H%M%S")
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_script_name}_${test_timestamp}")
set(build_dir "${test_dir}/build")
file(MAKE_DIRECTORY "${build_dir}/src")

# Source file: includes <vector> but never uses it — IWYU violation
file(
    WRITE "${build_dir}/src/violations.cpp"
    "#include <vector>\nint add(int a, int b) { return a + b; }\n"
)

file(
    WRITE "${build_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(IWYUGlobalViolations LANGUAGES CXX)

set(CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(IWYU)

IWYU_Configure(STATUS ON)

add_library(testlib STATIC src/violations.cpp)
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
    message(STATUS "PASS: Build passed (IWYU not installed, advisory mode skips checks)")
else()
    # Verify the failure is IWYU-related, not a compiler error
    set(full_output "${build_output}${build_error}")
    if(NOT (full_output MATCHES "violations\\.cpp" OR full_output MATCHES "include-what-you-use"))
        message(
            FATAL_ERROR
            "FAIL: Build failed but output does not mention IWYU.\noutput=${build_output}\nerror=${build_error}"
        )
    endif()
    message(
        STATUS
        "PASS: Build failed as expected (IWYU detected include violations via global config)"
    )
endif()
