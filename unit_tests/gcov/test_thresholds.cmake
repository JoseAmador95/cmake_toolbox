# Test: Gcovr threshold enforcement
#
# CMT_GCOVR_ENFORCE_THRESHOLDS turns the CMT_GCOVR_FAIL_UNDER_* values into
# --fail-under-* arguments on the gcovr command line. Because they live on the
# command line (and not in the generated gcovr.cfg) the behaviour is identical
# in generated mode and in CONFIG_FILE mode; the last case below pins that down.
#
# Each case configures a throwaway project that dumps ${CMT_GCOVR_COMMAND} to a
# file, then asserts on the resolved command line.

if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcov_thresholds")

file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${TEST_ROOT}")
TestHelpers_CreateMockGcovr(_gcovr_mock OUTPUT_DIR "${TEST_ROOT}/mock_gcovr")
file(TO_CMAKE_PATH "${_gcovr_mock}" GCOVR_MOCK_PATH)
TestHelpers_GetConfigureArgs(CONFIGURE_ARGS)

# Configure a project with the given cache settings and assert on the resolved
# gcovr command line.
#
#   NAME            unique case name (also the artifact sub-directory)
#   SETTINGS        extra CMake statements injected before include(Gcov)
#   EXPECT_PRESENT  list of substrings that must appear in CMT_GCOVR_COMMAND
#   EXPECT_ABSENT   list of substrings that must NOT appear in CMT_GCOVR_COMMAND
function(run_case NAME SETTINGS EXPECT_PRESENT EXPECT_ABSENT)
    message(STATUS "Case: ${NAME}")

    set(src_dir "${TEST_ROOT}/${NAME}/src")
    set(build_dir "${TEST_ROOT}/${NAME}/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")
    file(
        WRITE "${src_dir}/CMakeLists.txt"
        "
cmake_minimum_required(VERSION 3.22)
project(GcovThresholdsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)
${SETTINGS}
include(Gcov)
add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)
file(WRITE \"\${CMAKE_BINARY_DIR}/gcovr_command.txt\" \"\${CMT_GCOVR_COMMAND}\")
"
    )

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${CONFIGURE_ARGS}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  x configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${build_dir}/gcovr_command.txt" command_line)
    set(local_errors 0)

    foreach(expected IN LISTS EXPECT_PRESENT)
        if(NOT command_line MATCHES "${expected}")
            message(STATUS "  x expected '${expected}' in gcovr command: ${command_line}")
            math(EXPR local_errors "${local_errors} + 1")
        endif()
    endforeach()

    foreach(unexpected IN LISTS EXPECT_ABSENT)
        if(command_line MATCHES "${unexpected}")
            message(STATUS "  x unexpected '${unexpected}' in gcovr command: ${command_line}")
            math(EXPR local_errors "${local_errors} + 1")
        endif()
    endforeach()

    if(local_errors EQUAL 0)
        message(STATUS "  ok")
    else()
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + ${local_errors}")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

message(STATUS "=== Gcovr Threshold Enforcement Tests ===")

# All four metrics are forwarded when enforcement is ON.
run_case(
    enforce_on
    "
set(CMT_GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_BRANCH 70 CACHE STRING \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_FUNCTION 90 CACHE STRING \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_DECISION 100 CACHE STRING \"\" FORCE)
"
    "--fail-under-line;80;--fail-under-branch;70;--fail-under-function;90;--fail-under-decision;100"
    ""
)

# Values are ignored entirely when enforcement is OFF.
run_case(
    enforce_off
    "
set(CMT_GCOVR_ENFORCE_THRESHOLDS OFF CACHE BOOL \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_BRANCH 70 CACHE STRING \"\" FORCE)
"
    ""
    "--fail-under"
)

# A threshold of 0 means "no threshold" and must not reach gcovr.
run_case(
    zero_threshold_excluded
    "
set(CMT_GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_BRANCH 0 CACHE STRING \"\" FORCE)
"
    "--fail-under-line;80"
    "--fail-under-branch;--fail-under-function;--fail-under-decision"
)

# Enforcement without any threshold configured must still configure cleanly.
run_case(
    enforce_without_thresholds
    "set(CMT_GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)"
    ""
    "--fail-under"
)

# CONFIG_FILE mode honours the thresholds too: they are appended to the command
# line, where gcovr gives them precedence over the config file contents.
file(MAKE_DIRECTORY "${TEST_ROOT}/config_file_mode/src")
file(WRITE "${TEST_ROOT}/config_file_mode/src/custom.cfg" "exclude = tests/\n")
run_case(
    config_file_mode
    "
set(CMT_GCOVR_CONFIG_FILE \"\${CMAKE_CURRENT_SOURCE_DIR}/custom.cfg\" CACHE FILEPATH \"\" FORCE)
set(CMT_GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)
"
    "--fail-under-line;80;custom\\.cfg"
    "gcovr_generated\\.cfg"
)

message(STATUS "")
if(ERROR_COUNT GREATER 0)
    message(FATAL_ERROR "Gcovr threshold tests failed with ${ERROR_COUNT} error(s)")
else()
    message(STATUS "All Gcovr threshold tests PASSED")
endif()
