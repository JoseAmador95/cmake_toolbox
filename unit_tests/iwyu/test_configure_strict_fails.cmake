# Test: IWYU_Configure in strict mode without tool
# Purpose: Verify that STRICT flag causes fatal error when IWYU unavailable
# Expected: PASS (STRICT mode enforced correctly, with or without IWYU installed)
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
    # Test this by running IWYU_Configure in a subprocess to capture the error
    message(STATUS "INFO: IWYU not found - testing STRICT mode enforcement...")

    # Create a temporary test script that calls IWYU_Configure with STRICT
    set(test_script_file "${CMAKE_CURRENT_BINARY_DIR}/iwyu_strict_test_script.cmake")
    file(
        WRITE "${test_script_file}"
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/../../cmake\")
include(IWYU)
IWYU_Configure(STATUS ON STRICT)
"
    )

    # Execute the script and capture the result
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${test_script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    # In strict mode, IWYU_Configure should fail (exit code != 0) when IWYU is not found
    if(NOT result EQUAL 0)
        message(STATUS "PASS: STRICT mode correctly enforced - IWYU_Configure failed as expected")
        message(STATUS "  Error was: ${error}")
    else()
        message(FATAL_ERROR "FAIL: STRICT mode did not produce fatal error when IWYU unavailable")
    endif()

    # Clean up
    file(REMOVE "${test_script_file}")
endif()
