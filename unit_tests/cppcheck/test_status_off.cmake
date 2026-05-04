# Test: STATUS OFF disables cppcheck
# Purpose: Verify that STATUS OFF clears the cppcheck configuration
# Expected: PASS (regardless of tool availability)
# Executable: cmake -P test_status_off.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the Cppcheck module
include(Cppcheck)

# Test 1: Enable cppcheck first (if available)
Cppcheck_Configure(STATUS ON)

# Store the initial state
set(initial_c_cppcheck "${CMAKE_C_CPPCHECK}")
set(initial_cxx_cppcheck "${CMAKE_CXX_CPPCHECK}")

# Test 2: Disable cppcheck with STATUS OFF
Cppcheck_Configure(STATUS OFF)

# Get the state after disabling
set(final_c_cppcheck "${CMAKE_C_CPPCHECK}")
set(final_cxx_cppcheck "${CMAKE_CXX_CPPCHECK}")

# Verify that disabling clears the configuration
if("${final_c_cppcheck}" STREQUAL "" AND "${final_cxx_cppcheck}" STREQUAL "")
    message(STATUS "PASS: STATUS OFF - Both C and CXX cppcheck variables are empty")
    message(STATUS "  CMAKE_C_CPPCHECK = '${final_c_cppcheck}'")
    message(STATUS "  CMAKE_CXX_CPPCHECK = '${final_cxx_cppcheck}'")
else()
    if("${final_c_cppcheck}" STREQUAL "")
        message(STATUS "  CMAKE_C_CPPCHECK correctly cleared")
    else()
        message(FATAL_ERROR "FAIL: CMAKE_C_CPPCHECK not cleared: '${final_c_cppcheck}'")
    endif()

    if("${final_cxx_cppcheck}" STREQUAL "")
        message(STATUS "  CMAKE_CXX_CPPCHECK correctly cleared")
    else()
        message(FATAL_ERROR "FAIL: CMAKE_CXX_CPPCHECK not cleared: '${final_cxx_cppcheck}'")
    endif()
endif()

# Test 3: Verify we can enable/disable multiple times
Cppcheck_Configure(STATUS ON)
set(second_enabled_c "${CMAKE_C_CPPCHECK}")

Cppcheck_Configure(STATUS OFF)
set(second_disabled_c "${CMAKE_C_CPPCHECK}")

if("${second_disabled_c}" STREQUAL "")
    message(STATUS "PASS: Multiple enable/disable cycles work correctly")
else()
    message(FATAL_ERROR "FAIL: STATUS OFF did not clear after second cycle")
endif()

message(STATUS "PASS: STATUS OFF test completed successfully")
