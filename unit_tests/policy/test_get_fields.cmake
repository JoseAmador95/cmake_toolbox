# Test: Policy Get Fields Function
# Tests policy_get_fields function with various scenarios

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(ERROR_COUNT 0)

function(setup_test_environment)
    # No file system setup needed for policy tests
    message(STATUS "Setting up policy get fields test environment")
    
    # Register policies for testing
    policy_register(NAME FIELDS001 
                    DESCRIPTION "Policy for fields testing" 
                    DEFAULT OLD 
                    INTRODUCED_VERSION 1.2.3 
                    WARNING "Test warning with | pipe")

    policy_register(NAME FIELDS002 
                    DESCRIPTION "Policy without warning" 
                    DEFAULT NEW 
                    INTRODUCED_VERSION 2.0.0)
endfunction()

function(test_get_fields_with_warning)
    message(STATUS "Test 1: Getting fields for policy with warning (default state)")
    
    policy_get_fields(POLICY FIELDS001 PREFIX TEST1)

    # Verify all fields
    if(NOT TEST1_NAME STREQUAL "FIELDS001")
        message(STATUS "  ✗ TEST1_NAME should be 'FIELDS001', got: '${TEST1_NAME}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TEST1_DESCRIPTION STREQUAL "Policy for fields testing")
        message(STATUS "  ✗ TEST1_DESCRIPTION mismatch, got: '${TEST1_DESCRIPTION}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TEST1_DEFAULT STREQUAL "OLD")
        message(STATUS "  ✗ TEST1_DEFAULT should be 'OLD', got: '${TEST1_DEFAULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TEST1_INTRODUCED_VERSION STREQUAL "1.2.3")
        message(STATUS "  ✗ TEST1_INTRODUCED_VERSION should be '1.2.3', got: '${TEST1_INTRODUCED_VERSION}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TEST1_WARNING STREQUAL "Test warning with | pipe")
        message(STATUS "  ✗ TEST1_WARNING should contain pipe character, got: '${TEST1_WARNING}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TEST1_CURRENT_VALUE STREQUAL "OLD")
        message(STATUS "  ✗ TEST1_CURRENT_VALUE should be 'OLD' (default), got: '${TEST1_CURRENT_VALUE}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TEST1_IS_DEFAULT)
        message(STATUS "  ✗ TEST1_IS_DEFAULT should be TRUE, got: '${TEST1_IS_DEFAULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Fields retrieved correctly for policy with warning")
endfunction()

function(test_is_default_changes)
    message(STATUS "Test 2: Setting policy and verifying IS_DEFAULT changes")
    
    policy_set(POLICY FIELDS001 VALUE NEW)
    policy_get_fields(POLICY FIELDS001 PREFIX TEST1_SET)

    if(NOT TEST1_SET_CURRENT_VALUE STREQUAL "NEW")
        message(STATUS "  ✗ TEST1_SET_CURRENT_VALUE should be 'NEW', got: '${TEST1_SET_CURRENT_VALUE}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(TEST1_SET_IS_DEFAULT)
        message(STATUS "  ✗ TEST1_SET_IS_DEFAULT should be FALSE, got: '${TEST1_SET_IS_DEFAULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ IS_DEFAULT correctly changed after setting policy")
endfunction()

function(test_policy_without_warning)
    message(STATUS "Test 3: Getting fields for policy without warning")
    
    policy_get_fields(POLICY FIELDS002 PREFIX TEST2)

    if(NOT TEST2_WARNING STREQUAL "")
        message(STATUS "  ✗ TEST2_WARNING should be empty, got: '${TEST2_WARNING}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TEST2_CURRENT_VALUE STREQUAL "NEW")
        message(STATUS "  ✗ TEST2_CURRENT_VALUE should be 'NEW' (default), got: '${TEST2_CURRENT_VALUE}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT TEST2_IS_DEFAULT)
        message(STATUS "  ✗ TEST2_IS_DEFAULT should be TRUE, got: '${TEST2_IS_DEFAULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Fields retrieved correctly for policy without warning")
endfunction()

function(test_multiple_prefixes)
    message(STATUS "Test 4: Testing multiple prefixes don't interfere")
    
    policy_get_fields(POLICY FIELDS001 PREFIX PREFIX_A)
    policy_get_fields(POLICY FIELDS002 PREFIX PREFIX_B)

    if(NOT PREFIX_A_NAME STREQUAL "FIELDS001")
        message(STATUS "  ✗ PREFIX_A_NAME should be 'FIELDS001', got: '${PREFIX_A_NAME}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT PREFIX_B_NAME STREQUAL "FIELDS002")
        message(STATUS "  ✗ PREFIX_B_NAME should be 'FIELDS002', got: '${PREFIX_B_NAME}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Multiple prefixes work correctly")
endfunction()

function(test_error_handling)
    message(STATUS "Test 5: Testing error handling for unregistered policy")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P -c "
            include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
            policy_get_fields(POLICY NONEXISTENT PREFIX TEST)
        "
        RESULT_VARIABLE unreg_result
        OUTPUT_VARIABLE unreg_output
        ERROR_VARIABLE unreg_error
    )
    if(unreg_result EQUAL 0)
        message(STATUS "  ✗ Getting fields for unregistered policy should have failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Error handling working correctly")
endfunction()

function(cleanup_test_environment)
    # No cleanup needed for policy tests
    message(STATUS "Cleaning up policy get fields test environment")
endfunction()

function(run_all_tests)
    message(STATUS "=== Policy Get Fields Unit Tests ===")
    
    setup_test_environment()
    test_get_fields_with_warning()
    test_is_default_changes()
    test_policy_without_warning()
    test_multiple_prefixes()
    test_error_handling()
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
