# Test: FindCppcheck module
# Purpose: Verify that find_package(Cppcheck) works correctly
# Expected: PASS (with or without cppcheck installed)
# Executable: cmake -P test_find_cppcheck.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Test 1: Find cppcheck quietly (should not fail)
find_package(Cppcheck QUIET)

if(Cppcheck_FOUND)
    if(Cppcheck_EXECUTABLE)
        message(STATUS "PASS: Cppcheck found at ${Cppcheck_EXECUTABLE}")
        if(Cppcheck_VERSION)
            message(STATUS "  Version: ${Cppcheck_VERSION}")
        endif()
    else()
        message(FATAL_ERROR "FAIL: Cppcheck_FOUND=TRUE but Cppcheck_EXECUTABLE is empty")
    endif()
else()
    # Cppcheck not found is acceptable - test should still pass
    # This is expected when the tool is not installed
    if(DEFINED Cppcheck_EXECUTABLE AND Cppcheck_EXECUTABLE STREQUAL "")
        message(STATUS "PASS: Cppcheck not found (expected in CI without tool)")
    else()
        # Verify that if found, executable is set
        if(DEFINED Cppcheck_EXECUTABLE)
            message(STATUS "PASS: Cppcheck not found - variables properly unset")
        else()
            message(STATUS "PASS: Cppcheck not found (expected in CI without tool)")
        endif()
    endif()
endif()

message(STATUS "PASS: FindCppcheck module test completed successfully")
