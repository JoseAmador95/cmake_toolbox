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

    set(test_failed FALSE)

    if(NOT ("${cppcheck_cmd}" MATCHES "--exclude="))
        message(STATUS "FAIL: No --exclude= flags in command: ${cppcheck_cmd}")
        set(test_failed TRUE)
    else()
        if(NOT ("${cppcheck_cmd}" MATCHES "exclude=.*build"))
            message(STATUS "FAIL: Pattern '^build/.*' not found in command: ${cppcheck_cmd}")
            set(test_failed TRUE)
        else()
            message(STATUS "PASS: Pattern '^build/.*' detected")
        endif()

        if(NOT ("${cppcheck_cmd}" MATCHES "exclude=.*third_party"))
            message(STATUS "FAIL: Pattern '.*third_party.*' not found in command: ${cppcheck_cmd}")
            set(test_failed TRUE)
        else()
            message(STATUS "PASS: Pattern '.*third_party.*' detected")
        endif()

        if(NOT ("${cppcheck_cmd}" MATCHES "exclude=.*generated"))
            message(STATUS "FAIL: Pattern '*/generated/*' not found in command: ${cppcheck_cmd}")
            set(test_failed TRUE)
        else()
            message(STATUS "PASS: Pattern '*/generated/*' detected")
        endif()
    endif()

    if(test_failed)
        message(FATAL_ERROR "FAIL: EXCLUDE_PATTERNS test failed")
    endif()
else()
    message(STATUS "PASS: EXCLUDE_PATTERNS handling - advisory mode (tool not installed)")
    message(STATUS "  CMAKE_C_CPPCHECK = '${CMAKE_C_CPPCHECK}' (empty as expected)")
endif()

message(STATUS "PASS: EXCLUDE_PATTERNS test completed successfully")
