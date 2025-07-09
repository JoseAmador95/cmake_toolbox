# Test: Policy Get Fields Function
# Tests policy_get_fields function with various scenarios

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(TEST_NAME "Policy Get Fields")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Test 1: Register policies for testing
message(STATUS "Test 1: Setting up test policies")
policy_register(NAME FIELDS001 
                DESCRIPTION "Policy for fields testing" 
                DEFAULT OLD 
                INTRODUCED_VERSION 1.2.3 
                WARNING "Test warning with | pipe")

policy_register(NAME FIELDS002 
                DESCRIPTION "Policy without warning" 
                DEFAULT NEW 
                INTRODUCED_VERSION 2.0.0)

# Test 2: Get fields for policy with warning (default state)
message(STATUS "Test 2: Getting fields for policy with warning (default state)")
policy_get_fields(POLICY FIELDS001 PREFIX TEST1)

# Verify all fields
if(NOT TEST1_NAME STREQUAL "FIELDS001")
    message(SEND_ERROR "TEST1_NAME should be 'FIELDS001', got: '${TEST1_NAME}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT TEST1_DESCRIPTION STREQUAL "Policy for fields testing")
    message(SEND_ERROR "TEST1_DESCRIPTION mismatch, got: '${TEST1_DESCRIPTION}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT TEST1_DEFAULT STREQUAL "OLD")
    message(SEND_ERROR "TEST1_DEFAULT should be 'OLD', got: '${TEST1_DEFAULT}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT TEST1_INTRODUCED_VERSION STREQUAL "1.2.3")
    message(SEND_ERROR "TEST1_INTRODUCED_VERSION should be '1.2.3', got: '${TEST1_INTRODUCED_VERSION}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT TEST1_WARNING STREQUAL "Test warning with | pipe")
    message(SEND_ERROR "TEST1_WARNING should contain pipe character, got: '${TEST1_WARNING}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT TEST1_CURRENT_VALUE STREQUAL "OLD")
    message(SEND_ERROR "TEST1_CURRENT_VALUE should be 'OLD' (default), got: '${TEST1_CURRENT_VALUE}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT TEST1_IS_DEFAULT)
    message(SEND_ERROR "TEST1_IS_DEFAULT should be TRUE, got: '${TEST1_IS_DEFAULT}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 3: Set policy and verify IS_DEFAULT changes
message(STATUS "Test 3: Setting policy and verifying IS_DEFAULT changes")
policy_set(POLICY FIELDS001 VALUE NEW)
policy_get_fields(POLICY FIELDS001 PREFIX TEST1_SET)

if(NOT TEST1_SET_CURRENT_VALUE STREQUAL "NEW")
    message(SEND_ERROR "TEST1_SET_CURRENT_VALUE should be 'NEW', got: '${TEST1_SET_CURRENT_VALUE}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(TEST1_SET_IS_DEFAULT)
    message(SEND_ERROR "TEST1_SET_IS_DEFAULT should be FALSE, got: '${TEST1_SET_IS_DEFAULT}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 4: Get fields for policy without warning
message(STATUS "Test 4: Getting fields for policy without warning")
policy_get_fields(POLICY FIELDS002 PREFIX TEST2)

if(NOT TEST2_WARNING STREQUAL "")
    message(SEND_ERROR "TEST2_WARNING should be empty, got: '${TEST2_WARNING}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT TEST2_CURRENT_VALUE STREQUAL "NEW")
    message(SEND_ERROR "TEST2_CURRENT_VALUE should be 'NEW' (default), got: '${TEST2_CURRENT_VALUE}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT TEST2_IS_DEFAULT)
    message(SEND_ERROR "TEST2_IS_DEFAULT should be TRUE, got: '${TEST2_IS_DEFAULT}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: Multiple prefixes don't interfere
message(STATUS "Test 5: Testing multiple prefixes don't interfere")
policy_get_fields(POLICY FIELDS001 PREFIX PREFIX_A)
policy_get_fields(POLICY FIELDS002 PREFIX PREFIX_B)

if(NOT PREFIX_A_NAME STREQUAL "FIELDS001")
    message(SEND_ERROR "PREFIX_A_NAME should be 'FIELDS001', got: '${PREFIX_A_NAME}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT PREFIX_B_NAME STREQUAL "FIELDS002")
    message(SEND_ERROR "PREFIX_B_NAME should be 'FIELDS002', got: '${PREFIX_B_NAME}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 6: Error handling - unregistered policy
message(STATUS "Test 6: Testing error handling for unregistered policy")
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
    message(SEND_ERROR "Getting fields for unregistered policy should have failed")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Summary
if(ERROR_COUNT EQUAL 0)
    message(STATUS "${TEST_NAME}: PASSED (0 errors)")
else()
    message(STATUS "${TEST_NAME}: FAILED (${ERROR_COUNT} errors)")
endif()
