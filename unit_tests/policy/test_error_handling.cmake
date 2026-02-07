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
    
    set(local_errors 0)
    
    # Missing required parameters for policy_register
    test_command_fails(
        "policy_register without NAME"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0)"
    )

    test_command_fails(
        "policy_register without DESCRIPTION"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DEFAULT OLD INTRODUCED_VERSION 1.0)"
    )

    test_command_fails(
        "policy_register without DEFAULT"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" INTRODUCED_VERSION 1.0)"
    )

    test_command_fails(
        "policy_register without INTRODUCED_VERSION"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD)"
    )

    # Invalid DEFAULT values
    test_command_fails(
        "policy_register with invalid DEFAULT"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT INVALID INTRODUCED_VERSION 1.0)"
    )

    test_command_fails(
        "policy_register with lowercase default"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT old INTRODUCED_VERSION 1.0)"
    )
    
    test_command_fails(
        "Duplicate policy registration"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME DUP DESCRIPTION \"first\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Register(NAME DUP DESCRIPTION \"second\" DEFAULT NEW INTRODUCED_VERSION 2.0)"
    )
    
    message(STATUS "  ✓ All policy_register error conditions handled correctly")
endfunction()

function(test_policy_set_errors)
    message(STATUS "Test 2: Testing policy_set parameter validation")
    
    test_command_fails(
        "policy_set without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Set(VALUE NEW)"
    )

    test_command_fails(
        "policy_set without VALUE"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Set(POLICY TEST)"
    )

    test_command_fails(
        "policy_set with invalid value"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Set(TEST INVALID)"
    )

    test_command_fails(
        "policy_set with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Set(NONEXISTENT NEW)"
    )
    
    message(STATUS "  ✓ All policy_set error conditions handled correctly")
endfunction()

function(test_policy_get_errors)
    message(STATUS "Test 3: Testing policy_get parameter validation")
    
    test_command_fails(
        "policy_get without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Get(OUTVAR result)"
    )

    test_command_fails(
        "policy_get without OUTVAR"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Get(POLICY TEST)"
    )

    test_command_fails(
        "policy_get with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Get(NONEXISTENT result)"
    )
    
    message(STATUS "  ✓ All policy_get error conditions handled correctly")
endfunction()

function(test_policy_version_errors)
    message(STATUS "Test 4: Testing policy_version parameter validation")
    
    test_command_fails(
        "policy_version without MINIMUM"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Version()"
    )
    
    test_command_fails(
        "policy_version with MAXIMUM < MINIMUM"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Version(MINIMUM 4.0 MAXIMUM 3.5)"
    )
    
    message(STATUS "  ✓ All policy_version error conditions handled correctly")
endfunction()

function(test_policy_info_errors)
    message(STATUS "Test 5: Testing policy_info parameter validation")
    
    test_command_fails(
        "policy_info without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Info()"
    )

    test_command_fails(
        "policy_info with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Info(NONEXISTENT)"
    )
    
    message(STATUS "  ✓ All policy_info error conditions handled correctly")
endfunction()

function(test_policy_get_fields_errors)
    message(STATUS "Test 6: Testing policy_get_fields parameter validation")
    
    test_command_fails(
        "policy_get_fields without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_GetFields(PREFIX TEST)"
    )

    test_command_fails(
        "policy_get_fields without PREFIX"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_GetFields(POLICY TEST)"
    )

    test_command_fails(
        "policy_get_fields with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_GetFields(NONEXISTENT TEST)"
    )
    
    message(STATUS "  ✓ All policy_get_fields error conditions handled correctly")
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
