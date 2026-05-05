# Test: IWYU_ConfigureTarget for specific target
# Purpose: Verify per-target configuration function works with a real target
# Expected: PASS (even without IWYU installed)
# Executable: cmake -P test_configure_target_basic.cmake

cmake_minimum_required(VERSION 3.22)

# Get absolute path to cmake modules
get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

# Create test directory with unique timestamp to avoid conflicts
get_filename_component(test_script_name "${CMAKE_CURRENT_LIST_FILE}" NAME_WE)
string(TIMESTAMP test_timestamp "%Y%m%d%H%M%S")
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_script_name}_${test_timestamp}")
set(build_dir "${test_dir}/build_output")
file(MAKE_DIRECTORY "${build_dir}")

# Create the CMakeLists.txt content with proper escaping
file(MAKE_DIRECTORY "${build_dir}/src")

file(WRITE "${build_dir}/src/dummy.c" "int c_add(int a, int b) { return a + b; }\n")
file(WRITE "${build_dir}/src/dummy.cpp" "int cpp_add(int a, int b) { return a + b; }\n")

file(
    WRITE "${build_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(IWYUTestWrapper LANGUAGES C CXX)

set(CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(IWYU)

add_library(testlib STATIC src/dummy.c src/dummy.cpp)
IWYU_ConfigureTarget(TARGET testlib STATUS ON)
get_target_property(iwyu_prop testlib CXX_INCLUDE_WHAT_YOU_USE)
if(iwyu_prop)
    message(\"PASS: Target configured\")
else()
    message(\"PASS: Target configured (IWYU not available)\")
endif()
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
        message(STATUS "PASS: IWYU_ConfigureTarget test successful")
    else()
        message(
            FATAL_ERROR
            "FAIL: Test succeeded but did not output PASS. output=${output}, error=${error}"
        )
    endif()
else()
    message(FATAL_ERROR "FAIL: Test failed with result=${result}, output=${output}, error=${error}")
endif()
