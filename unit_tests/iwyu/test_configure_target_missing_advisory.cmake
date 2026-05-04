# Test: IWYU_ConfigureTarget missing target in advisory mode
# Purpose: Verify that missing target only warns in advisory mode
# Expected: PASS (advisory mode should not fail on missing target)
# Executable: cmake -P test_configure_target_missing_advisory.cmake

cmake_minimum_required(VERSION 3.22)

# Get absolute path to cmake modules
get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

# Create test directory with unique timestamp to avoid conflicts
string(TIMESTAMP test_timestamp "%H%M%S%f")
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_timestamp}")
set(build_dir "${test_dir}/build_output")
file(MAKE_DIRECTORY "${build_dir}")

# Create the CMakeLists.txt content
file(
    WRITE "${build_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(IWYUTestAdvisoryMode LANGUAGES CXX)

set(CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(IWYU)

# Try to configure a non-existent target in advisory mode
# Should not fail, just issue a verbose message
IWYU_ConfigureTarget(TARGET nonexistent_target STATUS ON)

# If we reach here, advisory mode handled missing target correctly
message(\"PASS: Advisory mode handled missing target\")
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

# Check result
if(result EQUAL 0)
    if(output MATCHES "PASS" OR error MATCHES "PASS")
        message(STATUS "PASS: IWYU_ConfigureTarget advisory mode test successful")
    else()
        message(
            FATAL_ERROR
            "FAIL: Test succeeded but did not output PASS. output=${output}, error=${error}"
        )
    endif()
else()
    message(FATAL_ERROR "FAIL: Test failed with result=${result}, output=${output}, error=${error}")
endif()
