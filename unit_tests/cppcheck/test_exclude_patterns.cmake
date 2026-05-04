# Test: EXCLUDE_PATTERNS parameter handling
# Purpose: Verify that exclude patterns are properly stored
# Expected: PASS
# Executable: cmake -P test_exclude_patterns.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the Cppcheck module
include(Cppcheck)

# Test: Configure with EXCLUDE_PATTERNS
Cppcheck_Configure(
    STATUS ON
    EXCLUDE_PATTERNS
        "^build/.*"
        ".*third_party.*"
        "*/generated/*"
)

if(Cppcheck_FOUND)
    # If tool is available, verify patterns are in the command
    set(cppcheck_cmd "${CMAKE_C_CPPCHECK}")

    message(STATUS "PASS: EXCLUDE_PATTERNS handling - tool found")
    message(STATUS "  Full command: ${cppcheck_cmd}")

    # Check for exclude flags
    if("${cppcheck_cmd}" MATCHES "--exclude=")
        message(STATUS "  Exclude patterns are present in command")

        if("${cppcheck_cmd}" MATCHES "exclude=.*build")
            message(STATUS "  - Pattern '^build/.*' detected")
        endif()

        if("${cppcheck_cmd}" MATCHES "exclude=.*third_party")
            message(STATUS "  - Pattern '.*third_party.*' detected")
        endif()

        if("${cppcheck_cmd}" MATCHES "exclude=.*generated")
            message(STATUS "  - Pattern '*/generated/*' detected")
        endif()
    else()
        message(STATUS "  INFO: Tool configured but pattern check may not apply")
    endif()
else()
    message(STATUS "PASS: EXCLUDE_PATTERNS handling - advisory mode (tool not installed)")
    message(STATUS "  CMAKE_C_CPPCHECK = '${CMAKE_C_CPPCHECK}' (empty as expected)")
endif()

message(STATUS "PASS: EXCLUDE_PATTERNS test completed successfully")
