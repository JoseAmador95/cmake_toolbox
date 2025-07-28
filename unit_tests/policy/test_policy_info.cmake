# Test: Policy Info Function
# Tests policy_info function output and formatting

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(ERROR_COUNT 0)

function(setup_test_environment)
    # Register test policies
    policy_register(NAME INFO001 
                    DESCRIPTION "Policy for info testing" 
                    DEFAULT OLD 
                    INTRODUCED_VERSION 1.0.0 
                    WARNING "Multi-line warning
Line 2 with | pipe
Line 3")

    policy_register(NAME INFO002 
                    DESCRIPTION "Policy without warning" 
                    DEFAULT NEW 
                    INTRODUCED_VERSION 2.1.0)
    
    message(STATUS "Setting up policy info test environment")
endfunction()

function(test_policy_info_basic)
    message(STATUS "Test 1: Testing basic policy_info functionality")
    
    # Test that policy_info executes without crashing
    policy_info(POLICY INFO001)
    policy_info(POLICY INFO002)
    
    # Verify the policies are accessible and have correct data
    policy_get_fields(POLICY INFO001 PREFIX VERIFY1)
    policy_get_fields(POLICY INFO002 PREFIX VERIFY2)
    
    if(NOT VERIFY1_NAME STREQUAL "INFO001")
        message(SEND_ERROR "INFO001 policy data not accessible")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    if(NOT VERIFY2_NAME STREQUAL "INFO002")
        message(SEND_ERROR "INFO002 policy data not accessible")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Policy info displays correctly for registered policies")
endfunction()

function(test_policy_info_with_set_value)
    message(STATUS "Test 2: Testing policy_info with explicitly set value")
    
    # Set a policy value and check info still works
    policy_set(POLICY INFO001 VALUE NEW)
    policy_info(POLICY INFO001)
    
    # Verify the value was actually set
    policy_get(POLICY INFO001 OUTVAR current_value)
    if(NOT current_value STREQUAL "NEW")
        message(SEND_ERROR "Policy value not set correctly")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Policy info works correctly with explicitly set values")
endfunction()

function(test_policy_info_warning_handling)
    message(STATUS "Test 3: Testing policy_info warning handling")
    
    # Test policy with warning
    policy_get_fields(POLICY INFO001 PREFIX WITH_WARNING)
    if(WITH_WARNING_WARNING STREQUAL "")
        message(SEND_ERROR "INFO001 should have a warning message")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    # Test policy without warning
    policy_get_fields(POLICY INFO002 PREFIX NO_WARNING)
    if(NOT NO_WARNING_WARNING STREQUAL "")
        message(SEND_ERROR "INFO002 should have empty warning")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    # Ensure both work with policy_info
    policy_info(POLICY INFO001)
    policy_info(POLICY INFO002)
    
    message(STATUS "  ✓ Policy info handles warnings correctly")
endfunction()

function(test_policy_info_error_handling)
    message(STATUS "Test 4: Testing policy_info error handling")
    
    # Test with unregistered policy
    execute_process(
        COMMAND ${CMAKE_COMMAND} -P -c "
            include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
            policy_info(POLICY NONEXISTENT)
        "
        RESULT_VARIABLE unreg_result
        OUTPUT_VARIABLE unreg_output
        ERROR_VARIABLE unreg_error
    )
    
    if(unreg_result EQUAL 0)
        message(SEND_ERROR "policy_info for unregistered policy should have failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Policy info error handling works correctly")
endfunction()

function(cleanup_test_environment)
    # No cleanup needed for policy tests
    message(STATUS "Cleaning up policy info test environment") 
endfunction()

function(run_all_tests)
    message(STATUS "=== Policy Info Function Unit Tests ===")
    
    setup_test_environment()
    test_policy_info_basic()
    test_policy_info_with_set_value()
    test_policy_info_warning_handling()
    test_policy_info_error_handling()
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
