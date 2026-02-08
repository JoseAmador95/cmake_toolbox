if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: FindUnity behavior via real find_package(Unity)

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_findunity_find_package")
set(TEST_PROJECT_SOURCE_DIR "${TEST_ROOT}/project")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_PROJECT_SOURCE_DIR}")

    set(_project_file
        "
cmake_minimum_required(VERSION 3.22)
project(FindUnityIntegration LANGUAGES C)

set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG FALSE)
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH FALSE)
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH FALSE)

find_package(Unity REQUIRED)

if(NOT TARGET Unity::Unity)
    message(FATAL_ERROR \"Unity::Unity target was not created\")
endif()

if(DEFINED EXPECT_VERSION AND NOT Unity_VERSION STREQUAL EXPECT_VERSION)
    message(FATAL_ERROR \"Unexpected Unity_VERSION='\${Unity_VERSION}', expected '\${EXPECT_VERSION}'\")
endif()

if(DEFINED EXPECT_ROOT)
    file(TO_CMAKE_PATH \"\${EXPECT_ROOT}\" expected_root_norm)
    file(TO_CMAKE_PATH \"\${Unity_SOURCE}\" unity_source_norm)
    cmake_path(IS_PREFIX expected_root_norm "\${unity_source_norm}" NORMALIZE is_under_root)
    if(NOT is_under_root)
        message(FATAL_ERROR \"Unity source path '\${Unity_SOURCE}' did not resolve from expected root '\${EXPECT_ROOT}'\")
    endif()
endif()
"
    )

    file(WRITE "${TEST_PROJECT_SOURCE_DIR}/CMakeLists.txt" "${_project_file}")

    set(_unity_layout_root "${TEST_ROOT}/fixtures/unity_root")
    file(MAKE_DIRECTORY "${_unity_layout_root}/src")
    file(
        WRITE "${_unity_layout_root}/src/unity.h"
        "#define UNITY_VERSION_MAJOR 2\n#define UNITY_VERSION_MINOR 6\n#define UNITY_VERSION_BUILD 1\n"
    )
    file(WRITE "${_unity_layout_root}/src/unity.c" "int unity_stub(void) { return 0; }\n")

    set(_unity_env_root "${TEST_ROOT}/fixtures/unity_env")
    file(MAKE_DIRECTORY "${_unity_env_root}/src")
    file(
        WRITE "${_unity_env_root}/src/unity.h"
        "#define UNITY_VERSION_MAJOR 2\n#define UNITY_VERSION_MINOR 5\n"
    )
    file(WRITE "${_unity_env_root}/src/unity.c" "int unity_env_stub(void) { return 0; }\n")

    set(_unity_broken_root "${TEST_ROOT}/fixtures/unity_broken")
    file(MAKE_DIRECTORY "${_unity_broken_root}/include")
    file(
        WRITE "${_unity_broken_root}/include/unity.h"
        "#define UNITY_VERSION_MAJOR 1\n#define UNITY_VERSION_MINOR 0\n"
    )

    set(UNITY_ROOT_FIXTURE "${_unity_layout_root}" PARENT_SCOPE)
    set(UNITY_ENV_FIXTURE "${_unity_env_root}" PARENT_SCOPE)
    set(UNITY_BROKEN_FIXTURE "${_unity_broken_root}" PARENT_SCOPE)
endfunction()

function(run_configure_case name expect_success)
    set(options)
    set(oneValueArgs work_dir expected_error_substring)
    set(multiValueArgs args)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${TEST_PROJECT_SOURCE_DIR}" -B "${ARG_work_dir}" ${ARG_args}
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(expect_success)
        if(NOT configure_result EQUAL 0)
            message(STATUS "  [FAIL] ${name}: configure failed")
            message(STATUS "  stdout: ${configure_output}")
            message(STATUS "  stderr: ${configure_error}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()
        message(STATUS "  [PASS] ${name}")
        return()
    endif()

    if(configure_result EQUAL 0)
        message(STATUS "  [FAIL] ${name}: expected configure failure")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(ARG_expected_error_substring)
        set(_combined_output "${configure_output}\n${configure_error}")
        string(FIND "${_combined_output}" "${ARG_expected_error_substring}" error_index)
        if(error_index EQUAL -1)
            message(STATUS "  [FAIL] ${name}: missing expected error text '${ARG_expected_error_substring}'")
            message(STATUS "  stdout: ${configure_output}")
            message(STATUS "  stderr: ${configure_error}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()
    endif()

    message(STATUS "  [PASS] ${name}")
endfunction()

function(test_unset_hints_fail)
    message(STATUS "Test 1: configure fails when no Unity hints are provided")
    unset(ENV{UNITY_ROOT})
    run_configure_case(
        "unset hints"
        FALSE
        work_dir
            "${TEST_ROOT}/build_unset_hints"
        expected_error_substring
            "Could NOT find Unity"
        args
            "-DUnity_ROOT="
            "-DUNITY_ROOT="
    )
endfunction()

function(test_unity_root_hint)
    message(STATUS "Test 2: Unity_ROOT hint resolves a valid Unity layout")
    unset(ENV{UNITY_ROOT})
    run_configure_case(
        "Unity_ROOT hint"
        TRUE
        work_dir
            "${TEST_ROOT}/build_unity_root_hint"
        args
            "-DUnity_ROOT=${UNITY_ROOT_FIXTURE}"
            "-DEXPECT_ROOT=${UNITY_ROOT_FIXTURE}"
            "-DEXPECT_VERSION=2.6.1"
    )
endfunction()

function(test_env_hint)
    message(STATUS "Test 3: UNITY_ROOT environment hint resolves Unity")
    set(ENV{UNITY_ROOT} "${UNITY_ENV_FIXTURE}")
    run_configure_case(
        "environment hint"
        TRUE
        work_dir
            "${TEST_ROOT}/build_env_hint"
        args
            "-DUnity_ROOT="
            "-DUNITY_ROOT="
            "-DEXPECT_ROOT=${UNITY_ENV_FIXTURE}"
            "-DEXPECT_VERSION=2.5"
    )
    unset(ENV{UNITY_ROOT})
endfunction()

function(test_unsupported_layout_fail)
    message(STATUS "Test 4: malformed Unity layout fails with deterministic diagnostics")
    unset(ENV{UNITY_ROOT})
    run_configure_case(
        "unsupported layout"
        FALSE
        work_dir
            "${TEST_ROOT}/build_unsupported_layout"
        expected_error_substring
            "Could NOT find Unity"
        args
            "-DUnity_ROOT=${UNITY_BROKEN_FIXTURE}"
    )
endfunction()

function(run_all_tests)
    message(STATUS "=== FindUnity Integration Tests (find_package) ===")

    setup_test_environment()
    test_unset_hints_fail()
    test_unity_root_hint()
    test_env_hint()
    test_unsupported_layout_fail()

    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "FindUnity integration tests failed with ${ERROR_COUNT} error(s)")
    endif()

    message(STATUS "All FindUnity integration tests PASSED")
endfunction()

run_all_tests()
