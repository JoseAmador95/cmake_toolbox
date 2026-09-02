if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: the default gcovr search path points at the build tree
#
# Regression test. CMT_GCOVR_SEARCH_PATH used to default to the empty string,
# which left gcovr scanning its working directory (the source tree) instead of
# the build tree where the .gcda/.gcno files actually live. The report then
# described whatever stale coverage data happened to sit under the sources.
#
# The fixture reproduces exactly that: a decoy build directory with real
# coverage data for decoy.c is planted *inside* the fixture source tree, and the
# project under test is configured out-of-source without ever setting
# CMT_GCOVR_SEARCH_PATH. The report must cover example.c (the file the project
# compiled) and must not mention decoy.c.

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_gcov_search_path")

find_program(REAL_GCOVR gcovr)
if(NOT REAL_GCOVR)
    message(STATUS "  - gcovr not installed, skipping search path default test")
    return()
endif()

set(_cmt_test_build_config "")
if(DEFINED CMAKE_TOOLBOX_TEST_BUILD_TYPE AND NOT CMAKE_TOOLBOX_TEST_BUILD_TYPE STREQUAL "")
    set(_cmt_test_build_config "${CMAKE_TOOLBOX_TEST_BUILD_TYPE}")
elseif(
    DEFINED
        CMAKE_TOOLBOX_TEST_GENERATOR
    AND CMAKE_TOOLBOX_TEST_GENERATOR
        MATCHES
        "Visual Studio|Xcode|Multi-Config"
)
    set(_cmt_test_build_config "Debug")
endif()

set(_cmt_test_build_args "")
if(_cmt_test_build_config)
    list(
        APPEND _cmt_test_build_args
        --config
        "${_cmt_test_build_config}"
    )
endif()

set(_exe_suffix "")
if(WIN32)
    set(_exe_suffix ".exe")
endif()

message(STATUS "=== Gcov Search Path Default Integration Test ===")
message(STATUS "Using gcovr: ${REAL_GCOVR}")

set(src_dir "${TEST_ROOT}/src")
set(build_dir "${TEST_ROOT}/build")
set(decoy_dir "${src_dir}/stale")
set(decoy_build_dir "${decoy_dir}/build")

file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${src_dir}")
file(MAKE_DIRECTORY "${decoy_dir}")

TestHelpers_GetConfigureArgs(configure_args)

# ------------------------------------------------------------------------------
# The decoy: a real, instrumented build living *inside* the source tree
# ------------------------------------------------------------------------------

file(
    WRITE "${decoy_dir}/decoy.c"
    "int decoy_func(int x) { if (x > 0) { return 1; } return 0; }
int main(void) { return decoy_func(1) - 1; }"
)
file(
    WRITE "${decoy_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(GcovDecoy LANGUAGES C)
add_executable(decoy decoy.c)
target_compile_options(decoy PRIVATE --coverage)
target_link_options(decoy PRIVATE --coverage)
"
)

execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${decoy_dir}" -B "${decoy_build_dir}" ${configure_args}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Decoy configuration failed: ${error}")
endif()

