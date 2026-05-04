if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_ctest")
set(SRC_DIR "${TEST_ROOT}/junit/src")
set(BUILD_DIR "${TEST_ROOT}/junit/build")

set(_cmt_test_build_config "")
if(DEFINED CMAKE_TOOLBOX_TEST_BUILD_TYPE AND NOT CMAKE_TOOLBOX_TEST_BUILD_TYPE STREQUAL "")
    set(_cmt_test_build_config "${CMAKE_TOOLBOX_TEST_BUILD_TYPE}")
elseif(DEFINED CMAKE_TOOLBOX_TEST_GENERATOR
    AND CMAKE_TOOLBOX_TEST_GENERATOR MATCHES "Visual Studio|Xcode|Multi-Config|Ninja Multi-Config"
)
    set(_cmt_test_build_config "Debug")
endif()

if(_cmt_test_build_config)
    set(CMAKE_TOOLBOX_TEST_BUILD_TYPE "${_cmt_test_build_config}")
endif()

file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${SRC_DIR}")

set(test_cmake_lists
    "cmake_minimum_required(VERSION 3.22)
project(CTestJunitOutput LANGUAGES C)

enable_testing()
include(CTest)

add_executable(junit_output_pass main.c)
add_executable(junit_output_fail main.c)
target_compile_definitions(junit_output_fail PRIVATE TEST_SHOULD_FAIL=1)

add_test(NAME junit_output_pass COMMAND junit_output_pass)
add_test(NAME junit_output_fail COMMAND junit_output_fail)
"
)

set(test_source
    [==[
#include <stdio.h>
#include <stdlib.h>

int main(void) {
#ifdef TEST_SHOULD_FAIL
  const char *tag = "FAIL";
#else
  const char *tag = "PASS";
#endif
  printf("OUTPUT_START_STDOUT_%s\n", tag);
  for (int i = 0; i < 5000; ++i) {
    putchar('A');
  }
  printf("\nOUTPUT_END_STDOUT_%s\n", tag);
  fprintf(stderr, "OUTPUT_START_STDERR_%s\n", tag);
  for (int i = 0; i < 5000; ++i) {
    fputc('B', stderr);
  }
  fprintf(stderr, "\nOUTPUT_END_STDERR_%s\n", tag);
  fflush(stdout);
  fflush(stderr);
#ifdef TEST_SHOULD_FAIL
  return 1;
#else
  return 0;
#endif
}
]==]
)

file(WRITE "${SRC_DIR}/CMakeLists.txt" "${test_cmake_lists}")
file(WRITE "${SRC_DIR}/main.c" "${test_source}")

TestHelpers_GetConfigureArgs(configure_args)
execute_process(
    COMMAND ${CMAKE_COMMAND} -S "${SRC_DIR}" -B "${BUILD_DIR}" ${configure_args}
    RESULT_VARIABLE configure_result
    OUTPUT_VARIABLE configure_output
    ERROR_VARIABLE configure_error
)

if(NOT configure_result EQUAL 0)
    message(FATAL_ERROR "CTest JUnit config failed: ${configure_error}")
endif()

set(build_args "")
if(_cmt_test_build_config)
    set(build_args --config "${_cmt_test_build_config}")
endif()

execute_process(
    COMMAND ${CMAKE_COMMAND} --build "${BUILD_DIR}" ${build_args}
    RESULT_VARIABLE build_result
    OUTPUT_VARIABLE build_output
    ERROR_VARIABLE build_error
)

if(NOT build_result EQUAL 0)
    message(FATAL_ERROR "CTest JUnit build failed: ${build_error}")
endif()

if(NOT CMAKE_CTEST_COMMAND)
    set(CMAKE_CTEST_COMMAND ctest)
endif()

set(junit_file "${BUILD_DIR}/junit-results.xml")
set(ctest_args --test-dir "${BUILD_DIR}" --output-junit "${junit_file}")
if(_cmt_test_build_config)
    list(APPEND ctest_args -C "${_cmt_test_build_config}")
