# Test: FindCException module
# Purpose: Verify that find_package(CException) works correctly
# Expected: PASS (with or without CException installed)
# Executable: cmake -P test_find_cexception.cmake

cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

find_package(CException QUIET MODULE)

if(CException_FOUND)
    if(NOT CException_INCLUDE_DIR)
        message(FATAL_ERROR "FAIL: CException_FOUND=TRUE but CException_INCLUDE_DIR is empty")
    endif()
    if(NOT CException_SOURCE)
        message(FATAL_ERROR "FAIL: CException_FOUND=TRUE but CException_SOURCE is empty")
    endif()
    if(NOT TARGET CException::CException)
        message(
            FATAL_ERROR
            "FAIL: CException_FOUND=TRUE but CException::CException target was not created"
        )
    endif()
    message(STATUS "PASS: CException found")
    message(STATUS "  Include: ${CException_INCLUDE_DIR}")
    message(STATUS "  Source:  ${CException_SOURCE}")
else()
    message(STATUS "PASS: CException not found (expected in CI without library installed)")
endif()

message(STATUS "PASS: FindCException module test completed successfully")
