# === Usage Example ===

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

policy_register(NAME MY0001 DESCRIPTION "Use new behavior for XYZ" DEFAULT OLD INTRODUCED_VERSION 1.0 WARNING "This policy changes behavior significantly. Please test thoroughly.")
policy_register(NAME MY0002 DESCRIPTION "Enable advanced optimization" DEFAULT OLD INTRODUCED_VERSION 2.0 WARNING "May cause compilation issues|with older compilers.")
policy_register(NAME MY0003 DESCRIPTION "New parser syntax" DEFAULT OLD INTRODUCED_VERSION 3.1)

message(STATUS "=== Set policies for API v2.5 (policy_version MINIMUM 2.5) ===")
policy_version(MINIMUM 2.5)

policy_get(POLICY MY0001 OUTVAR v1)
policy_get(POLICY MY0002 OUTVAR v2)
policy_get(POLICY MY0003 OUTVAR v3)
message(STATUS "MY0001: ${v1}")
message(STATUS "MY0002: ${v2}")
message(STATUS "MY0003: ${v3}")

if(NOT v1 STREQUAL NEW)
    message(SEND_ERROR "policy_get(MY0001) returned OLD instead of NEW")
endif()

if(NOT v2 STREQUAL NEW)
    message(SEND_ERROR "policy_get(MY0002) returned OLD instead of NEW")
endif()

if(NOT v3 STREQUAL OLD)
    message(SEND_ERROR "policy_get(MY0003) returned NEW instead of OLD")
endif()

message(STATUS "=== Now try API v3.2 (policy_version MINIMUM 3.2) ===")
policy_version(MINIMUM 3.2)

policy_get(POLICY MY0001 OUTVAR v1)
policy_get(POLICY MY0002 OUTVAR v2)
policy_get(POLICY MY0003 OUTVAR v3)
message(STATUS "MY0001: ${v1}")
message(STATUS "MY0002: ${v2}")
message(STATUS "MY0003: ${v3}")

if(NOT v1 STREQUAL NEW)
    message(SEND_ERROR "policy_get(MY0001) returned OLD instead of NEW")
endif()

if(NOT v2 STREQUAL NEW)
    message(SEND_ERROR "policy_get(MY0002) returned OLD instead of NEW")
endif()

if(NOT v3 STREQUAL NEW)
    message(SEND_ERROR "policy_get(MY0003) returned OLD instead of NEW")
endif()

message(STATUS "=== Try with explicit MAXIMUM (policy_version MINIMUM 4.0 MAXIMUM 3.5): all policies OLD ===")
policy_version(MINIMUM 4.0 MAXIMUM 3.5)

policy_get(POLICY MY0001 OUTVAR v1)
policy_get(POLICY MY0002 OUTVAR v2)
policy_get(POLICY MY0003 OUTVAR v3)
message(STATUS "MY0001: ${v1}")
message(STATUS "MY0002: ${v2}")
message(STATUS "MY0003: ${v3}")

if(NOT v1 STREQUAL OLD)
    message(SEND_ERROR "policy_get(MY0001) returned NEW instead of OLD")
endif()

if(NOT v2 STREQUAL OLD)
    message(SEND_ERROR "policy_get(MY0002) returned NEW instead of OLD")
endif()

if(NOT v3 STREQUAL OLD)
    message(SEND_ERROR "policy_get(MY0003) returned NEW instead of OLD")
endif()
