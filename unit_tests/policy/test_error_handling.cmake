# Test: Error Handling
# Tests various error conditions and parameter validation

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(ERROR_COUNT 0)

function(setup_test_environment)
    # No file system setup needed for policy tests
    message(STATUS "Setting up error handling test environment")
endfunction()

# Helper function to test that a command fails
function(test_command_fails DESCRIPTION COMMAND_STRING)
    message(STATUS "  Testing: ${DESCRIPTION}")
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P -c "${COMMAND_STRING}"
        RESULT_VARIABLE cmd_result
        OUTPUT_VARIABLE cmd_output
        ERROR_VARIABLE cmd_error
    )
    if(cmd_result EQUAL 0)
        message(STATUS "    ✗ ${DESCRIPTION} - should have failed but succeeded")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
    else()
        message(STATUS "    ✓ ${DESCRIPTION} - correctly failed")
    endif()
endfunction()

function(test_policy_register_errors)
    message(STATUS "Test 1: Testing policy_register parameter validation")
    
    # Missing required parameters for policy_register
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

    # Invalid DEFAULT values
    test_command_fails(
        "policy_register with invalid DEFAULT"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT INVALID INTRODUCED_VERSION 1.0)"
    )

    test_command_fails(
        "policy_register with lowercase default"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION \"test\" DEFAULT old INTRODUCED_VERSION 1.0)"
    )
    
    test_command_fails(
        "Duplicate policy registration"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME DUP DESCRIPTION "first" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_register(NAME DUP DESCRIPTION "second" DEFAULT NEW INTRODUCED_VERSION 2.0)"
    )
endfunction()

function(test_policy_set_errors)
    message(STATUS "Test 2: Testing policy_set parameter validation")
    
    test_command_fails(
        "policy_set without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_set(VALUE NEW)"
    )

    test_command_fails(
        "policy_set without VALUE"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION "test" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_set(POLICY TEST)"
    )

    test_command_fails(
        "policy_set with invalid value"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION "test" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_set(POLICY TEST VALUE INVALID)"
    )

    test_command_fails(
        "policy_set with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_set(POLICY NONEXISTENT VALUE NEW)"
    )
endfunction()

function(test_policy_get_errors)
    message(STATUS "Test 3: Testing policy_get parameter validation")
    
    test_command_fails(
        "policy_get without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_get(OUTVAR result)"
    )

    test_command_fails(
        "policy_get without OUTVAR"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION "test" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_get(POLICY TEST)"
    )

    test_command_fails(
        "policy_get with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_get(POLICY NONEXISTENT OUTVAR result)"
    )
endfunction()

function(test_policy_version_errors)
    message(STATUS "Test 4: Testing policy_version parameter validation")
    
    test_command_fails(
        "policy_version without MINIMUM"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_version()"
    )
endfunction()

function(test_policy_info_errors)
    message(STATUS "Test 5: Testing policy_info parameter validation")
    
    test_command_fails(
        "policy_info without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_info()"
    )

    test_command_fails(
        "policy_info with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_info(POLICY NONEXISTENT)"
    )
endfunction()

function(test_policy_get_fields_errors)
    message(STATUS "Test 6: Testing policy_get_fields parameter validation")
    
    test_command_fails(
        "policy_get_fields without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_get_fields(PREFIX TEST)"
    )

    test_command_fails(
        "policy_get_fields without PREFIX"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_register(NAME TEST DESCRIPTION "test" DEFAULT OLD INTRODUCED_VERSION 1.0); policy_get_fields(POLICY TEST)"
    )

    test_command_fails(
        "policy_get_fields with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); policy_get_fields(POLICY NONEXISTENT PREFIX TEST)"
    )
endfunction()

function(cleanup_test_environment)
    # No cleanup needed for policy tests
    message(STATUS "Cleaning up error handling test environment")
endfunction()

function(run_all_tests)
    message(STATUS "=== Error Handling Unit Tests ===")
    
    setup_test_environment()
    test_policy_register_errors()
    test_policy_set_errors()
    test_policy_get_errors()
    test_policy_version_errors()
    test_policy_info_errors()
    test_policy_get_fields_errors()
    cleanup_test_environment()
    
    # Test Summary
    message(STATUS "")
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "✓ All tests passed!")
    else()
        message(STATUS "✗ ${ERROR_COUNT} test(s) failed")
    endif()
    message(STATUS "")
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
    run_all_tests()
endif()

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
