# Test: Policy Info Function
# Tests policy_info function output and formatting

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(TEST_NAME "Policy Info Function")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Test 1: Register test policies
message(STATUS "Test 1: Setting up test policies")
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

# Test 2: Test policy_info output format
message(STATUS "Test 2: Testing policy_info output format")
# We can't easily test the exact output format, but we can ensure it doesn't crash
policy_info(POLICY INFO001)
policy_info(POLICY INFO002)

# Test 3: Test policy_info with set value
message(STATUS "Test 3: Testing policy_info with explicitly set value")
policy_set(POLICY INFO001 VALUE NEW)
policy_info(POLICY INFO001)

# Test 4: Verify info function works by checking internal calls don't fail
message(STATUS "Test 4: Verifying policy_info internal operations")
# We'll use policy_get_fields to verify the same data is accessible
policy_get_fields(POLICY INFO001 PREFIX VERIFY)
if(NOT VERIFY_NAME STREQUAL "INFO001")
    message(SEND_ERROR "policy_info should work with same data as policy_get_fields")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: Test policy_info with policy that has empty warning
message(STATUS "Test 5: Testing policy_info with policy without warning")
policy_get_fields(POLICY INFO002 PREFIX VERIFY2)
if(NOT VERIFY2_WARNING STREQUAL "")
    message(SEND_ERROR "INFO002 should have empty warning")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()
# The info function should handle empty warnings gracefully
policy_info(POLICY INFO002)

# Test 6: Error handling - unregistered policy
message(STATUS "Test 6: Testing error handling for unregistered policy")
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
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Summary
if(ERROR_COUNT EQUAL 0)
    message(STATUS "${TEST_NAME}: PASSED (0 errors)")
else()
    message(STATUS "${TEST_NAME}: FAILED (${ERROR_COUNT} errors)")
endif()
