# Test: ENABLE and SUPPRESS parameter handling
# Purpose: Verify that flags are properly formatted
# Expected: PASS
# Executable: cmake -P test_enable_suppress_flags.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the Cppcheck module
include(Cppcheck)

# Test: Configure with ENABLE and SUPPRESS flags
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

set(test_failed FALSE)

if(Cppcheck_FOUND)
    set(cppcheck_cmd "${CMAKE_C_CPPCHECK}")

    # Check --enable flag format: comma-separated is correct for --enable
    if(NOT ("${cppcheck_cmd}" MATCHES "--enable=warning,style,performance"))
        message(STATUS "FAIL: --enable flag has unexpected format. Command: ${cppcheck_cmd}")
        set(test_failed TRUE)
    else()
        message(STATUS "PASS: --enable flag has correct format: --enable=warning,style,performance")
    endif()

    # Check --suppress flags: each suppression must be a separate flag
    if(NOT ("${cppcheck_cmd}" MATCHES "--suppress=missingIncludeSystem"))
        message(STATUS "FAIL: --suppress=missingIncludeSystem not in command: ${cppcheck_cmd}")
        set(test_failed TRUE)
    else()
        message(STATUS "PASS: --suppress=missingIncludeSystem is present")
    endif()

    if(NOT ("${cppcheck_cmd}" MATCHES "--suppress=unusedVariable"))
        message(STATUS "FAIL: --suppress=unusedVariable not in command: ${cppcheck_cmd}")
        set(test_failed TRUE)
    else()
        message(STATUS "PASS: --suppress=unusedVariable is present")
    endif()

    # Verify suppression IDs are NOT joined with a comma into one flag
    if("${cppcheck_cmd}" MATCHES "--suppress=[^ ]*,[^ ]*")
        message(
            STATUS
            "FAIL: --suppress flags are comma-joined (unsupported by cppcheck). Command: ${cppcheck_cmd}"
        )
        set(test_failed TRUE)
    else()
        message(STATUS "PASS: --suppress flags are correctly separate (no comma-joining)")
    endif()

    message(STATUS "Full command: ${cppcheck_cmd}")
else()
    message(STATUS "PASS: ENABLE/SUPPRESS flags test - advisory mode (tool not installed)")
    message(STATUS "  CMAKE_C_CPPCHECK = '${CMAKE_C_CPPCHECK}' (empty as expected)")
endif()

if(test_failed)
    message(FATAL_ERROR "FAIL: ENABLE and SUPPRESS parameter test failed")
endif()

message(STATUS "PASS: ENABLE and SUPPRESS parameter test completed successfully")
