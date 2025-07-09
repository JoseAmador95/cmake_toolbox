# Test: Basic Policy Operations
# Tests policy_register, policy_set, policy_get functions

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(TEST_NAME "Basic Policy Operations")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Test 1: Register a basic policy
message(STATUS "Test 1: Basic policy registration")
policy_register(NAME BASIC001 
                DESCRIPTION "Basic test policy" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.0)

# Test 2: Register policy with warning
message(STATUS "Test 2: Policy registration with warning")
policy_register(NAME BASIC002 
                DESCRIPTION "Policy with warning" 
                DEFAULT NEW 
                INTRODUCED_VERSION 2.0 
                WARNING "This is a test warning")

# Test 3: Register policy with multi-line warning and pipe characters
message(STATUS "Test 3: Policy registration with complex warning")
policy_register(NAME BASIC003 
                DESCRIPTION "Policy with complex warning" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.5 
                WARNING "Line 1 of warning
Line 2 with | pipe character
Line 3 with multiple | pipes | here")

# Test 4: Get default values
message(STATUS "Test 4: Getting default policy values")
policy_get(POLICY BASIC001 OUTVAR val1)
if(NOT val1 STREQUAL "OLD")
    message(SEND_ERROR "BASIC001 should return OLD, got: ${val1}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

policy_get(POLICY BASIC002 OUTVAR val2)
if(NOT val2 STREQUAL "NEW")
    message(SEND_ERROR "BASIC002 should return NEW, got: ${val2}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: Set policy values
message(STATUS "Test 5: Setting policy values")
policy_set(POLICY BASIC001 VALUE NEW)
policy_set(POLICY BASIC002 VALUE OLD)

# Test 6: Verify set values
message(STATUS "Test 6: Verifying set values")
policy_get(POLICY BASIC001 OUTVAR val1_new)
if(NOT val1_new STREQUAL "NEW")
    message(SEND_ERROR "BASIC001 should return NEW after setting, got: ${val1_new}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

policy_get(POLICY BASIC002 OUTVAR val2_old)
if(NOT val2_old STREQUAL "OLD")
    message(SEND_ERROR "BASIC002 should return OLD after setting, got: ${val2_old}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 7: Error handling - duplicate registration
message(STATUS "Test 7: Testing duplicate registration error handling")
execute_process(
    COMMAND ${CMAKE_COMMAND} -P -c "
        include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
        policy_register(NAME DUP_TEST DESCRIPTION \"First\" DEFAULT OLD INTRODUCED_VERSION 1.0)
        policy_register(NAME DUP_TEST DESCRIPTION \"Duplicate\" DEFAULT NEW INTRODUCED_VERSION 2.0)
    "
    RESULT_VARIABLE dup_result
    OUTPUT_VARIABLE dup_output
    ERROR_VARIABLE dup_error
)
if(dup_result EQUAL 0)
    message(SEND_ERROR "Duplicate policy registration should have failed")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 8: Error handling - invalid policy value
message(STATUS "Test 8: Testing invalid policy value error handling")
execute_process(
    COMMAND ${CMAKE_COMMAND} -P -c "
        include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
        policy_register(NAME INV_TEST DESCRIPTION \"Test\" DEFAULT INVALID INTRODUCED_VERSION 1.0)
    "
    RESULT_VARIABLE inv_result
    OUTPUT_VARIABLE inv_output
    ERROR_VARIABLE inv_error
)
if(inv_result EQUAL 0)
    message(SEND_ERROR "Invalid policy value should have failed")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 9: Error handling - unregistered policy
message(STATUS "Test 9: Testing unregistered policy error handling")
execute_process(
    COMMAND ${CMAKE_COMMAND} -P -c "
        include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
        policy_get(POLICY NONEXISTENT OUTVAR result)
    "
    RESULT_VARIABLE unreg_result
    OUTPUT_VARIABLE unreg_output
    ERROR_VARIABLE unreg_error
)
if(unreg_result EQUAL 0)
    message(SEND_ERROR "Getting unregistered policy should have failed")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Summary
if(ERROR_COUNT EQUAL 0)
    message(STATUS "${TEST_NAME}: PASSED (0 errors)")
else()
    message(STATUS "${TEST_NAME}: FAILED (${ERROR_COUNT} errors)")
endif()
