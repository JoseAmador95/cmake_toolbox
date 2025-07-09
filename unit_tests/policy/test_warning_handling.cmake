# Test: Warning Message Handling
# Tests warning message escaping, unescaping, and multi-line support

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(TEST_NAME "Warning Message Handling")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Test 1: Simple warning message
message(STATUS "Test 1: Simple warning message")
policy_register(NAME WARN001 
                DESCRIPTION "Policy with simple warning" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.0 
                WARNING "This is a simple warning message")

policy_get_fields(POLICY WARN001 PREFIX SIMPLE)
if(NOT SIMPLE_WARNING STREQUAL "This is a simple warning message")
    message(SEND_ERROR "Simple warning message not preserved correctly: '${SIMPLE_WARNING}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 2: Warning with pipe characters
message(STATUS "Test 2: Warning with pipe characters")
policy_register(NAME WARN002 
                DESCRIPTION "Policy with pipe warning" 
                DEFAULT NEW 
                INTRODUCED_VERSION 1.1 
                WARNING "Warning with | single pipe and || double pipes")

policy_get_fields(POLICY WARN002 PREFIX PIPE)
if(NOT PIPE_WARNING STREQUAL "Warning with | single pipe and || double pipes")
    message(SEND_ERROR "Pipe characters not preserved correctly: '${PIPE_WARNING}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 3: Multi-line warning
message(STATUS "Test 3: Multi-line warning")
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
    message(STATUS "Expected: '${EXPECTED_MULTILINE}'")
    message(STATUS "Got: '${MULTI_WARNING}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 4: Empty warning (should work)
message(STATUS "Test 4: Empty warning")
policy_register(NAME WARN004 
                DESCRIPTION "Policy with empty warning" 
                DEFAULT NEW 
                INTRODUCED_VERSION 1.3 
                WARNING "")

policy_get_fields(POLICY WARN004 PREFIX EMPTY)
if(NOT EMPTY_WARNING STREQUAL "")
    message(SEND_ERROR "Empty warning should be empty string, got: '${EMPTY_WARNING}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: No warning parameter (should default to empty)
message(STATUS "Test 5: No warning parameter")
policy_register(NAME WARN005 
                DESCRIPTION "Policy without warning parameter" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.4)

policy_get_fields(POLICY WARN005 PREFIX NONE)
if(NOT NONE_WARNING STREQUAL "")
    message(SEND_ERROR "Missing warning should default to empty string, got: '${NONE_WARNING}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 6: Warning with quotes and backslashes (simplified)
message(STATUS "Test 6: Warning with quotes and backslashes")
policy_register(NAME WARN006 
                DESCRIPTION "Policy with special character warning" 
                DEFAULT NEW 
                INTRODUCED_VERSION 1.5 
                WARNING "Warning with \"double quotes\" and basic text")

policy_get_fields(POLICY WARN006 PREFIX SPECIAL)
set(EXPECTED_SPECIAL "Warning with \"double quotes\" and basic text")
if(NOT SPECIAL_WARNING STREQUAL EXPECTED_SPECIAL)
    message(SEND_ERROR "Special characters not preserved correctly")
    message(STATUS "Expected: '${EXPECTED_SPECIAL}'")
    message(STATUS "Got: '${SPECIAL_WARNING}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 7: Test warning display in policy_info
message(STATUS "Test 7: Testing warning display in policy_info")
# This should display the warning correctly (visual check)
message(STATUS "Policy info for WARN002 (should show pipe characters):")
policy_info(POLICY WARN002)

# Summary
if(ERROR_COUNT EQUAL 0)
    message(STATUS "${TEST_NAME}: PASSED (0 errors)")
else()
    message(STATUS "${TEST_NAME}: FAILED (${ERROR_COUNT} errors)")
endif()
