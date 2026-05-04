# Test: IWYU_Configure in strict mode without tool
# Purpose: Verify that STRICT flag causes fatal error when IWYU unavailable
# Expected: FAIL with fatal error (when IWYU not installed)
#           PASS (when IWYU is installed)
# Executable: cmake -P test_configure_strict_fails.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the IWYU module
include(IWYU)

# Pre-check: Is IWYU available?
find_package(IWYU QUIET)

if(IWYU_FOUND)
    # If IWYU is available, STRICT mode should work fine
    IWYU_Configure(STATUS ON STRICT)
    message(STATUS "PASS: STRICT mode - IWYU found and configured successfully")
    message(STATUS "  IWYU executable: ${IWYU_EXECUTABLE}")
else()
    # If IWYU is NOT available, STRICT mode should fail
    message(STATUS "INFO: IWYU not found - testing STRICT mode enforcement...")

    # This should cause a fatal error
    IWYU_Configure(STATUS ON STRICT)
    # If we get here, test failed - STRICT mode should have caused fatal error
    message(FATAL_ERROR "FAIL: STRICT mode did not produce fatal error when IWYU unavailable")
endif()
