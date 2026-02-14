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
# Validates that defaults are correctly applied

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(CMockSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/cmockschema_defaults_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_defaults_set)
    message(STATUS "Test 1: SetDefaults applies cache defaults")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

unset(CMOCK_MOCK_PREFIX CACHE)
unset(CMOCK_PLUGINS CACHE)

CMockSchema_SetDefaults()

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
        message(STATUS "  ✗ SetDefaults failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Defaults correctly applied")
endfunction()

function(test_schema_variables_defined)
    message(STATUS "Test 2: Verify schema variables are initialized")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

CMockSchema_SetDefaults()

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
    message(STATUS "Test 3: Verify default mock prefix is 'mock_'")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

CMockSchema_SetDefaults()

if(NOT CMOCK_MOCK_PREFIX STREQUAL \"mock_\")
    message(FATAL_ERROR \"CMOCK_MOCK_PREFIX should be 'mock_', got \${CMOCK_MOCK_PREFIX}\")
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
    message(STATUS "Test 4: Verify default plugins include 'ignore' and 'callback'")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

CMockSchema_SetDefaults()

list(FIND CMOCK_PLUGINS \"ignore\" ignore_plugin_idx)
if(ignore_plugin_idx EQUAL -1)
    message(FATAL_ERROR \"CMOCK_PLUGINS should include 'ignore'\")
endif()

list(FIND CMOCK_PLUGINS \"callback\" callback_plugin_idx)
if(callback_plugin_idx EQUAL -1)
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

    test_defaults_set()
    test_schema_variables_defined()
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
