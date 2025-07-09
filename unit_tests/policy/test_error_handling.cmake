# Test: Error Handling
# Tests various error conditions and parameter validation

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(TEST_NAME "Error Handling")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Helper function to test that a command fails
function(test_command_fails DESCRIPTION COMMAND_STRING)
    message(STATUS "Testing: ${DESCRIPTION}")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P -c "${COMMAND_STRING}"
        RESULT_VARIABLE cmd_result
        OUTPUT_VARIABLE cmd_output
        ERROR_VARIABLE cmd_error
    )
    if(cmd_result EQUAL 0)
        message(SEND_ERROR "${DESCRIPTION} - should have failed but succeeded")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
    endif()
endfunction()

# Test 1: Missing required parameters for policy_register
test_command_fails(
    "policy_register without NAME"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0)"
)

test_command_fails(
    "policy_register without DESCRIPTION"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DEFAULT OLD INTRODUCED_VERSION 1.0)"
)

test_command_fails(
    "policy_register without DEFAULT"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" INTRODUCED_VERSION 1.0)"
)

test_command_fails(
    "policy_register without INTRODUCED_VERSION"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD)"
)

# Test 2: Invalid DEFAULT values
test_command_fails(
    "policy_register with invalid DEFAULT"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT INVALID INTRODUCED_VERSION 1.0)"
)

test_command_fails(
    "policy_register with lowercase default"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT old INTRODUCED_VERSION 1.0)"
)

# Test 3: Duplicate policy registration
test_command_fails(
    "Duplicate policy registration"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME DUP DESCRIPTION \"first\" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_register(NAME DUP DESCRIPTION \"second\" DEFAULT NEW INTRODUCED_VERSION 2.0)"
)

# Test 4: Missing required parameters for policy_set
test_command_fails(
    "policy_set without POLICY"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_set(VALUE NEW)"
)

test_command_fails(
    "policy_set without VALUE"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_set(POLICY TEST)"
)

# Test 5: Invalid values for policy_set
test_command_fails(
    "policy_set with invalid value"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_set(POLICY TEST VALUE INVALID)"
)

# Test 6: Setting unregistered policy
test_command_fails(
    "policy_set with unregistered policy"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_set(POLICY NONEXISTENT VALUE NEW)"
)

# Test 7: Missing required parameters for policy_get
test_command_fails(
    "policy_get without POLICY"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_get(OUTVAR result)"
)

test_command_fails(
    "policy_get without OUTVAR"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_get(POLICY TEST)"
)

# Test 8: Getting unregistered policy
test_command_fails(
    "policy_get with unregistered policy"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_get(POLICY NONEXISTENT OUTVAR result)"
)

# Test 9: Missing required parameters for policy_version
test_command_fails(
    "policy_version without MINIMUM"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_version(MAXIMUM 2.0)"
)

# Test 10: Missing required parameters for policy_info
test_command_fails(
    "policy_info without POLICY"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_info()"
)

# Test 11: policy_info with unregistered policy
test_command_fails(
    "policy_info with unregistered policy"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_info(POLICY NONEXISTENT)"
)

# Test 12: Missing required parameters for policy_get_fields
test_command_fails(
    "policy_get_fields without POLICY"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_get_fields(PREFIX TEST)"
)

test_command_fails(
    "policy_get_fields without PREFIX"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_get_fields(POLICY TEST)"
)

# Test 13: policy_get_fields with unregistered policy
test_command_fails(
    "policy_get_fields with unregistered policy"
    "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_get_fields(POLICY NONEXISTENT PREFIX TEST)"
)

# Summary
if(ERROR_COUNT EQUAL 0)
    message(STATUS "${TEST_NAME}: PASSED (0 errors)")
else()
    message(STATUS "${TEST_NAME}: FAILED (${ERROR_COUNT} errors)")
endif()
