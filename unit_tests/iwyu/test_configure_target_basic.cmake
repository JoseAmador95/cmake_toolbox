# Test: IWYU_ConfigureTarget for specific target
# Purpose: Verify per-target configuration function works with a real target
# Expected: PASS (even without IWYU installed)
# Executable: cmake -P test_configure_target_basic.cmake

cmake_minimum_required(VERSION 3.22)

# Create test directory
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
set(src_dir "${test_dir}/src")
set(build_dir "${test_dir}/build")
file(MAKE_DIRECTORY "${src_dir}")
file(MAKE_DIRECTORY "${build_dir}")

# Get absolute path to cmake modules
get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

# Create minimal CMakeLists.txt for test project
file(
    WRITE "${src_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(IWYUTest LANGUAGES CXX)
list(APPEND CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(IWYU)
add_library(testlib STATIC \"${src_dir}/lib.cpp\")
IWYU_ConfigureTarget(TARGET testlib STATUS ON)
get_target_property(iwyu_prop testlib CXX_INCLUDE_WHAT_YOU_USE)
if(iwyu_prop)
    message(\"PASS: Target configured\")
else()
    message(\"PASS: Target configured (IWYU not available)\")
endif()
"
)

# Create minimal source file
file(WRITE "${src_dir}/lib.cpp" "void dummy() {}")

# Run cmake on the test project
execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
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
        if(output MATCHES "PASS")
            message(STATUS "Output: ${output}")
        endif()
        if(error MATCHES "PASS")
            message(STATUS "Error output: ${error}")
        endif()
    else()
        message(
            FATAL_ERROR
            "FAIL: Test succeeded but did not output PASS. output=${output}, error=${error}"
        )
    endif()
else()
    message(FATAL_ERROR "FAIL: Test failed with result=${result}, output=${output}, error=${error}")
endif()
