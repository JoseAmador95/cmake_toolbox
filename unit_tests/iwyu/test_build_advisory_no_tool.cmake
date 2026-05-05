# Test: Advisory mode with tool absent — build always passes
# Purpose: Verify that STRICT=OFF with no IWYU tool does not break the build,
#          even when source files contain IWYU violations.
# Expected: PASS (build always succeeds; violations are not checked without the tool)
# Executable: cmake -P test_build_advisory_no_tool.cmake

cmake_minimum_required(VERSION 3.22)

get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

string(TIMESTAMP test_timestamp "%Y%m%d%H%M%S")
set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_timestamp}")
set(build_dir "${test_dir}/build")
set(fake_finder_dir "${test_dir}/fake_cmake_modules")
file(
    MAKE_DIRECTORY
        "${build_dir}/src"
        "${fake_finder_dir}"
)

# Fake FindIWYU.cmake: always reports the tool as absent, regardless of system state.
# Prepending its directory to CMAKE_MODULE_PATH ensures cmake finds it before the real one.
file(
    WRITE "${fake_finder_dir}/FindIWYU.cmake"
    "set(IWYU_FOUND FALSE)\nset(IWYU_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)\n"
)

# Source file with IWYU violations — would be caught if the tool were present
file(
    WRITE "${build_dir}/src/violations.cpp"
    "#include <vector>\nint add(int a, int b) { return a + b; }\n"
)

file(
    WRITE "${build_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(IWYUAdvisoryNoTool LANGUAGES CXX)

# Fake finder prepended so IWYU_FOUND is always FALSE in this test
set(CMAKE_MODULE_PATH \"${fake_finder_dir}\" \"${abs_cmake_module_path}\")
include(IWYU)

add_library(testlib STATIC src/violations.cpp)
IWYU_ConfigureTarget(TARGET testlib STATUS ON)

get_target_property(iwyu_prop testlib CXX_INCLUDE_WHAT_YOU_USE)
if(iwyu_prop)
    message(FATAL_ERROR \"FAIL: CXX_INCLUDE_WHAT_YOU_USE must be empty when tool is absent\")
else()
    message(\"PASS: Advisory mode correctly leaves property empty when tool is absent\")
endif()
"
)

execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${build_dir}" -B "${build_dir}/cmake_build"
    RESULT_VARIABLE config_result
    OUTPUT_VARIABLE config_output
    ERROR_VARIABLE config_error
)
if(NOT (config_result EQUAL 0))
    file(REMOVE_RECURSE "${test_dir}")
    message(FATAL_ERROR "FAIL: Configure failed: ${config_error}")
endif()

if(NOT (config_output MATCHES "PASS" OR config_error MATCHES "PASS"))
    file(REMOVE_RECURSE "${test_dir}")
    message(
        FATAL_ERROR
        "FAIL: Configure did not report expected advisory behaviour. output=${config_output} error=${config_error}"
    )
endif()

execute_process(
    COMMAND
        ${CMAKE_COMMAND} --build "${build_dir}/cmake_build"
    RESULT_VARIABLE build_result
    OUTPUT_VARIABLE build_output
    ERROR_VARIABLE build_error
)

file(REMOVE_RECURSE "${test_dir}")

if(NOT (build_result EQUAL 0))
    message(
        FATAL_ERROR
        "FAIL: Build must pass in advisory mode when tool is absent. error=${build_error}"
    )
endif()

message(STATUS "PASS: Advisory mode without tool — build succeeded despite violations in source")
