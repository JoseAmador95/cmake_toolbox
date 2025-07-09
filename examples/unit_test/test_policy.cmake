# === Usage Example ===

policy_register(MY0001 "Use new behavior for XYZ" OLD 1.0)
policy_register(MY0002 "Enable advanced optimization" OLD 2.0)
policy_register(MY0003 "New parser syntax" OLD 3.1)

message(STATUS "=== Set policies for API v2.5 (policy_version MINIMUM 2.5) ===")
policy_version(MINIMUM 2.5)

policy_get(MY0001 v1)
policy_get(MY0002 v2)
policy_get(MY0003 v3)
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

policy_get(MY0001 v1)
policy_get(MY0002 v2)
policy_get(MY0003 v3)
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

policy_get(MY0001 v1)
policy_get(MY0002 v2)
policy_get(MY0003 v3)
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
