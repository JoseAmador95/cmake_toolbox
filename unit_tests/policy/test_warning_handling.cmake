# Test: Warning Message Handling
# Tests warning message escaping, unescaping, and multi-line support

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(ERROR_COUNT 0)

function(setup_test_environment)
    # No file system setup needed for policy tests
    message(STATUS "Setting up warning handling test environment")
endfunction()

function(test_simple_warning)
    message(STATUS "Test 1: Testing simple warning message")
    
    policy_register(NAME WARN001 
                    DESCRIPTION "Policy with simple warning" 
                    DEFAULT OLD 
                    INTRODUCED_VERSION 1.0 
                    WARNING "This is a simple warning message")

    policy_get_fields(POLICY WARN001 PREFIX SIMPLE)
    if(NOT SIMPLE_WARNING STREQUAL "This is a simple warning message")
        message(SEND_ERROR "Simple warning message not preserved correctly: '${SIMPLE_WARNING}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Simple warning message preserved correctly")
endfunction()

function(test_pipe_characters)
    message(STATUS "Test 2: Testing warning with pipe characters")
    
    policy_register(NAME WARN002 
                    DESCRIPTION "Policy with pipe warning" 
                    DEFAULT NEW 
                    INTRODUCED_VERSION 1.1 
                    WARNING "Warning with | single pipe and || double pipes")

    policy_get_fields(POLICY WARN002 PREFIX PIPE)
    if(NOT PIPE_WARNING STREQUAL "Warning with | single pipe and || double pipes")
        message(SEND_ERROR "Pipe characters not preserved correctly: '${PIPE_WARNING}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Pipe characters preserved correctly")
endfunction()

function(test_multiline_warning)
    message(STATUS "Test 3: Testing multi-line warning")
    
    policy_register(NAME WARN003 
                    DESCRIPTION "Policy with multi-line warning" 
                    DEFAULT OLD 
                    INTRODUCED_VERSION 1.2 
                    WARNING "Line 1 of warning
Line 2 of warning  
Line 3 with trailing spaces   
Line 4 with | pipe character")

    policy_get_fields(POLICY WARN003 PREFIX MULTI)
    set(EXPECTED_MULTILINE "Line 1 of warning
Line 2 of warning  
Line 3 with trailing spaces   
Line 4 with | pipe character")

    if(NOT MULTI_WARNING STREQUAL EXPECTED_MULTILINE)
        message(SEND_ERROR "Multi-line warning not preserved correctly")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Multi-line warning preserved correctly")
endfunction()

function(test_empty_warning)
    message(STATUS "Test 4: Testing empty warning")
    
    policy_register(NAME WARN004 
                    DESCRIPTION "Policy with empty warning" 
                    DEFAULT NEW 
                    INTRODUCED_VERSION 1.3 
                    WARNING "")

    policy_get_fields(POLICY WARN004 PREFIX EMPTY)
    if(NOT EMPTY_WARNING STREQUAL "")
        message(SEND_ERROR "Empty warning should be empty string, got: '${EMPTY_WARNING}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Empty warning handled correctly")
endfunction()

function(test_no_warning_parameter)
    message(STATUS "Test 5: Testing no warning parameter")
    
    policy_register(NAME WARN005 
                    DESCRIPTION "Policy without warning parameter" 
                    DEFAULT OLD 
                    INTRODUCED_VERSION 1.4)

    policy_get_fields(POLICY WARN005 PREFIX NONE)
    if(NOT NONE_WARNING STREQUAL "")
        message(SEND_ERROR "Missing warning should default to empty string, got: '${NONE_WARNING}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Missing warning parameter defaults to empty correctly")
endfunction()

function(test_special_characters)
    message(STATUS "Test 6: Testing warning with special characters")
    
    policy_register(NAME WARN006 
                    DESCRIPTION "Policy with special character warning" 
                    DEFAULT NEW 
                    INTRODUCED_VERSION 1.5 
                    WARNING "Warning with \"double quotes\" and basic text")

    policy_get_fields(POLICY WARN006 PREFIX SPECIAL)
    set(EXPECTED_SPECIAL "Warning with \"double quotes\" and basic text")
    if(NOT SPECIAL_WARNING STREQUAL EXPECTED_SPECIAL)
        message(SEND_ERROR "Special characters not preserved correctly")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Special characters preserved correctly")
endfunction()

function(test_warning_display)
    message(STATUS "Test 7: Testing warning display in policy_info")
    
    # Test that policy_info displays warnings without crashing
    policy_info(POLICY WARN002)
    
    # Verify the policy exists and can be accessed
    policy_get(POLICY WARN002 OUTVAR test_value)
    if(test_value STREQUAL "")
        message(SEND_ERROR "Policy WARN002 should be accessible")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Warning display in policy_info works correctly")
endfunction()

function(cleanup_test_environment)
    # No cleanup needed for policy tests
    message(STATUS "Cleaning up warning handling test environment")
endfunction()

function(run_all_tests)
    message(STATUS "=== Warning Message Handling Unit Tests ===")
    
    setup_test_environment()
    test_simple_warning()
    test_pipe_characters()
    test_multiline_warning()
    test_empty_warning()
    test_no_warning_parameter()
    test_special_characters()
    test_warning_display()
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
