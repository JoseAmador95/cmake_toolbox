# Test: Basic Policy Operations
# Tests policy_register, policy_set, policy_get functions

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(ERROR_COUNT 0)

function(setup_test_environment)
    # No file system setup needed for policy tests
    message(STATUS "Setting up policy test environment")
endfunction()

function(test_basic_policy_registration)
    message(STATUS "Test 1: Basic policy registration and verification")
    
    # Register the policies
    Policy_Register(NAME BASIC001 
                    DESCRIPTION "Basic test policy" 
                    DEFAULT OLD 
                    INTRODUCED_VERSION 1.0)
    
    Policy_Register(NAME BASIC002 
                    DESCRIPTION "Policy with warning" 
                    DEFAULT NEW 
                    INTRODUCED_VERSION 2.0 
                    WARNING "This is a test warning")
    
    Policy_Register(NAME BASIC003 
                    DESCRIPTION "Policy with complex warning" 
                    DEFAULT OLD 
                    INTRODUCED_VERSION 1.5 
                    WARNING "Line 1 of warning
Line 2 with | pipe character
Line 3 with multiple | pipes | here")
    
    # Verify BASIC001 registration
    Policy_GetFields(BASIC001 B1)
    if(NOT B1_NAME STREQUAL "BASIC001")
        message(STATUS "  ✗ BASIC001 name should be 'BASIC001', got: '${B1_NAME}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    if(NOT B1_DESCRIPTION STREQUAL "Basic test policy")
        message(STATUS "  ✗ BASIC001 description mismatch, got: '${B1_DESCRIPTION}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    if(NOT B1_DEFAULT STREQUAL "OLD")
        message(STATUS "  ✗ BASIC001 default should be 'OLD', got: '${B1_DEFAULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    if(NOT B1_INTRODUCED_VERSION STREQUAL "1.0")
        message(STATUS "  ✗ BASIC001 version should be '1.0', got: '${B1_INTRODUCED_VERSION}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    # Verify BASIC002 registration (with warning)
    Policy_GetFields(BASIC002 B2)
    if(NOT B2_WARNING STREQUAL "This is a test warning")
        message(STATUS "  ✗ BASIC002 warning mismatch, got: '${B2_WARNING}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    if(NOT B2_DEFAULT STREQUAL "NEW")
        message(STATUS "  ✗ BASIC002 default should be 'NEW', got: '${B2_DEFAULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    # Verify BASIC003 registration (complex warning with pipes)
    Policy_GetFields(BASIC003 B3)
    set(expected_warning "Line 1 of warning
Line 2 with | pipe character
Line 3 with multiple | pipes | here")
    if(NOT B3_WARNING STREQUAL expected_warning)
        message(STATUS "  ✗ BASIC003 complex warning mismatch")
        message(STATUS "    Expected: '${expected_warning}'")
        message(STATUS "    Got: '${B3_WARNING}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ All policies registered and verified correctly")
endfunction()

function(test_default_policy_values)
    message(STATUS "Test 2: Getting default policy values")
    
    Policy_Get(BASIC001 val1)
    if(NOT val1 STREQUAL "OLD")
        message(STATUS "  ✗ BASIC001 should return OLD, got: ${val1}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    Policy_Get(BASIC002 val2)
    if(NOT val2 STREQUAL "NEW")
        message(STATUS "  ✗ BASIC002 should return NEW, got: ${val2}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Default policy values correct")
endfunction()

function(test_policy_setting)
    message(STATUS "Test 3: Setting and verifying policy values")
    
    # Set the values
    Policy_Set(BASIC001 NEW)
    Policy_Set(BASIC002 OLD)
    
    # Immediately verify they were set correctly
    Policy_Get(BASIC001 val1_new)
    if(NOT val1_new STREQUAL "NEW")
        message(STATUS "  ✗ BASIC001 should be NEW after setting, got: ${val1_new}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    Policy_Get(BASIC002 val2_old)
    if(NOT val2_old STREQUAL "OLD")
        message(STATUS "  ✗ BASIC002 should be OLD after setting, got: ${val2_old}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Policy values set and verified correctly")
endfunction()

function(test_policy_value_persistence)
    message(STATUS "Test 4: Verifying policy values persist correctly")
    
    # Verify the values are still set from the previous test
    Policy_Get(BASIC001 val1_check)
    if(NOT val1_check STREQUAL "NEW")
        message(STATUS "  ✗ BASIC001 value should persist as NEW, got: ${val1_check}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    Policy_Get(BASIC002 val2_check)
    if(NOT val2_check STREQUAL "OLD")
        message(STATUS "  ✗ BASIC002 value should persist as OLD, got: ${val2_check}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    # Test setting the same value again (should not cause issues)
    Policy_Set(BASIC001 NEW)
    Policy_Get(BASIC001 val1_same)
    if(NOT val1_same STREQUAL "NEW")
        message(STATUS "  ✗ BASIC001 should remain NEW after setting same value, got: ${val1_same}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Policy values persist correctly and handle re-setting")
endfunction()

function(test_error_handling)
    message(STATUS "Test 5: Testing error handling")
    
    # Test duplicate registration
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P -c "
            include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
            Policy_Register(NAME DUP_TEST DESCRIPTION \"First\" DEFAULT OLD INTRODUCED_VERSION 1.0)
            Policy_Register(NAME DUP_TEST DESCRIPTION \"Duplicate\" DEFAULT NEW INTRODUCED_VERSION 2.0)
        "
        RESULT_VARIABLE dup_result
        OUTPUT_VARIABLE dup_output
        ERROR_VARIABLE dup_error
    )
    if(dup_result EQUAL 0)
        message(STATUS "  ✗ Duplicate policy registration should have failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Test invalid policy value
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P -c "
            include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
            Policy_Register(NAME INV_TEST DESCRIPTION \"Test\" DEFAULT INVALID INTRODUCED_VERSION 1.0)
        "
        RESULT_VARIABLE inv_result
        OUTPUT_VARIABLE inv_output
        ERROR_VARIABLE inv_error
    )
    if(inv_result EQUAL 0)
        message(STATUS "  ✗ Invalid policy value should have failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Test unregistered policy
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P -c "
            include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
            Policy_Get(NONEXISTENT result)
        "
        RESULT_VARIABLE unreg_result
        OUTPUT_VARIABLE unreg_output
        ERROR_VARIABLE unreg_error
    )
    if(unreg_result EQUAL 0)
        message(STATUS "  ✗ Getting unregistered policy should have failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Error handling working correctly")
endfunction()

function(cleanup_test_environment)
    # No cleanup needed for policy tests
    message(STATUS "Cleaning up policy test environment")
endfunction()

function(run_all_tests)
    message(STATUS "=== Basic Policy Operations Unit Tests ===")
    
    setup_test_environment()
    test_basic_policy_registration()
    test_default_policy_values()
    test_policy_setting()
    test_policy_value_persistence()
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
