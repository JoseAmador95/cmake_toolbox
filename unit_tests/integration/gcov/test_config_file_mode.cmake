if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: Gcov CONFIG_FILE mode
# Verifies that external config file is used instead of generating one

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_gcov_config_file")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_gcovr")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)
    set(GCOVR_MOCK_PATH "${mock_gcovr_path}" PARENT_SCOPE)
endfunction()

function(test_config_file_mode_uses_external)
    message(STATUS "Test 1: CONFIG_FILE mode uses external config file")

    set(src_dir "${TEST_ROOT}/external_config/src")
    set(build_dir "${TEST_ROOT}/external_config/build")
    file(MAKE_DIRECTORY "${src_dir}")

    # Create external gcovr config
    file(
        WRITE "${src_dir}/my_gcovr.cfg"
        "# Custom gcovr config
root = .
filter = src/
exclude = test/
html-details = yes
"
    )

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovConfigFileTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)

# Use external config file
set(CMT_GCOVR_CONFIG_FILE \"\${CMAKE_CURRENT_SOURCE_DIR}/my_gcovr.cfg\" CACHE FILEPATH \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)

message(STATUS \"CONFIG_FILE mode configured\")
"
    )

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

    # Verify NO generated config file was created
    if(EXISTS "${build_dir}/coverage/gcovr_generated.cfg")
        message(STATUS "  ✗ Generated config should NOT exist in CONFIG_FILE mode")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ CONFIG_FILE mode correctly uses external config")
endfunction()

function(test_config_file_mode_warns_enforce)
    message(STATUS "Test 2: CONFIG_FILE mode warns when CMT_GCOVR_ENFORCE_THRESHOLDS is set")

    set(src_dir "${TEST_ROOT}/enforce_warning/src")
    set(build_dir "${TEST_ROOT}/enforce_warning/build")
    file(MAKE_DIRECTORY "${src_dir}")

    file(WRITE "${src_dir}/gcovr.cfg" "root = .\n")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovConfigFileTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)

set(CMT_GCOVR_CONFIG_FILE \"\${CMAKE_CURRENT_SOURCE_DIR}/gcovr.cfg\" CACHE FILEPATH \"\" FORCE)
set(CMT_GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)
"
    )

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

    # Check for warning in output
    string(
        FIND "${output}${error}"
        "CMT_GCOVR_ENFORCE_THRESHOLDS is ignored"
        has_warning
    )
    if(has_warning EQUAL -1)
        message(STATUS "  ✗ Expected warning about CMT_GCOVR_ENFORCE_THRESHOLDS being ignored")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Warning correctly emitted for ignored CMT_GCOVR_ENFORCE_THRESHOLDS")
endfunction()

function(run_all_tests)
    message(STATUS "=== Gcov CONFIG_FILE Mode Integration Tests ===")

    setup_test_environment()

    test_config_file_mode_uses_external()
    test_config_file_mode_warns_enforce()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Gcov CONFIG_FILE mode tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Gcov CONFIG_FILE mode tests PASSED")
    endif()
endfunction()

run_all_tests()
