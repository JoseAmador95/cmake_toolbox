# Test: Cppcheck_Configure in strict mode without tool
# Purpose: Verify that STRICT flag causes fatal error when cppcheck unavailable
# Expected: PASS (STRICT mode enforced correctly, with or without cppcheck installed)
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
    # Test this by running Cppcheck_Configure in a subprocess to capture the error
    message(STATUS "INFO: Cppcheck not found - testing STRICT mode enforcement...")

    # Create a temporary test script that calls Cppcheck_Configure with STRICT
    set(test_script_file "${CMAKE_CURRENT_BINARY_DIR}/cppcheck_strict_test_script.cmake")
    file(
        WRITE "${test_script_file}"
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/../../cmake\")
include(Cppcheck)
Cppcheck_Configure(STATUS ON STRICT)
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

    # In strict mode, Cppcheck_Configure should fail (exit code != 0) when cppcheck is not found
    if(NOT result EQUAL 0)
        message(
            STATUS
            "PASS: STRICT mode correctly enforced - Cppcheck_Configure failed as expected"
        )
        message(STATUS "  Error was: ${error}")
    else()
        message(
            FATAL_ERROR
            "FAIL: STRICT mode did not produce fatal error when cppcheck unavailable"
        )
    endif()

    # Clean up
    file(REMOVE "${test_script_file}")
endif()