execute_process(
    COMMAND
        ${CMAKE_COMMAND} --build "${decoy_build_dir}" ${_cmt_test_build_args}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    if("${error}" MATCHES "libclang_rt")
        message(STATUS "  - compiler runtime libraries missing, skipping")
        return()
    endif()
    message(FATAL_ERROR "Decoy build failed: ${error}")
endif()

set(decoy_bin_dir "${decoy_build_dir}")
if(_cmt_test_build_config)
    set(decoy_bin_dir "${decoy_build_dir}/${_cmt_test_build_config}")
endif()

execute_process(
    COMMAND
        "${decoy_bin_dir}/decoy${_exe_suffix}"
    WORKING_DIRECTORY "${decoy_build_dir}"
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Decoy binary exited with ${result}")
endif()

file(GLOB_RECURSE decoy_gcda "${decoy_build_dir}/*.gcda")
if(NOT decoy_gcda)
    message(FATAL_ERROR "The decoy produced no .gcda files; the fixture cannot detect the bug")
endif()
message(STATUS "  planted decoy coverage data: ${decoy_gcda}")

# ------------------------------------------------------------------------------
# The project under test: built out-of-source, no explicit search path
# ------------------------------------------------------------------------------

file(WRITE "${src_dir}/example.c" "int example_func(int x) { if (x > 0) { return 1; } return 0; }")
file(
    WRITE "${src_dir}/main.c"
    "extern int example_func(int); int main(void) { return example_func(1) - 1; }"
)
file(
    WRITE "${src_dir}/CMakeLists.txt"
    "
cmake_minimum_required(VERSION 3.22)
project(GcovSearchPathTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Deliberately no CMT_GCOVR_SEARCH_PATH: the module default must already point
# gcovr at the build tree.
set(CMT_GCOVR_OUTPUT_FORMATS \"json\" CACHE STRING \"\" FORCE)

include(Gcov)

add_library(examplelib STATIC example.c)
Gcov_AddToTarget(examplelib PUBLIC)

add_executable(exampletest main.c)
target_link_libraries(exampletest PRIVATE examplelib)
"
)

execute_process(
    COMMAND
        ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Configuration failed: ${error}")
endif()

execute_process(
    COMMAND
        ${CMAKE_COMMAND} --build "${build_dir}" ${_cmt_test_build_args} --target exampletest
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    if("${error}" MATCHES "libclang_rt")
        message(STATUS "  - compiler runtime libraries missing, skipping")
        return()
    endif()
    message(FATAL_ERROR "Build failed: ${error}")
endif()

set(test_bin_dir "${build_dir}")
if(_cmt_test_build_config)
    set(test_bin_dir "${build_dir}/${_cmt_test_build_config}")
endif()

execute_process(
    COMMAND
        "${test_bin_dir}/exampletest${_exe_suffix}"
    WORKING_DIRECTORY "${build_dir}"
    RESULT_VARIABLE result
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Instrumented binary exited with ${result}")
endif()

execute_process(
    COMMAND
        ${CMAKE_COMMAND} --build "${build_dir}" ${_cmt_test_build_args} --target gcovr
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)
if(NOT result EQUAL 0)
    message(FATAL_ERROR "Building the gcovr target failed:\n${output}\n${error}")
endif()

if(NOT EXISTS "${build_dir}/coverage/coverage.json")
    message(FATAL_ERROR "Expected coverage.json in ${build_dir}/coverage")
endif()

file(READ "${build_dir}/coverage/coverage.json" coverage_json)

# The report must describe the file this build actually compiled ...
if(NOT coverage_json MATCHES "example\\.c")
    message(
        FATAL_ERROR
        "Coverage report does not mention example.c; gcovr did not find the build tree data"
    )
endif()

# ... and nothing from the decoy build planted in the source tree.
if(coverage_json MATCHES "decoy")
    message(
        FATAL_ERROR
        "Coverage report contains the decoy from ${decoy_build_dir}; "
        "gcovr scanned the source tree instead of the build tree"
    )
endif()

message(STATUS "  ok report covers example.c and ignores the source-tree decoy")

# And the mechanism behind it: the generated config carries the build tree as
# the default search path.
set(generated_cfg "${build_dir}/coverage/gcovr_generated.cfg")
if(NOT EXISTS "${generated_cfg}")
    message(FATAL_ERROR "Expected a generated config at ${generated_cfg}")
endif()
file(READ "${generated_cfg}" generated_cfg_content)
if(NOT generated_cfg_content MATCHES "search-path *= *${build_dir}")
    message(
        FATAL_ERROR
        "The generated config must default search-path to ${build_dir}:\n${generated_cfg_content}"
    )
endif()

message(STATUS "  ok the generated config defaults search-path to the build tree")
message(STATUS "Gcov search path default test PASSED")
