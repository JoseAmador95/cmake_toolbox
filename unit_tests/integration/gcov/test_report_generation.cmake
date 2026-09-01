if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: end-to-end coverage report generation
#
# Instruments a real project, runs it, then builds the `gcovr` target with the
# real gcovr and asserts that a report containing the instrumented source is
# produced. This is the only test that exercises the assembled gcovr command
# line against the actual tool.

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_gcov_report")

find_program(REAL_GCOVR gcovr)
if(NOT REAL_GCOVR)
    message(STATUS "  - gcovr not installed, skipping report generation test")
    return()
endif()

set(_cmt_test_build_config "")
if(DEFINED CMAKE_TOOLBOX_TEST_BUILD_TYPE AND NOT CMAKE_TOOLBOX_TEST_BUILD_TYPE STREQUAL "")
    set(_cmt_test_build_config "${CMAKE_TOOLBOX_TEST_BUILD_TYPE}")
elseif(
    DEFINED
        CMAKE_TOOLBOX_TEST_GENERATOR
    AND CMAKE_TOOLBOX_TEST_GENERATOR
        MATCHES
        "Visual Studio|Xcode|Multi-Config"
)
    set(_cmt_test_build_config "Debug")
endif()

set(_cmt_test_build_args "")
if(_cmt_test_build_config)
    list(
        APPEND _cmt_test_build_args
        --config
        "${_cmt_test_build_config}"
    )
endif()

message(STATUS "=== Gcov Report Generation Integration Test ===")
message(STATUS "Using gcovr: ${REAL_GCOVR}")

set(src_dir "${TEST_ROOT}/src")
set(build_dir "${TEST_ROOT}/build")
file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${src_dir}")

file(WRITE "${src_dir}/lib.c" "int lib_func(int x) { if (x > 0) { return 1; } return 0; }")
file(
    WRITE "${src_dir}/main.c"
    "extern int lib_func(int); int main(void) { return lib_func(1) - 1; }"
)
file(
    WRITE "${src_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(GcovReportTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Point gcovr at the build tree so it can find the .gcda files
set(CMT_GCOVR_SEARCH_PATH \"\${CMAKE_BINARY_DIR}\" CACHE STRING \"\" FORCE)
set(CMT_GCOVR_OUTPUT_FORMATS \"html;json\" CACHE STRING \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)

add_executable(mytest main.c)
target_link_libraries(mytest PRIVATE mylib)
"
)

TestHelpers_GetConfigureArgs(configure_args)
execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Configuration failed: ${error}")
endif()

execute_process(
    COMMAND
        ${CMAKE_COMMAND} --build "${build_dir}" ${_cmt_test_build_args} --target mytest
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    if("${error}" MATCHES "libclang_rt")
        message(STATUS "  - compiler runtime libraries missing, skipping")
        return()
    endif()
    message(FATAL_ERROR "Build failed: ${error}")
endif()

set(test_bin_dir "${build_dir}")
if(_cmt_test_build_config)
    set(test_bin_dir "${build_dir}/${_cmt_test_build_config}")
endif()
set(_exe_suffix "")
if(WIN32)
    set(_exe_suffix ".exe")
endif()

# Run the instrumented binary so that .gcda files are emitted
execute_process(
    COMMAND
        "${test_bin_dir}/mytest${_exe_suffix}"
    WORKING_DIRECTORY "${build_dir}"
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Instrumented binary exited with ${result}")
endif()

# Build the report target created by the module
execute_process(
    COMMAND
        ${CMAKE_COMMAND} --build "${build_dir}" ${_cmt_test_build_args} --target gcovr
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Building the gcovr target failed:\n${output}\n${error}")
endif()

foreach(artifact "coverage.html" "coverage.json")
    if(NOT EXISTS "${build_dir}/coverage/${artifact}")
        message(FATAL_ERROR "Expected ${artifact} in ${build_dir}/coverage")
    endif()
endforeach()

# The report must actually reference the instrumented translation unit,
# otherwise gcovr ran but found no coverage data.
file(READ "${build_dir}/coverage/coverage.json" coverage_json)
if(NOT coverage_json MATCHES "lib\\.c")
    message(FATAL_ERROR "Coverage report does not mention lib.c; no data was collected")
endif()

message(STATUS "  ok gcovr target produced a populated coverage report")
message(STATUS "Gcov report generation test PASSED")
