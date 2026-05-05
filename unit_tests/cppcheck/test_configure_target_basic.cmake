# Test: Cppcheck_ConfigureTarget for specific target
# Purpose: Verify per-target configuration function requires existing targets
# Note: Missing targets always cause a configuration error (not context-dependent)
# Expected: PASS (test correctly validates that missing target fails)
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

# Test: Missing target should ALWAYS cause a configuration error
# Create a test script that attempts to use a non-existent target
file(
    WRITE "${CMAKE_CURRENT_BINARY_DIR}/test_missing_target.cmake"
    "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/../../cmake\")
include(Cppcheck)
Cppcheck_ConfigureTarget(TARGET nonexistent_target_12345 STATUS ON)
"
)

execute_process(
    COMMAND
        ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_BINARY_DIR}/test_missing_target.cmake"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)

if(result EQUAL 0)
    message(FATAL_ERROR "FAIL: Cppcheck_ConfigureTarget should have failed on missing target")
else()
    message(STATUS "PASS: Cppcheck_ConfigureTarget correctly failed on missing target")
endif()

# Test with STRICT flag (should also fail, but this verifies STRICT is accepted)
file(
    WRITE "${CMAKE_CURRENT_BINARY_DIR}/test_missing_target_strict.cmake"
    "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/../../cmake\")
include(Cppcheck)
Cppcheck_ConfigureTarget(TARGET another_nonexistent STRICT STATUS ON)
"
)

execute_process(
    COMMAND
        ${CMAKE_COMMAND} -P "${CMAKE_CURRENT_BINARY_DIR}/test_missing_target_strict.cmake"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)

if(result EQUAL 0)
    message(
        FATAL_ERROR
        "FAIL: Cppcheck_ConfigureTarget STRICT mode should also fail on missing target"
    )
else()
    message(STATUS "PASS: Cppcheck_ConfigureTarget STRICT mode correctly failed on missing target")
endif()

message(STATUS "PASS: Cppcheck_ConfigureTarget test completed successfully")

# Cleanup temp files
file(
    REMOVE
    "${CMAKE_CURRENT_BINARY_DIR}/test_missing_target.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/test_missing_target_strict.cmake"
)
