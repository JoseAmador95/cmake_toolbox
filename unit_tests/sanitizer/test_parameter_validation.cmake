# Test: Sanitizer_AddToTarget - Parameter Validation
# Validates error conditions and parameter validation

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/sanitizer_validation_test")

# Helper to test that a project configuration fails
function(test_project_fails DESCRIPTION SRC_DIR BUILD_DIR)
    message(STATUS "  Testing: ${DESCRIPTION}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${SRC_DIR}" -B "${BUILD_DIR}"
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

function(test_missing_target_fails)
    message(STATUS "Test 1: Sanitizer_AddToTarget without TARGET fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Sanitizer)

# Missing TARGET parameter
Sanitizer_AddToTarget(SCOPE PUBLIC)
"
    )

    set(src_dir "${TEST_ROOT}/missing_target/src")
    set(build_dir "${TEST_ROOT}/missing_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("Missing TARGET parameter" "${src_dir}" "${build_dir}")
endfunction()

function(test_missing_scope_fails)
    message(STATUS "Test 2: Sanitizer_AddToTarget without SCOPE fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Sanitizer)

add_library(mylib STATIC dummy.c)

# Missing SCOPE parameter
Sanitizer_AddToTarget(TARGET mylib)
"
    )

    set(src_dir "${TEST_ROOT}/missing_scope/src")
    set(build_dir "${TEST_ROOT}/missing_scope/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("Missing SCOPE parameter" "${src_dir}" "${build_dir}")
endfunction()

function(test_nonexistent_target_fails)
    message(STATUS "Test 3: Sanitizer_AddToTarget with non-existent target fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Sanitizer)

# Target doesn't exist
Sanitizer_AddToTarget(TARGET nonexistent_target SCOPE PUBLIC)
"
    )

    set(src_dir "${TEST_ROOT}/nonexistent_target/src")
    set(build_dir "${TEST_ROOT}/nonexistent_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("Non-existent target" "${src_dir}" "${build_dir}")
endfunction()

function(test_no_parameters_fails)
    message(STATUS "Test 4: Sanitizer_AddToTarget with no parameters fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Sanitizer)

# No parameters
Sanitizer_AddToTarget()
"
    )

    set(src_dir "${TEST_ROOT}/no_params/src")
    set(build_dir "${TEST_ROOT}/no_params/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("No parameters" "${src_dir}" "${build_dir}")
endfunction()

function(test_valid_scope_public)
    message(STATUS "Test 5: Sanitizer_AddToTarget with SCOPE PUBLIC succeeds")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

message(STATUS \"Sanitizer_AddToTarget with SCOPE PUBLIC succeeded\")
"
    )

    set(src_dir "${TEST_ROOT}/scope_public/src")
    set(build_dir "${TEST_ROOT}/scope_public/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SCOPE PUBLIC failed unexpectedly: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ SCOPE PUBLIC works correctly")
endfunction()

function(test_valid_scope_private)
    message(STATUS "Test 6: Sanitizer_AddToTarget with SCOPE PRIVATE succeeds")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PRIVATE)

message(STATUS \"Sanitizer_AddToTarget with SCOPE PRIVATE succeeded\")
"
    )

    set(src_dir "${TEST_ROOT}/scope_private/src")
    set(build_dir "${TEST_ROOT}/scope_private/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SCOPE PRIVATE failed unexpectedly: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ SCOPE PRIVATE works correctly")
endfunction()

function(test_valid_scope_interface)
    message(STATUS "Test 7: Sanitizer_AddToTarget with SCOPE INTERFACE succeeds")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Sanitizer)

add_library(mylib INTERFACE)
Sanitizer_AddToTarget(TARGET mylib SCOPE INTERFACE)

message(STATUS \"Sanitizer_AddToTarget with SCOPE INTERFACE succeeded\")
"
    )

    set(src_dir "${TEST_ROOT}/scope_interface/src")
    set(build_dir "${TEST_ROOT}/scope_interface/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SCOPE INTERFACE failed unexpectedly: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ SCOPE INTERFACE works correctly")
endfunction()

function(test_apply_environment_to_tests)
    message(STATUS "Test 8: Sanitizer_ApplyEnvironmentToTests applies test env")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CTest)
include(Sanitizer)

set(SANITIZER_ENV_VARS \"ASAN_OPTIONS=abort_on_error=1;UBSAN_OPTIONS=print_stacktrace=1\" CACHE STRING \"\" FORCE)

add_executable(mytest dummy.c)
add_test(NAME sanitizer_env_test COMMAND mytest)

Sanitizer_ApplyEnvironmentToTests(TESTS sanitizer_env_test)
get_test_property(sanitizer_env_test ENVIRONMENT configured_env)
string(REPLACE \"\\;\" \";\" configured_env_normalized \"\${configured_env}\")

if(NOT \"\${configured_env_normalized}\" STREQUAL \"\${SANITIZER_ENV_VARS}\")
    message(FATAL_ERROR \"Unexpected ENVIRONMENT for sanitizer_env_test: '\${configured_env}'\")
endif()

Sanitizer_ApplyEnvironmentToTests(
    TESTS sanitizer_env_test
    ENVIRONMENT \"LSAN_OPTIONS=verbosity=1\"
    APPEND
)
get_test_property(sanitizer_env_test ENVIRONMENT appended_env)
string(FIND \"\${appended_env}\" \"LSAN_OPTIONS=verbosity=1\" has_lsan)
if(has_lsan EQUAL -1)
    message(FATAL_ERROR \"APPEND did not add LSAN_OPTIONS. Got: '\${appended_env}'\")
endif()

message(STATUS \"Sanitizer_ApplyEnvironmentToTests works\")
"
    )

    set(src_dir "${TEST_ROOT}/apply_test_env/src")
    set(build_dir "${TEST_ROOT}/apply_test_env/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int main(void) { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Sanitizer_ApplyEnvironmentToTests failed unexpectedly: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Sanitizer_ApplyEnvironmentToTests works correctly")
endfunction()

function(test_deprecated_function)
    message(STATUS "Test 9: Deprecated target_add_sanitizer function works")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(Sanitizer)

add_library(mylib STATIC dummy.c)

# Use deprecated function
target_add_sanitizer(mylib PUBLIC)
"
    )

    set(src_dir "${TEST_ROOT}/deprecated/src")
    set(build_dir "${TEST_ROOT}/deprecated/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Deprecated function call failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Check for deprecation warning
    string(
        FIND "${output}${error}"
        "deprecated"
        has_deprecation
    )
    if(has_deprecation EQUAL -1)
        message(
            STATUS
            "  ⚠ Deprecated function did not emit deprecation warning (might be suppressed)"
        )
    else()
        message(STATUS "  ✓ Deprecated function works and emits deprecation warning")
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== Sanitizer_AddToTarget Parameter Validation Tests ===")

    setup_test_environment()

    test_missing_target_fails()
    test_missing_scope_fails()
    test_nonexistent_target_fails()
    test_no_parameters_fails()
    test_valid_scope_public()
    test_valid_scope_private()
    test_valid_scope_interface()
    test_apply_environment_to_tests()
    test_deprecated_function()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(
            FATAL_ERROR
            "Sanitizer parameter validation tests failed with ${ERROR_COUNT} error(s)"
        )
    else()
        message(STATUS "All Sanitizer parameter validation tests PASSED")
    endif()
endfunction()

run_all_tests()
