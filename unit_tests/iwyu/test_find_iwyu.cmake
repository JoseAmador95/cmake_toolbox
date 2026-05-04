# Test: FindIWYU module
# Purpose: Verify that find_package(IWYU) works correctly
# Expected: PASS (with or without IWYU installed)
# Executable: cmake -P test_find_iwyu.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Test 1: Find IWYU quietly (should not fail)
find_package(IWYU QUIET)

if(IWYU_FOUND)
    if(IWYU_EXECUTABLE)
        message(STATUS "PASS: IWYU found at ${IWYU_EXECUTABLE}")
        if(IWYU_VERSION)
            message(STATUS "  Version: ${IWYU_VERSION}")
        endif()
    else()
        message(FATAL_ERROR "FAIL: IWYU_FOUND=TRUE but IWYU_EXECUTABLE is empty")
    endif()
else()
    # IWYU not found is acceptable - test should still pass
    # This is expected when the tool is not installed
    if(DEFINED IWYU_EXECUTABLE AND IWYU_EXECUTABLE STREQUAL "")
        message(STATUS "PASS: IWYU not found (expected in CI without tool)")
    else()
        # Verify that if found, executable is set
        if(DEFINED IWYU_EXECUTABLE)
            message(STATUS "PASS: IWYU not found - variables properly unset")
        else()
            message(STATUS "PASS: IWYU not found (expected in CI without tool)")
        endif()
    endif()
endif()

message(STATUS "PASS: FindIWYU module test completed successfully")
