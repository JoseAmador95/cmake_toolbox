# Test: Cppcheck_ConfigureTarget for specific target
# Purpose: Verify per-target configuration works with real targets and fails on missing ones
# Expected: PASS
# Executable: cmake -P test_configure_target_basic.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

# Include the Cppcheck module to get the function
include(Cppcheck)

# Verify the function exists
if(COMMAND Cppcheck_ConfigureTarget)
    message(STATUS "PASS: Cppcheck_ConfigureTarget function exists")
else()
    message(FATAL_ERROR "FAIL: Cppcheck_ConfigureTarget function not found")
endif()

# Test 1: Missing target should ALWAYS cause a configuration error
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

# Test 2: STRICT flag also fails on missing target
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

# Test 3: Real target — C_CPPCHECK and CXX_CPPCHECK properties must be set when cppcheck found
get_filename_component(test_script_name "${CMAKE_CURRENT_LIST_FILE}" NAME_WE)
string(TIMESTAMP test_timestamp "%Y%m%d%H%M%S")
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_script_name}_${test_timestamp}")
set(build_dir "${test_dir}/build")
file(MAKE_DIRECTORY "${build_dir}/src")

file(WRITE "${build_dir}/src/dummy.c" "int c_add(int a, int b) { return a + b; }\n")
file(WRITE "${build_dir}/src/dummy.cpp" "int cpp_add(int a, int b) { return a + b; }\n")

file(
    WRITE "${build_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(CppcheckTargetTest LANGUAGES C CXX)

set(CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(Cppcheck)

add_library(testlib STATIC src/dummy.c src/dummy.cpp)
Cppcheck_ConfigureTarget(TARGET testlib STATUS ON)

get_target_property(c_prop testlib C_CPPCHECK)
get_target_property(cxx_prop testlib CXX_CPPCHECK)

if(Cppcheck_FOUND)
    if(NOT c_prop)
        message(FATAL_ERROR \"FAIL: Cppcheck found but C_CPPCHECK not set on target\")
    endif()
    if(NOT cxx_prop)
        message(FATAL_ERROR \"FAIL: Cppcheck found but CXX_CPPCHECK not set on target\")
    endif()
    message(\"PASS: Target properties set correctly\")
else()
    message(\"PASS: Target configured (Cppcheck not available)\")
endif()
"
)

execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${build_dir}" -B "${build_dir}/cmake_build"
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)

file(REMOVE_RECURSE "${test_dir}")

if(NOT (result EQUAL 0))
    message(FATAL_ERROR "FAIL: Real target test configure failed: ${error}")
endif()

if(output MATCHES "FAIL" OR error MATCHES "FAIL")
    message(FATAL_ERROR "FAIL: Real target test inner cmake reported failure. output=${output}")
endif()

message(STATUS "PASS: Cppcheck_ConfigureTarget works correctly with a real target")

message(STATUS "PASS: Cppcheck_ConfigureTarget test completed successfully")

# Cleanup temp files
file(
    REMOVE
    "${CMAKE_CURRENT_BINARY_DIR}/test_missing_target.cmake"
    "${CMAKE_CURRENT_BINARY_DIR}/test_missing_target_strict.cmake"
)
