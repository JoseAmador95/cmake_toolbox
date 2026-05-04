# Test: Cppcheck_ConfigureTarget for specific target
# Purpose: Verify per-target configuration function exists and accepts parameters
# Note: Full target testing requires a CMake project with targets
# This test focuses on verifying the function signature and advisory mode behavior
# Expected: PASS (even without cppcheck installed)
# Executable: cmake -P test_configure_target_basic.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the Cppcheck module to get the function
include(Cppcheck)

# Verify the function exists
if(COMMAND Cppcheck_ConfigureTarget)
    message(STATUS "PASS: Cppcheck_ConfigureTarget function exists")
else()
    message(FATAL_ERROR "FAIL: Cppcheck_ConfigureTarget function not found")
endif()

# Test the function with a non-existent target in advisory mode
# This should NOT fail in advisory mode (only if STRICT flag is used)
Cppcheck_ConfigureTarget(TARGET nonexistent_target_12345 STATUS ON)

message(STATUS "PASS: Cppcheck_ConfigureTarget accepted parameters in advisory mode")
message(STATUS "  Non-existent target was handled gracefully (expected behavior)")

# Verify we can call it again with STATUS OFF
Cppcheck_ConfigureTarget(TARGET nonexistent_target_12345 STATUS OFF)

message(STATUS "PASS: Cppcheck_ConfigureTarget test completed successfully")
