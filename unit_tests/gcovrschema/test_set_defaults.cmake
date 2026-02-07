# Test: GcovrSchema_SetDefaults
# Validates that version-specific defaults are correctly applied

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH "${REPO_ROOT}/cmake" ${CMAKE_MODULE_PATH})

include(GcovrSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/gcovrschema_defaults_test")

# Helper to test that a command fails (FATAL_ERROR)
function(test_command_fails DESCRIPTION COMMAND_STRING)
    message(STATUS "  Testing: ${DESCRIPTION}")
    
    string(MD5 temp_script_id "${DESCRIPTION};${COMMAND_STRING}")
    set(temp_script "${TEST_ROOT}/temp_test_${temp_script_id}.cmake")
    file(WRITE "${temp_script}" "${COMMAND_STRING}")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P "${temp_script}"
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
    message(STATUS "Test 1: Valid version (7.0) sets cache defaults")
    
    # Clear any existing cache values by running in subprocess
    set(test_script "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

# Unset any cached variables before testing
unset(GCOVR_FAIL_UNDER_LINE CACHE)
unset(GCOVR_FAIL_UNDER_BRANCH CACHE)
unset(GCOVR_HTML_HIGH_THRESHOLD CACHE)

GcovrSchema_SetDefaults(\"7.0\")

# Verify defaults were set
if(NOT DEFINED GCOVR_FAIL_UNDER_LINE)
    message(FATAL_ERROR \"GCOVR_FAIL_UNDER_LINE not set\")
endif()

if(NOT DEFINED GCOVR_HTML_HIGH_THRESHOLD)
    message(FATAL_ERROR \"GCOVR_HTML_HIGH_THRESHOLD not set\")
endif()

message(STATUS \"GCOVR_FAIL_UNDER_LINE = \${GCOVR_FAIL_UNDER_LINE}\")
message(STATUS \"GCOVR_HTML_HIGH_THRESHOLD = \${GCOVR_HTML_HIGH_THRESHOLD}\")
")
    
    set(script_file "${TEST_ROOT}/test_defaults.cmake")
    file(WRITE "${script_file}" "${test_script}")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    
    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SetDefaults(7.0) failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ SetDefaults(7.0) correctly applied defaults")
endfunction()

function(test_invalid_version_fails)
    message(STATUS "Test 2: Invalid version causes FATAL_ERROR")
    
    test_command_fails(
        "SetDefaults with unsupported version 99.99"
        "cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)
GcovrSchema_SetDefaults(\"99.99\")"
    )
endfunction()

function(test_empty_version_fails)
    message(STATUS "Test 3: Empty version causes FATAL_ERROR")
    
    test_command_fails(
        "SetDefaults with empty version"
        "cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)
GcovrSchema_SetDefaults(\"\")"
    )
endfunction()

function(test_schema_file_loaded)
    message(STATUS "Test 4: Verify schema variables are properly initialized")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults(\"7.0\")

# Check that expected variables exist with sensible values
set(expected_vars
    GCOVR_ENFORCE_THRESHOLDS
    GCOVR_FAIL_UNDER_LINE
    GCOVR_FAIL_UNDER_BRANCH
    GCOVR_FAIL_UNDER_FUNCTION
    GCOVR_HTML_HIGH_THRESHOLD
    GCOVR_HTML_MEDIUM_THRESHOLD
    GCOVR_OUTPUT_FORMATS
    GCOVR_PRINT_SUMMARY
)

foreach(var IN LISTS expected_vars)
    if(NOT DEFINED \${var})
        message(FATAL_ERROR \"\${var} not defined after SetDefaults\")
    endif()
    message(STATUS \"\${var} = \${\${var}}\")
endforeach()
")
    
    set(script_file "${TEST_ROOT}/test_schema_vars.cmake")
    file(WRITE "${script_file}" "${test_script}")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P "${script_file}"
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

function(test_threshold_defaults_are_zero)
    message(STATUS "Test 5: Verify fail-under thresholds default to 0")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults(\"7.0\")

# Thresholds should default to zero (no enforcement by default)
if(NOT GCOVR_FAIL_UNDER_LINE STREQUAL \"0\")
    message(FATAL_ERROR \"GCOVR_FAIL_UNDER_LINE should be 0, got \${GCOVR_FAIL_UNDER_LINE}\")
endif()

if(NOT GCOVR_FAIL_UNDER_BRANCH STREQUAL \"0\")
    message(FATAL_ERROR \"GCOVR_FAIL_UNDER_BRANCH should be 0, got \${GCOVR_FAIL_UNDER_BRANCH}\")
endif()
")
    
    set(script_file "${TEST_ROOT}/test_threshold_defaults.cmake")
    file(WRITE "${script_file}" "${test_script}")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    
    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Threshold defaults check failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Fail-under thresholds correctly default to 0")
endfunction()

function(run_all_tests)
    message(STATUS "=== GcovrSchema_SetDefaults Tests ===")
    
    setup_test_environment()
    
    test_valid_version_sets_defaults()
    test_invalid_version_fails()
    test_empty_version_fails()
    test_schema_file_loaded()
    test_threshold_defaults_are_zero()
    
    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "GcovrSchema SetDefaults tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All GcovrSchema SetDefaults tests PASSED")
    endif()
endfunction()

run_all_tests()
