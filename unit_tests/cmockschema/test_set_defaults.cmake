if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: CMockSchema_SetDefaults
# Validates that version-specific defaults are correctly applied

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(CMockSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/cmockschema_defaults_test")

# Helper to test that a command fails (FATAL_ERROR)
function(test_command_fails DESCRIPTION COMMAND_STRING)
    message(STATUS "  Testing: ${DESCRIPTION}")

    string(MD5 temp_script_id "${DESCRIPTION};${COMMAND_STRING}")
    set(temp_script "${TEST_ROOT}/temp_test_${temp_script_id}.cmake")
    file(WRITE "${temp_script}" "${COMMAND_STRING}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${temp_script}"
        RESULT_VARIABLE cmd_result
        OUTPUT_VARIABLE cmd_output
        ERROR_VARIABLE cmd_error
        OUTPUT_QUIET
        ERROR_QUIET
    )

    file(REMOVE "${temp_script}")

    if(cmd_result EQUAL 0)
        message(STATUS "    ✗ ${DESCRIPTION} - should have failed but succeeded")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    else()
        message(STATUS "    ✓ ${DESCRIPTION} - correctly failed")
    endif()
endfunction()

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_valid_version_sets_defaults)
    message(STATUS "Test 1: Valid version (2.6) sets cache defaults")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

# Unset any cached variables before testing
unset(CMOCK_MOCK_PREFIX CACHE)
unset(CMOCK_PLUGINS CACHE)

CMockSchema_SetDefaults(\"2.6\")

# Verify defaults were set
if(NOT DEFINED CMOCK_MOCK_PREFIX)
    message(FATAL_ERROR \"CMOCK_MOCK_PREFIX not set\")
endif()

if(NOT DEFINED CMOCK_PLUGINS)
    message(FATAL_ERROR \"CMOCK_PLUGINS not set\")
endif()

message(STATUS \"CMOCK_MOCK_PREFIX = \${CMOCK_MOCK_PREFIX}\")
message(STATUS \"CMOCK_PLUGINS = \${CMOCK_PLUGINS}\")
"
    )

    set(script_file "${TEST_ROOT}/test_defaults.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SetDefaults(2.6) failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ SetDefaults(2.6) correctly applied defaults")
endfunction()

function(test_invalid_version_fails)
    message(STATUS "Test 2: Invalid version causes FATAL_ERROR")

    test_command_fails(
        "SetDefaults with unsupported version 99.99"
        "cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)
CMockSchema_SetDefaults(\"99.99\")"
    )
endfunction()

function(test_empty_version_fails)
    message(STATUS "Test 3: Empty version causes FATAL_ERROR")

    test_command_fails(
        "SetDefaults with empty version"
        "cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)
CMockSchema_SetDefaults(\"\")"
    )
endfunction()

function(test_schema_file_loaded)
    message(STATUS "Test 4: Verify schema variables are properly initialized")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

CMockSchema_SetDefaults(\"2.6\")

# Check that expected variables exist
set(expected_vars
    CMOCK_MOCK_PREFIX
    CMOCK_MOCK_SUFFIX
    CMOCK_MOCK_PATH
    CMOCK_INCLUDES
    CMOCK_PLUGINS
    CMOCK_WHEN_NO_PROTOTYPES
    CMOCK_ENFORCE_STRICT_ORDERING
    CMOCK_CALLBACK_INCLUDE_COUNT
)

foreach(var IN LISTS expected_vars)
    if(NOT DEFINED \${var})
        message(FATAL_ERROR \"\${var} not defined after SetDefaults\")
    endif()
    message(STATUS \"\${var} = \${\${var}}\")
endforeach()
"
    )

    set(script_file "${TEST_ROOT}/test_schema_vars.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Schema variables check failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ All expected schema variables are defined")
endfunction()

function(test_default_mock_prefix)
    message(STATUS "Test 5: Verify default mock prefix is 'mock_'")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

CMockSchema_SetDefaults(\"2.6\")

if(NOT CMOCK_MOCK_PREFIX STREQUAL \"mock_\")
    message(FATAL_ERROR \"CMOCK_MOCK_PREFIX should be 'mock_', got '\${CMOCK_MOCK_PREFIX}'\")
endif()
"
    )

    set(script_file "${TEST_ROOT}/test_mock_prefix.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Default mock prefix check failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Default mock prefix correctly set to 'mock_'")
endfunction()

function(test_default_plugins)
    message(STATUS "Test 6: Verify default plugins include 'ignore' and 'callback'")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

CMockSchema_SetDefaults(\"2.6\")

if(NOT \"ignore\" IN_LIST CMOCK_PLUGINS)
    message(FATAL_ERROR \"CMOCK_PLUGINS should include 'ignore'\")
endif()

if(NOT \"callback\" IN_LIST CMOCK_PLUGINS)
    message(FATAL_ERROR \"CMOCK_PLUGINS should include 'callback'\")
endif()
"
    )

    set(script_file "${TEST_ROOT}/test_default_plugins.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Default plugins check failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Default plugins correctly include 'ignore' and 'callback'")
endfunction()

function(run_all_tests)
    message(STATUS "=== CMockSchema_SetDefaults Tests ===")

    setup_test_environment()

    test_valid_version_sets_defaults()
    test_invalid_version_fails()
    test_empty_version_fails()
    test_schema_file_loaded()
    test_default_mock_prefix()
    test_default_plugins()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "CMockSchema SetDefaults tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All CMockSchema SetDefaults tests PASSED")
    endif()
endfunction()

run_all_tests()
