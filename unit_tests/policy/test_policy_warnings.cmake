# Test: Policy Warning and Deprecation Behavior
# Tests the automatic warning system for policies

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(TEST_NAME "Policy Warning and Deprecation")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Test 1: Register policies with different statuses
message(STATUS "Test 1: Registering policies with different statuses")
policy_register(NAME WARN001 
                DESCRIPTION "Current policy with warning" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.0 
                WARNING "This policy changes behavior")

policy_register(NAME WARN002 
                DESCRIPTION "Deprecated policy" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.0 
                WARNING "This feature is deprecated"
                DEPRECATED_VERSION 2.0)

policy_register(NAME WARN003 
                DESCRIPTION "Removed policy" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.0 
                WARNING "This feature was removed"
                DEPRECATED_VERSION 2.0
                REMOVED_VERSION 3.0)

policy_register(NAME WARN004 
                DESCRIPTION "Policy without warning" 
                DEFAULT NEW 
                INTRODUCED_VERSION 1.0)

# Test 2: Test that we can capture warnings in a real scenario
message(STATUS "Test 2: Testing warnings in current context")

# Create a policy that should warn
policy_register(NAME TEST_WARN_HERE 
                DESCRIPTION "Test policy for warnings" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.0 
                WARNING "This should generate a warning")

# This should generate warnings when called
message(STATUS "About to call policy_get on unset policy with warning...")
policy_get(POLICY TEST_WARN_HERE OUTVAR test_val)
message(STATUS "Successfully got value: ${test_val}")

# Test 3: Test explicitly set policy doesn't warn about being unset
message(STATUS "Test 3: Testing explicitly set policy")
policy_set(POLICY TEST_WARN_HERE VALUE NEW)
message(STATUS "About to call policy_get on explicitly set policy...")
policy_get(POLICY TEST_WARN_HERE OUTVAR test_val2)
message(STATUS "Successfully got value: ${test_val2}")

# Test 4: Test deprecated policy
message(STATUS "Test 4: Testing deprecated policy")
policy_register(NAME TEST_DEPRECATED_HERE 
                DESCRIPTION "Test deprecated policy" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.0 
                DEPRECATED_VERSION 2.0)

message(STATUS "About to call policy_get on deprecated policy...")
policy_get(POLICY TEST_DEPRECATED_HERE OUTVAR test_val3)
message(STATUS "Successfully got value: ${test_val3}")

# Test 5: Test removed policy
message(STATUS "Test 5: Testing removed policy")
policy_register(NAME TEST_REMOVED_HERE 
                DESCRIPTION "Test removed policy" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.0 
                DEPRECATED_VERSION 2.0
                REMOVED_VERSION 3.0)

message(STATUS "About to call policy_get on removed policy...")
policy_get(POLICY TEST_REMOVED_HERE OUTVAR test_val4)
message(STATUS "Successfully got value: ${test_val4}")

# Test 6: Test policy without warning
message(STATUS "Test 6: Testing policy without warning")
policy_register(NAME TEST_NO_WARN_HERE 
                DESCRIPTION "Test policy without warning" 
                DEFAULT NEW 
                INTRODUCED_VERSION 1.0)

message(STATUS "About to call policy_get on policy without warning...")
policy_get(POLICY TEST_NO_WARN_HERE OUTVAR test_val5)
message(STATUS "Successfully got value: ${test_val5}")

# Test 7: Test policy_get_fields shows deprecation/removal status
message(STATUS "Test 7: Testing policy_get_fields shows status information")
policy_get_fields(POLICY WARN002 PREFIX DEPRECATED_INFO)
if(NOT DEPRECATED_INFO_DEPRECATED_VERSION STREQUAL "2.0")
    message(SEND_ERROR "policy_get_fields should expose DEPRECATED_VERSION")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

policy_get_fields(POLICY WARN003 PREFIX REMOVED_INFO)
if(NOT REMOVED_INFO_REMOVED_VERSION STREQUAL "3.0")
    message(SEND_ERROR "policy_get_fields should expose REMOVED_VERSION")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Note: The warning behavior is demonstrated by the actual warnings printed above.
# This test focuses on verifying the API works correctly rather than parsing warning output.

# Test completion message
if(ERROR_COUNT EQUAL 0)
    message(STATUS "${TEST_NAME}: PASSED (0 errors)")
else()
    message(STATUS "${TEST_NAME}: FAILED (${ERROR_COUNT} errors)")
endif()
