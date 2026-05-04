# Test: Cppcheck_Configure in advisory mode (default)
# Purpose: Verify that Cppcheck_Configure(STATUS ON) succeeds without the tool
# Expected: PASS (even without cppcheck installed)
# Executable: cmake -P test_configure_advisory.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the Cppcheck module
include(Cppcheck)

# Test: Call Cppcheck_Configure in advisory mode (no STRICT flag)
# This should succeed even if cppcheck is not installed
Cppcheck_Configure(STATUS ON)

# Verify that configuration was applied (or gracefully skipped)
if(Cppcheck_FOUND)
    if(CMAKE_C_CPPCHECK)
        message(STATUS "PASS: Advisory mode - Cppcheck_Configure succeeded with tool")
        message(STATUS "  CMAKE_C_CPPCHECK = ${CMAKE_C_CPPCHECK}")
    else()
        message(FATAL_ERROR "FAIL: Cppcheck found but CMAKE_C_CPPCHECK is empty")
    endif()
else()
    # Cppcheck not found - advisory mode should still succeed
    # Variables should be empty as tool not available
    message(
        STATUS
        "PASS: Advisory mode - Cppcheck_Configure succeeded without tool (tool not installed)"
    )
    message(STATUS "  CMAKE_C_CPPCHECK = '${CMAKE_C_CPPCHECK}' (empty as expected)")
    message(STATUS "  CMAKE_CXX_CPPCHECK = '${CMAKE_CXX_CPPCHECK}' (empty as expected)")
endif()

message(STATUS "PASS: Cppcheck_Configure advisory mode test completed successfully")
