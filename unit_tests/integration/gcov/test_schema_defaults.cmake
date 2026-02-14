if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: Gcov SCHEMA mode with defaults
# Verifies that Gcov module correctly applies coverage flags in SCHEMA mode

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_gcov_schema_defaults")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_gcovr")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)
    set(GCOVR_MOCK_PATH "${mock_gcovr_path}" PARENT_SCOPE)
endfunction()

function(test_schema_defaults_gcc)
    message(STATUS "Test 1: SCHEMA mode with GCC defaults")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovSchemaTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_C_COMPILER_ID \"GNU\")
set(CMAKE_CXX_COMPILER_ID \"GNU\")

set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)

# Verify coverage flags were applied
get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")

# Check for coverage flag presence
string(FIND \"\${compile_opts}\" \"coverage\" has_coverage)
if(has_coverage EQUAL -1)
    message(FATAL_ERROR \"Expected --coverage flag in compile options\")
endif()

# Verify gcovr config file was generated
if(NOT EXISTS \"\${CMAKE_BINARY_DIR}/coverage/gcovr_generated.cfg\")
    message(FATAL_ERROR \"Expected gcovr_generated.cfg to be created\")
endif()

message(STATUS \"SCHEMA mode defaults test passed\")
"
    )

    set(src_dir "${TEST_ROOT}/schema_gcc/src")
    set(build_dir "${TEST_ROOT}/schema_gcc/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SCHEMA mode GCC defaults failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Verify config file exists
    if(NOT EXISTS "${build_dir}/coverage/gcovr_generated.cfg")
        message(STATUS "  ✗ gcovr_generated.cfg not created")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Verify config file has some content (schema varies by gcovr version)
    file(READ "${build_dir}/coverage/gcovr_generated.cfg" config_content)
    string(LENGTH "${config_content}" config_len)
    if(config_len LESS 10)
        message(STATUS "  ✗ Config file appears empty or too short")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ SCHEMA mode GCC defaults works correctly")
endfunction()

function(test_schema_defaults_clang)
    message(STATUS "Test 2: SCHEMA mode with Clang defaults")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovSchemaTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_C_COMPILER_ID \"Clang\")
set(CMAKE_CXX_COMPILER_ID \"Clang\")

set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)

# Verify coverage flags applied (same for Clang)
get_target_property(compile_opts mylib COMPILE_OPTIONS)
string(FIND \"\${compile_opts}\" \"coverage\" has_coverage)
if(has_coverage EQUAL -1)
    message(FATAL_ERROR \"Expected --coverage flag for Clang\")
endif()

message(STATUS \"SCHEMA mode Clang test passed\")
"
    )

    set(src_dir "${TEST_ROOT}/schema_clang/src")
    set(build_dir "${TEST_ROOT}/schema_clang/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SCHEMA mode Clang defaults failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ SCHEMA mode Clang defaults works correctly")
endfunction()

function(run_all_tests)
    message(STATUS "=== Gcov SCHEMA Mode Defaults Integration Tests ===")

    setup_test_environment()

    test_schema_defaults_gcc()
    test_schema_defaults_clang()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Gcov SCHEMA defaults tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Gcov SCHEMA defaults tests PASSED")
    endif()
endfunction()

run_all_tests()
