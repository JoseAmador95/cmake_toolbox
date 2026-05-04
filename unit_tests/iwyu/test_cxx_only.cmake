# Test: IWYU is C++ only
# Purpose: Verify that IWYU only sets CXX_INCLUDE_WHAT_YOU_USE, not C_INCLUDE_WHAT_YOU_USE
# Expected: PASS
# Executable: cmake -P test_cxx_only.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the IWYU module
include(IWYU)

# Configure IWYU globally
IWYU_Configure(STATUS ON)

# Check C variable (should not be set)
if(DEFINED CMAKE_C_INCLUDE_WHAT_YOU_USE)
    set(c_variable "${CMAKE_C_INCLUDE_WHAT_YOU_USE}")
else()
    set(c_variable "UNDEFINED")
endif()

# Check CXX variable (may or may not be set depending on tool availability)
if(DEFINED CMAKE_CXX_INCLUDE_WHAT_YOU_USE)
    set(cxx_variable "${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}")
else()
    set(cxx_variable "UNDEFINED")
endif()

# Verify C variable is NOT set (or is empty)
if(c_variable STREQUAL "UNDEFINED" OR c_variable STREQUAL "")
    message(STATUS "PASS: C++ Only - CMAKE_C_INCLUDE_WHAT_YOU_USE is NOT set")
    message(STATUS "  CMAKE_C_INCLUDE_WHAT_YOU_USE = '${c_variable}'")
else()
    message(
        FATAL_ERROR
        "FAIL: CMAKE_C_INCLUDE_WHAT_YOU_USE should not be set but is: '${c_variable}'"
    )
endif()

# Verify CXX variable behavior
if(IWYU_FOUND)
    # Tool found - CXX variable should be set
    if(cxx_variable STREQUAL "UNDEFINED" OR cxx_variable STREQUAL "")
        message(FATAL_ERROR "FAIL: IWYU found but CMAKE_CXX_INCLUDE_WHAT_YOU_USE not set")
    else()
        message(STATUS "PASS: C++ Only - CMAKE_CXX_INCLUDE_WHAT_YOU_USE is set for tool")
        message(STATUS "  CMAKE_CXX_INCLUDE_WHAT_YOU_USE = ${cxx_variable}")
    endif()
else()
    # Tool not found - CXX variable should be empty (advisory mode)
    if(cxx_variable STREQUAL "" OR cxx_variable STREQUAL "UNDEFINED")
        message(STATUS "PASS: C++ Only - CMAKE_CXX_INCLUDE_WHAT_YOU_USE is empty (tool not found)")
    else()
        message(FATAL_ERROR "FAIL: CMAKE_CXX_INCLUDE_WHAT_YOU_USE should be empty without tool")
    endif()
endif()

message(STATUS "PASS: IWYU C++ only test completed successfully")
