# Test: IWYU_ConfigureTarget for specific C++ target
# Purpose: Verify per-target configuration function works with a real target
# Expected: PASS (even without IWYU installed)
# Executable: cmake -P test_configure_target_basic.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Create a test directory for the minimal project
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
file(MAKE_DIRECTORY "${test_dir}")

# Create minimal CMake project
set(src_dir "${test_dir}/src")
set(build_dir "${test_dir}/build")
file(MAKE_DIRECTORY "${src_dir}")
file(MAKE_DIRECTORY "${build_dir}")

# Write a test CMakeLists.txt that uses IWYU_ConfigureTarget
set(test_cmakelists
    "
cmake_minimum_required(VERSION 3.22)
project(IWYUTargetTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${CMAKE_CURRENT_LIST_DIR}/../../cmake\")

include(IWYU)

# Create a simple library target
add_library(test_lib STATIC lib.cpp)

# Configure the target with IWYU
IWYU_ConfigureTarget(TARGET test_lib STATUS ON)

# Verify the target property was set
get_target_property(iwyu_setting test_lib CXX_INCLUDE_WHAT_YOU_USE)
if(iwyu_setting)
    message(STATUS \"PASS: Target CXX_INCLUDE_WHAT_YOU_USE property set to: \${iwyu_setting}\")
else()
    if(IWYU_FOUND)
        message(FATAL_ERROR \"FAIL: Target property should be set when IWYU found\")
    else()
        message(STATUS \"PASS: Target property not set (IWYU not found, advisory mode)\")
    endif()
endif()
"
)

file(WRITE "${src_dir}/CMakeLists.txt" "${test_cmakelists}")
file(WRITE "${src_dir}/lib.cpp" "#include <iostream>\nvoid lib_func() { }")

# Use execute_process to run cmake configure
execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)

if(NOT result EQUAL 0)
    message(FATAL_ERROR "FAIL: CMake configure failed: ${error}")
endif()

# Check if the test was successful from the output
if(output MATCHES "PASS")
    message(STATUS "PASS: IWYU_ConfigureTarget test completed successfully")
    message(STATUS "Test output:\n${output}")
else()
    message(FATAL_ERROR "FAIL: Test did not report PASS. Output: ${output}")
endif()

# Cleanup
file(REMOVE_RECURSE "${test_dir}")
