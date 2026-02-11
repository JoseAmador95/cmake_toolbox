if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: Gcov compiler compatibility
# Verifies coverage flags work with both GCC and Clang

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_gcov_compiler")

set(_exe_suffix "")
if(WIN32)
    set(_exe_suffix ".exe")
endif()

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_build_with_coverage_gcc)
    message(STATUS "Test 1: Build with coverage using GCC")

    # Find GCC
    find_program(GCC_C_COMPILER gcc)
    find_program(GCC_CXX_COMPILER g++)

    if(NOT GCC_C_COMPILER OR NOT GCC_CXX_COMPILER)
        message(STATUS "  ⊘ GCC not found, skipping")
        return()
    endif()

    set(src_dir "${TEST_ROOT}/gcc_build/src")
    set(build_dir "${TEST_ROOT}/gcc_build/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovGccTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)

add_executable(mytest main.c)
target_link_libraries(mytest PRIVATE mylib)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")
    file(
        WRITE "${src_dir}/main.c"
        "extern int lib_func(void); int main(void) { return lib_func() != 42; }"
    )

    # Configure with GCC
    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
            -DCMAKE_C_COMPILER=${GCC_C_COMPILER}
        RESULT_VARIABLE config_result
        OUTPUT_VARIABLE config_output
        ERROR_VARIABLE config_error
    )

    if(NOT config_result EQUAL 0)
        message(STATUS "  ✗ GCC configuration failed: ${config_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Build
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    if(NOT build_result EQUAL 0)
        message(STATUS "  ✗ GCC build failed: ${build_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Verify .gcno files were created (coverage instrumentation)
    file(GLOB_RECURSE gcno_files "${build_dir}/*.gcno")
    list(LENGTH gcno_files gcno_count)

    if(gcno_count EQUAL 0)
        message(STATUS "  ✗ No .gcno files created - coverage instrumentation missing")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT EXISTS "${build_dir}/mytest${_exe_suffix}")
        message(STATUS "  ✗ Expected test executable not found: ${build_dir}/mytest${_exe_suffix}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ GCC build with coverage succeeded (${gcno_count} .gcno files)")
endfunction()

function(test_build_with_coverage_clang)
    message(STATUS "Test 2: Build with coverage using Clang")

    # Find Clang
    find_program(CLANG_C_COMPILER clang)
    find_program(CLANG_CXX_COMPILER clang++)

    if(NOT CLANG_C_COMPILER OR NOT CLANG_CXX_COMPILER)
        message(STATUS "  ⊘ Clang not found, skipping")
        return()
    endif()

    set(src_dir "${TEST_ROOT}/clang_build/src")
    set(build_dir "${TEST_ROOT}/clang_build/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovClangTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)

add_executable(mytest main.c)
target_link_libraries(mytest PRIVATE mylib)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")
    file(
        WRITE "${src_dir}/main.c"
        "extern int lib_func(void); int main(void) { return lib_func() != 42; }"
    )

    # Configure with Clang
    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
            -DCMAKE_C_COMPILER=${CLANG_C_COMPILER}
        RESULT_VARIABLE config_result
        OUTPUT_VARIABLE config_output
        ERROR_VARIABLE config_error
    )

    if(NOT config_result EQUAL 0)
        message(STATUS "  ✗ Clang configuration failed: ${config_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Build
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    if(NOT build_result EQUAL 0)
        # Check if it's a missing runtime library issue
        string(
            FIND "${build_error}"
            "libclang_rt"
            has_runtime_error
        )
        if(NOT has_runtime_error EQUAL -1)
            message(STATUS "  ⊘ Clang runtime libraries not installed, skipping")
            return()
        endif()
        message(STATUS "  ✗ Clang build failed: ${build_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Clang with --coverage also produces .gcno files (gcov-compatible)
    file(GLOB_RECURSE gcno_files "${build_dir}/*.gcno")
    list(LENGTH gcno_files gcno_count)

    if(gcno_count EQUAL 0)
        message(STATUS "  ✗ No .gcno files created for Clang build")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT EXISTS "${build_dir}/mytest${_exe_suffix}")
        message(
            STATUS
            "  ✗ Expected Clang test executable not found: ${build_dir}/mytest${_exe_suffix}"
        )
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Clang build with coverage succeeded (${gcno_count} .gcno files)")
endfunction()

function(run_all_tests)
    message(STATUS "=== Gcov Compiler Compatibility Integration Tests ===")

    setup_test_environment()

    test_build_with_coverage_gcc()
    test_build_with_coverage_clang()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Gcov compiler tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Gcov compiler tests PASSED")
    endif()
endfunction()

run_all_tests()
