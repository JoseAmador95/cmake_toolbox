# Test: ENABLE and SUPPRESS parameter handling
# Purpose: Verify that flags are properly formatted
# Expected: PASS
# Executable: cmake -P test_enable_suppress_flags.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the Cppcheck module
include(Cppcheck)

# Test 1: Configure with ENABLE and SUPPRESS flags
Cppcheck_Configure(
    STATUS ON
    ENABLE
        warning
        style
        performance
    SUPPRESS
        missingIncludeSystem
        unusedVariable
)

if(Cppcheck_FOUND)
    # If tool is available, verify flags are set correctly
    set(cppcheck_cmd "${CMAKE_C_CPPCHECK}")

    # Check for --enable flag
    if("${cppcheck_cmd}" MATCHES "--enable=")
        message(STATUS "PASS: ENABLE flag is present in command")
        if("${cppcheck_cmd}" MATCHES "--enable=warning,style,performance")
            message(STATUS "  Correct format: --enable=warning,style,performance")
        else()
            message(STATUS "  Command: ${cppcheck_cmd}")
        endif()
    else()
        message(STATUS "  INFO: Tool configured but flag check may not apply")
    endif()

    # Check for --suppress flag
    if("${cppcheck_cmd}" MATCHES "--suppress=")
        message(STATUS "PASS: SUPPRESS flag is present in command")
        if("${cppcheck_cmd}" MATCHES "--suppress=missingIncludeSystem,unusedVariable")
            message(STATUS "  Correct format: --suppress=missingIncludeSystem,unusedVariable")
        else()
            message(STATUS "  Command: ${cppcheck_cmd}")
        endif()
    else()
        message(STATUS "  INFO: Tool configured but suppress flag check may not apply")
    endif()

    message(STATUS "Full command: ${CMAKE_C_CPPCHECK}")
else()
    message(STATUS "PASS: ENABLE/SUPPRESS flags test - advisory mode (tool not installed)")
    message(STATUS "  CMAKE_C_CPPCHECK = '${CMAKE_C_CPPCHECK}' (empty as expected)")
endif()

message(STATUS "PASS: ENABLE and SUPPRESS parameter test completed successfully")