endif()
list(APPEND ctest_args --test-output-size-passed 200000)
list(APPEND ctest_args --test-output-size-failed 400000)

execute_process(
    COMMAND ${CMAKE_CTEST_COMMAND} ${ctest_args}
    RESULT_VARIABLE ctest_result
    OUTPUT_VARIABLE ctest_output
    ERROR_VARIABLE ctest_error
)

if(ctest_result EQUAL 0)
    message(FATAL_ERROR "Expected failing test to make ctest return non-zero")
endif()

if(NOT EXISTS "${junit_file}")
    message(FATAL_ERROR "JUnit output not generated: ${junit_file}")
endif()

set(_cmt_test_markers
    "OUTPUT_START_STDOUT_PASS"
    "OUTPUT_END_STDOUT_PASS"
    "OUTPUT_START_STDERR_PASS"
    "OUTPUT_END_STDERR_PASS"
    "OUTPUT_START_STDOUT_FAIL"
    "OUTPUT_END_STDOUT_FAIL"
    "OUTPUT_START_STDERR_FAIL"
    "OUTPUT_END_STDERR_FAIL"
)

function(_cmt_test_marker_present_hex marker hex_content result_var)
    string(HEX "${marker}" marker_hex)

    string(FIND "${hex_content}" "${marker_hex}" marker_index_utf8)
    if(NOT marker_index_utf8 EQUAL -1)
        set(${result_var} TRUE PARENT_SCOPE)
        return()
    endif()

    string(REGEX REPLACE "([0-9a-f][0-9a-f])" "\\1 00" marker_hex_le_spaced "${marker_hex}")
    string(REPLACE " " "" marker_hex_le "${marker_hex_le_spaced}")
    string(FIND "${hex_content}" "${marker_hex_le}" marker_index_le)
    if(NOT marker_index_le EQUAL -1)
        set(${result_var} TRUE PARENT_SCOPE)
        return()
    endif()

    string(REGEX REPLACE "([0-9a-f][0-9a-f])" "00\\1" marker_hex_be_spaced "${marker_hex}")
    string(REPLACE " " "" marker_hex_be "${marker_hex_be_spaced}")
    string(FIND "${hex_content}" "${marker_hex_be}" marker_index_be)
    if(NOT marker_index_be EQUAL -1)
        set(${result_var} TRUE PARENT_SCOPE)
        return()
    endif()

    set(${result_var} FALSE PARENT_SCOPE)
endfunction()

file(READ "${junit_file}" _cmt_test_junit_hex HEX)

set(_cmt_test_missing_markers "")
foreach(marker IN LISTS _cmt_test_markers)
    _cmt_test_marker_present_hex("${marker}" "${_cmt_test_junit_hex}" marker_present)
    if(NOT marker_present)
        list(APPEND _cmt_test_missing_markers "${marker}")
    endif()
endforeach()

if(_cmt_test_missing_markers)
    file(SIZE "${junit_file}" _cmt_test_junit_size)
    set(_cmt_test_hex_head "")
    string(LENGTH "${_cmt_test_junit_hex}" _cmt_test_hex_length)
    if(_cmt_test_hex_length GREATER 0)
        set(_cmt_test_hex_head_length 200)
        if(_cmt_test_hex_length LESS _cmt_test_hex_head_length)
            set(_cmt_test_hex_head_length ${_cmt_test_hex_length})
        endif()
        string(SUBSTRING "${_cmt_test_junit_hex}" 0 ${_cmt_test_hex_head_length} _cmt_test_hex_head)
    endif()
    message(
        FATAL_ERROR
        "Missing markers in JUnit output: ${_cmt_test_missing_markers}\n"
        "JUnit size (bytes): ${_cmt_test_junit_size}\n"
        "JUnit hex head: ${_cmt_test_hex_head}"
    )
endif()

message(STATUS "JUnit output captured full stdout/stderr markers")
