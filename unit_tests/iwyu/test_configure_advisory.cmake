# Test: IWYU_Configure in advisory mode (default)
# Purpose: Verify that IWYU_Configure(STATUS ON) succeeds without the tool
# Expected: PASS (even without IWYU installed)
# Executable: cmake -P test_configure_advisory.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the IWYU module
include(IWYU)

# Test: Call IWYU_Configure in advisory mode (no STRICT flag)
# This should succeed even if IWYU is not installed
IWYU_Configure(STATUS ON)

# Verify that configuration was applied (or gracefully skipped)
if(IWYU_FOUND)
    if(CMAKE_CXX_INCLUDE_WHAT_YOU_USE)
        message(STATUS "PASS: Advisory mode - IWYU_Configure succeeded with tool")
        message(STATUS "  CMAKE_CXX_INCLUDE_WHAT_YOU_USE = ${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}")
    else()
        message(FATAL_ERROR "FAIL: IWYU found but CMAKE_CXX_INCLUDE_WHAT_YOU_USE is empty")
    endif()
else()
    # IWYU not found - advisory mode should still succeed
    # Variables should be empty as tool not available
    message(
        STATUS
        "PASS: Advisory mode - IWYU_Configure succeeded without tool (tool not installed)"
    )
    message(
        STATUS
        "  CMAKE_CXX_INCLUDE_WHAT_YOU_USE = '${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}' (empty as expected)"
    )
endif()

message(STATUS "PASS: IWYU_Configure advisory mode test completed successfully")
