# Test: Policy Version Function
# Tests policy_version function with various version ranges

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(TEST_NAME "Policy Version Function")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Register test policies for version testing
policy_register(NAME VER001 DESCRIPTION "Use new behavior for XYZ" DEFAULT OLD INTRODUCED_VERSION 1.0)
policy_register(NAME VER002 DESCRIPTION "Enable advanced optimization" DEFAULT OLD INTRODUCED_VERSION 2.0)
policy_register(NAME VER003 DESCRIPTION "New parser syntax" DEFAULT OLD INTRODUCED_VERSION 3.1)
policy_register(NAME VER004 DESCRIPTION "Future feature" DEFAULT OLD INTRODUCED_VERSION 5.0)

message(STATUS "=== Test 1: Set policies for API v2.5 (policy_version MINIMUM 2.5) ===")
policy_version(MINIMUM 2.5)

policy_get(POLICY VER001 OUTVAR v1)
policy_get(POLICY VER002 OUTVAR v2)
policy_get(POLICY VER003 OUTVAR v3)
policy_get(POLICY VER004 OUTVAR v4)
message(STATUS "VER001: ${v1}")
message(STATUS "VER002: ${v2}")
message(STATUS "VER003: ${v3}")
message(STATUS "VER004: ${v4}")

if(NOT v1 STREQUAL "NEW")
    message(SEND_ERROR "policy_get(VER001) returned ${v1} instead of NEW")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v2 STREQUAL "NEW")
    message(SEND_ERROR "policy_get(VER002) returned ${v2} instead of NEW")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v3 STREQUAL "OLD")
    message(SEND_ERROR "policy_get(VER003) returned ${v3} instead of OLD (not introduced yet)")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v4 STREQUAL "OLD")
    message(SEND_ERROR "policy_get(VER004) returned ${v4} instead of OLD (future version)")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

message(STATUS "=== Test 2: Set policies for API v3.2 (policy_version MINIMUM 3.2) ===")
policy_version(MINIMUM 3.2)

policy_get(POLICY VER001 OUTVAR v1)
policy_get(POLICY VER002 OUTVAR v2)
policy_get(POLICY VER003 OUTVAR v3)
policy_get(POLICY VER004 OUTVAR v4)
message(STATUS "VER001: ${v1}")
message(STATUS "VER002: ${v2}")
message(STATUS "VER003: ${v3}")
message(STATUS "VER004: ${v4}")

if(NOT v1 STREQUAL "NEW")
    message(SEND_ERROR "policy_get(VER001) returned ${v1} instead of NEW")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v2 STREQUAL "NEW")
    message(SEND_ERROR "policy_get(VER002) returned ${v2} instead of NEW")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v3 STREQUAL "NEW")
    message(SEND_ERROR "policy_get(VER003) returned ${v3} instead of NEW")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v4 STREQUAL "OLD")
    message(SEND_ERROR "policy_get(VER004) returned ${v4} instead of OLD (future version)")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

message(STATUS "=== Test 3: Test with MAXIMUM (policy_version MINIMUM 1.0 MAXIMUM 2.5) ===")
policy_version(MINIMUM 1.0 MAXIMUM 2.5)

policy_get(POLICY VER001 OUTVAR v1)
policy_get(POLICY VER002 OUTVAR v2)
policy_get(POLICY VER003 OUTVAR v3)
policy_get(POLICY VER004 OUTVAR v4)
message(STATUS "VER001: ${v1}")
message(STATUS "VER002: ${v2}")
message(STATUS "VER003: ${v3}")
message(STATUS "VER004: ${v4}")

if(NOT v1 STREQUAL "NEW")
    message(SEND_ERROR "policy_get(VER001) returned ${v1} instead of NEW (within range)")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v2 STREQUAL "NEW")
    message(SEND_ERROR "policy_get(VER002) returned ${v2} instead of NEW (within range)")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v3 STREQUAL "OLD")
    message(SEND_ERROR "policy_get(VER003) returned ${v3} instead of OLD (outside range)")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(NOT v4 STREQUAL "OLD")
    message(SEND_ERROR "policy_get(VER004) returned ${v4} instead of OLD (outside range)")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test completion message
if(ERROR_COUNT EQUAL 0)
    message(STATUS "${TEST_NAME}: PASSED (0 errors)")
else()
    message(STATUS "${TEST_NAME}: FAILED (${ERROR_COUNT} errors)")
endif()
