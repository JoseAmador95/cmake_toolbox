if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: Gcov_AddToTarget Error Handling
# Validates error conditions and parameter validation

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcov_error_test")
TestHelpers_GetConfigureArgs(_GCOV_CONFIGURE_ARGS)

# Helper to test that a project configuration fails
function(test_project_fails DESCRIPTION SRC_DIR BUILD_DIR)
    message(STATUS "  Testing: ${DESCRIPTION}")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${SRC_DIR}" -B "${BUILD_DIR}" ${configure_args}
        RESULT_VARIABLE cmd_result
        OUTPUT_VARIABLE cmd_output
        ERROR_VARIABLE cmd_error
        OUTPUT_QUIET
        ERROR_QUIET
    )

    if(cmd_result EQUAL 0)
        message(STATUS "    ✗ ${DESCRIPTION} - should have failed but succeeded")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    else()
        message(STATUS "    ✓ ${DESCRIPTION} - correctly failed")
    endif()
endfunction()

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_nonexistent_target_fails)
    message(STATUS "Test 1: Gcov_AddToTarget with non-existent target fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Gcov)

# Target doesn't exist
Gcov_AddToTarget(nonexistent_target PUBLIC)
"
    )

    set(src_dir "${TEST_ROOT}/nonexistent_target/src")
    set(build_dir "${TEST_ROOT}/nonexistent_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("Non-existent target" "${src_dir}" "${build_dir}")
endfunction()

function(test_valid_target_succeeds)
    message(STATUS "Test 2: Gcov_AddToTarget with valid target succeeds")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Gcov)

add_library(mylib STATIC dummy.c)
Gcov_AddToTarget(mylib PUBLIC)

message(STATUS \"Gcov_AddToTarget with valid target succeeded\")
"
    )

    set(src_dir "${TEST_ROOT}/valid_target/src")
    set(build_dir "${TEST_ROOT}/valid_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Valid target unexpectedly failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Valid target succeeds")
endfunction()

function(test_multiple_targets)
    message(STATUS "Test 3: Gcov_AddToTarget works on multiple targets")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Gcov)

add_library(lib1 STATIC lib1.c)
add_library(lib2 STATIC lib2.c)
add_executable(exe main.c)

Gcov_AddToTarget(lib1 PUBLIC)
Gcov_AddToTarget(lib2 PRIVATE)
Gcov_AddToTarget(exe PRIVATE)

message(STATUS \"Multiple targets configured successfully\")
"
    )

    set(src_dir "${TEST_ROOT}/multiple_targets/src")
    set(build_dir "${TEST_ROOT}/multiple_targets/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib1.c" "int lib1_func(void) { return 1; }")
    file(WRITE "${src_dir}/lib2.c" "int lib2_func(void) { return 2; }")
    file(WRITE "${src_dir}/main.c" "int main(void) { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Multiple targets configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Multiple targets can be configured")
endfunction()

function(test_custom_flags_override)
    message(STATUS "Test 4: Custom GCOV_COMPILE_FLAGS override works")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Set custom flags before including module
set(GCOV_COMPILE_FLAGS \"--coverage\" CACHE STRING \"\" FORCE)
set(GCOV_LINK_FLAGS \"--coverage\" CACHE STRING \"\" FORCE)

include(Gcov)

add_library(mylib STATIC dummy.c)
Gcov_AddToTarget(mylib PUBLIC)

# Verify flags were applied
get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")
"
    )

    set(src_dir "${TEST_ROOT}/custom_flags/src")
    set(build_dir "${TEST_ROOT}/custom_flags/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Custom flags override failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Custom GCOV_COMPILE_FLAGS override works")
endfunction()

function(run_all_tests)
    message(STATUS "=== Gcov_AddToTarget Error Handling Tests ===")

    setup_test_environment()

    test_nonexistent_target_fails()
    test_valid_target_succeeds()
    test_multiple_targets()
    test_custom_flags_override()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Gcov error handling tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Gcov error handling tests PASSED")
    endif()
endfunction()

run_all_tests()
