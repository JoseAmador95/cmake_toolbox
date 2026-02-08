if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: Gcov SCHEMA mode with threshold enforcement
# Verifies that fail-under thresholds are correctly written to config

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_gcov_thresholds")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_thresholds_enforcement_on)
    message(STATUS "Test 1: Threshold enforcement ON writes fail-under to config")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovThresholdsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Enable threshold enforcement with specific values
set(GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)
set(GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)
set(GCOVR_FAIL_UNDER_BRANCH 70 CACHE STRING \"\" FORCE)
set(GCOVR_FAIL_UNDER_FUNCTION 90 CACHE STRING \"\" FORCE)
set(GCOVR_FAIL_UNDER_DECISION 60 CACHE STRING \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)

message(STATUS \"Thresholds enforcement ON test configured\")
"
    )

    set(src_dir "${TEST_ROOT}/enforce_on/src")
    set(build_dir "${TEST_ROOT}/enforce_on/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Verify config file contains all thresholds
    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    if(NOT EXISTS "${config_file}")
        message(STATUS "  ✗ Config file not created")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${config_file}" config_content)

    # Check for all fail-under entries
    string(
        FIND "${config_content}"
        "fail-under-line = 80"
        has_line
    )
    string(
        FIND "${config_content}"
        "fail-under-branch = 70"
        has_branch
    )
    string(
        FIND "${config_content}"
        "fail-under-function = 90"
        has_function
    )
    string(
        FIND "${config_content}"
        "fail-under-decision = 60"
        has_decision
    )

    if(has_line EQUAL -1)
        message(STATUS "  ✗ Missing fail-under-line in config")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(has_branch EQUAL -1)
        message(STATUS "  ✗ Missing fail-under-branch in config")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(has_function EQUAL -1)
        message(STATUS "  ✗ Missing fail-under-function in config")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(has_decision EQUAL -1)
        message(STATUS "  ✗ Missing fail-under-decision in config")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)

    if(
        NOT has_line
            EQUAL
            -1
        AND NOT has_branch
            EQUAL
            -1
        AND NOT has_function
            EQUAL
            -1
        AND NOT has_decision
            EQUAL
            -1
    )
        message(STATUS "  ✓ All fail-under thresholds present in config")
    endif()
endfunction()

function(test_thresholds_enforcement_off)
    message(STATUS "Test 2: Threshold enforcement OFF omits fail-under from config")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovThresholdsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Disable threshold enforcement but set values
set(GCOVR_ENFORCE_THRESHOLDS OFF CACHE BOOL \"\" FORCE)
set(GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)
set(GCOVR_FAIL_UNDER_BRANCH 70 CACHE STRING \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)
"
    )

    set(src_dir "${TEST_ROOT}/enforce_off/src")
    set(build_dir "${TEST_ROOT}/enforce_off/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    file(READ "${config_file}" config_content)

    # Verify fail-under entries are NOT present
    string(
        FIND "${config_content}"
        "fail-under-line"
        has_line
    )
    string(
        FIND "${config_content}"
        "fail-under-branch"
        has_branch
    )

    if(NOT has_line EQUAL -1 OR NOT has_branch EQUAL -1)
        message(STATUS "  ✗ fail-under should not be present when enforcement is OFF")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ fail-under entries correctly omitted when enforcement OFF")
endfunction()

function(test_threshold_zero_excluded)
    message(STATUS "Test 3: Threshold value 0 is excluded from config")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovThresholdsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)
set(GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)
set(GCOVR_FAIL_UNDER_BRANCH 0 CACHE STRING \"\" FORCE)  # Should be excluded

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)
"
    )

    set(src_dir "${TEST_ROOT}/zero_threshold/src")
    set(build_dir "${TEST_ROOT}/zero_threshold/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    file(READ "${config_file}" config_content)

    string(
        FIND "${config_content}"
        "fail-under-line"
        has_line
    )
    string(
        FIND "${config_content}"
        "fail-under-branch"
        has_branch
    )

    if(has_line EQUAL -1)
        message(STATUS "  ✗ fail-under-line (80) should be present")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT has_branch EQUAL -1)
        message(STATUS "  ✗ fail-under-branch (0) should be excluded")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)

    if(NOT has_line EQUAL -1 AND has_branch EQUAL -1)
        message(STATUS "  ✓ Zero threshold correctly excluded")
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== Gcov Threshold Enforcement Integration Tests ===")

    setup_test_environment()

    test_thresholds_enforcement_on()
    test_thresholds_enforcement_off()
    test_threshold_zero_excluded()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Gcov threshold tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Gcov threshold tests PASSED")
    endif()
endfunction()

run_all_tests()
