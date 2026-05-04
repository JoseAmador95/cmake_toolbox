# Test: Cppcheck_Configure in strict mode without tool
# Purpose: Verify that STRICT flag causes fatal error when cppcheck unavailable
# Expected: FAIL with fatal error (when cppcheck not installed)
#           PASS (when cppcheck is installed)
# Executable: cmake -P test_configure_strict_fails.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the Cppcheck module
include(Cppcheck)

# Pre-check: Is cppcheck available?
find_package(Cppcheck QUIET)

if(Cppcheck_FOUND)
    # If cppcheck is available, STRICT mode should work fine
    Cppcheck_Configure(STATUS ON STRICT)
    message(STATUS "PASS: STRICT mode - Cppcheck found and configured successfully")
    message(STATUS "  Cppcheck executable: ${Cppcheck_EXECUTABLE}")
else()
    # If cppcheck is NOT available, STRICT mode should fail
    message(STATUS "INFO: Cppcheck not found - testing STRICT mode enforcement...")

    # This should cause a fatal error
    Cppcheck_Configure(STATUS ON STRICT)
    # If we get here, test failed - STRICT mode should have caused fatal error
    message(FATAL_ERROR "FAIL: STRICT mode did not produce fatal error when cppcheck unavailable")
endif()
