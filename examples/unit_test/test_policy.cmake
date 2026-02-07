# === Usage Example ===

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

Policy_Register(NAME MY0001 DESCRIPTION "Use new behavior for XYZ" DEFAULT OLD INTRODUCED_VERSION 1.0 WARNING "This policy changes behavior significantly. Please test thoroughly.")
Policy_Register(NAME MY0002 DESCRIPTION "Enable advanced optimization" DEFAULT OLD INTRODUCED_VERSION 2.0 WARNING "May cause compilation issues|with older compilers.")
Policy_Register(NAME MY0003 DESCRIPTION "New parser syntax" DEFAULT OLD INTRODUCED_VERSION 3.1)

message(STATUS "=== Set policies for API v2.5 (policy_version MINIMUM 2.5) ===")
Policy_Version(MINIMUM 2.5)

Policy_Get(MY0001 v1)
Policy_Get(MY0002 v2)
Policy_Get(MY0003 v3)
message(STATUS "MY0001: ${v1}")
message(STATUS "MY0002: ${v2}")
message(STATUS "MY0003: ${v3}")

if(NOT v1 STREQUAL NEW)
    message(SEND_ERROR "Policy_Get(MY0001) returned OLD instead of NEW")
endif()

if(NOT v2 STREQUAL NEW)
    message(SEND_ERROR "Policy_Get(MY0002) returned OLD instead of NEW")
endif()

if(NOT v3 STREQUAL OLD)
    message(SEND_ERROR "Policy_Get(MY0003) returned NEW instead of OLD")
endif()

message(STATUS "=== Now try API v3.2 (policy_version MINIMUM 3.2) ===")
Policy_Version(MINIMUM 3.2)

Policy_Get(MY0001 v1)
Policy_Get(MY0002 v2)
Policy_Get(MY0003 v3)
message(STATUS "MY0001: ${v1}")
message(STATUS "MY0002: ${v2}")
message(STATUS "MY0003: ${v3}")

if(NOT v1 STREQUAL NEW)
    message(SEND_ERROR "Policy_Get(MY0001) returned OLD instead of NEW")
endif()

if(NOT v2 STREQUAL NEW)
    message(SEND_ERROR "Policy_Get(MY0002) returned OLD instead of NEW")
endif()

if(NOT v3 STREQUAL NEW)
    message(SEND_ERROR "Policy_Get(MY0003) returned OLD instead of NEW")
endif()

message(STATUS "=== Try with explicit MAXIMUM (Policy_Version MINIMUM 1.0 MAXIMUM 2.5): policies in range set to NEW ===")
Policy_Version(MINIMUM 1.0 MAXIMUM 2.5)

Policy_Get(MY0001 v1)
Policy_Get(MY0002 v2)
Policy_Get(MY0003 v3)
message(STATUS "MY0001: ${v1}")
message(STATUS "MY0002: ${v2}")
message(STATUS "MY0003: ${v3}")

if(NOT v1 STREQUAL NEW)
    message(SEND_ERROR "Policy_Get(MY0001) returned OLD instead of NEW (1.0 is in range [1.0, 2.5])")
endif()

if(NOT v2 STREQUAL NEW)
    message(SEND_ERROR "Policy_Get(MY0002) returned OLD instead of NEW (2.0 is in range [1.0, 2.5])")
endif()

if(NOT v3 STREQUAL OLD)
    message(SEND_ERROR "Policy_Get(MY0003) returned NEW instead of OLD (3.1 is outside range [1.0, 2.5])")
endif()
