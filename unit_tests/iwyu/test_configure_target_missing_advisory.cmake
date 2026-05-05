# Test: IWYU_ConfigureTarget missing target requirement
# Purpose: Verify that missing target always causes a configuration error
# Expected: PASS (test correctly validates that missing target fails)
# Executable: cmake -P test_configure_target_missing_advisory.cmake

cmake_minimum_required(VERSION 3.22)

# Get absolute path to cmake modules
get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

# Create test directory with unique timestamp to avoid conflicts
string(TIMESTAMP test_timestamp "%s")
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_timestamp}")
set(build_dir "${test_dir}/build_output")
file(MAKE_DIRECTORY "${build_dir}")

# Create the CMakeLists.txt content
file(
    WRITE "${build_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(IWYUTestMissingTarget LANGUAGES CXX)

set(CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(IWYU)

# Try to configure a non-existent target
# Should ALWAYS fail (missing target is a usage error)
IWYU_ConfigureTarget(TARGET nonexistent_target STATUS ON)

message(\"ERROR: Should not reach here!\")
"
)

# Run cmake on the test project
execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${build_dir}" -B "${build_dir}/cmake_build"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)

# Cleanup
file(REMOVE_RECURSE "${test_dir}")

# Check result - should FAIL
if(result EQUAL 0)
    message(FATAL_ERROR "FAIL: IWYU_ConfigureTarget should fail on missing target")
else()
    if(error MATCHES "does not exist")
        message(STATUS "PASS: IWYU_ConfigureTarget correctly failed on missing target")
    else()
        message(FATAL_ERROR "FAIL: Test failed but with unexpected error: ${error}")
    endif()
endif()
