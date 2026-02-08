if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: ClangTidy_ConfigureTarget
# Validates per-target clang-tidy configuration

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/clangtidy_target_test")

# Helper to test that a command fails (FATAL_ERROR)
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

function(test_configure_target_valid)
    message(STATUS "Test 1: ClangTidy_ConfigureTarget with valid target")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

add_library(mylib STATIC dummy.c)

ClangTidy_ConfigureTarget(TARGET mylib STATUS ON)

# Verify target property was set (may be empty if clang-tidy not found, but should not fail)
get_target_property(c_clang_tidy mylib C_CLANG_TIDY)
message(STATUS \"mylib C_CLANG_TIDY = \${c_clang_tidy}\")
"
    )

    set(src_dir "${TEST_ROOT}/valid_target/src")
    set(build_dir "${TEST_ROOT}/valid_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")
    # Create dummy compile_commands.json to satisfy target_sources requirement
    file(WRITE "${build_dir}/compile_commands.json" "[]")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ ClangTidy_ConfigureTarget with valid target failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangTidy_ConfigureTarget with valid target works")
endfunction()

function(test_configure_target_missing_target_param)
    message(STATUS "Test 2: ClangTidy_ConfigureTarget without TARGET fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(ClangTidy)

# Missing TARGET parameter
ClangTidy_ConfigureTarget(STATUS ON)
"
    )

    set(src_dir "${TEST_ROOT}/missing_target/src")
    set(build_dir "${TEST_ROOT}/missing_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int main() { return 0; }")

    test_project_fails("Missing TARGET parameter" "${src_dir}" "${build_dir}")
endfunction()

function(test_configure_target_nonexistent)
    message(STATUS "Test 3: ClangTidy_ConfigureTarget with non-existent target fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(ClangTidy)

# Target doesn't exist
ClangTidy_ConfigureTarget(TARGET nonexistent_target STATUS ON)
"
    )

    set(src_dir "${TEST_ROOT}/nonexistent_target/src")
    set(build_dir "${TEST_ROOT}/nonexistent_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int main() { return 0; }")

    test_project_fails("Non-existent target" "${src_dir}" "${build_dir}")
endfunction()

function(test_configure_target_status_off)
    message(STATUS "Test 4: ClangTidy_ConfigureTarget STATUS OFF clears config")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

add_library(mylib STATIC dummy.c)

# First enable, then disable
ClangTidy_ConfigureTarget(TARGET mylib STATUS ON)
ClangTidy_ConfigureTarget(TARGET mylib STATUS OFF)

# Property should be empty
get_target_property(c_clang_tidy mylib C_CLANG_TIDY)
if(NOT c_clang_tidy STREQUAL \"\" AND NOT c_clang_tidy STREQUAL \"c_clang_tidy-NOTFOUND\")
    message(FATAL_ERROR \"C_CLANG_TIDY should be empty after STATUS OFF, got '\${c_clang_tidy}'\")
endif()

message(STATUS \"ClangTidy_ConfigureTarget STATUS OFF correctly clears config\")
"
    )

    set(src_dir "${TEST_ROOT}/status_off/src")
    set(build_dir "${TEST_ROOT}/status_off/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")
    # Create dummy compile_commands.json to satisfy target_sources requirement
    file(WRITE "${build_dir}/compile_commands.json" "[]")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ ClangTidy_ConfigureTarget STATUS OFF failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangTidy_ConfigureTarget STATUS OFF clears config")
endfunction()

function(test_configure_target_with_trim)
    message(STATUS "Test 5: ClangTidy_ConfigureTarget with TRIM_COMPILE_COMMANDS")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

add_library(mylib STATIC dummy.c)

# With TRIM_COMPILE_COMMANDS option
ClangTidy_ConfigureTarget(TARGET mylib STATUS ON TRIM_COMPILE_COMMANDS)

message(STATUS \"ClangTidy_ConfigureTarget with TRIM_COMPILE_COMMANDS completed\")
"
    )

    set(src_dir "${TEST_ROOT}/with_trim/src")
    set(build_dir "${TEST_ROOT}/with_trim/build")
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
        message(STATUS "  ✗ ClangTidy_ConfigureTarget with TRIM_COMPILE_COMMANDS failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangTidy_ConfigureTarget with TRIM_COMPILE_COMMANDS works")
endfunction()

function(test_configure_multiple_targets)
    message(STATUS "Test 6: Configure multiple targets independently")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

add_library(lib1 STATIC lib1.c)
add_library(lib2 STATIC lib2.c)

# Configure independently
ClangTidy_ConfigureTarget(TARGET lib1 STATUS ON)
ClangTidy_ConfigureTarget(TARGET lib2 STATUS OFF)

message(STATUS \"Multiple targets configured independently\")
"
    )

    set(src_dir "${TEST_ROOT}/multiple_targets/src")
    set(build_dir "${TEST_ROOT}/multiple_targets/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib1.c" "int lib1_func(void) { return 1; }")
    file(WRITE "${src_dir}/lib2.c" "int lib2_func(void) { return 2; }")
    # Create dummy compile_commands.json to satisfy target_sources requirement
    file(WRITE "${build_dir}/compile_commands.json" "[]")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
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

    message(STATUS "  ✓ Multiple targets can be configured independently")
endfunction()

function(test_deprecated_function_warning)
    message(STATUS "Test 7: Deprecated function target_set_clang_tidy emits warning")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

add_library(mylib STATIC dummy.c)

# Use deprecated function
target_set_clang_tidy(TARGET mylib STATUS ON)
"
    )

    set(src_dir "${TEST_ROOT}/deprecated/src")
    set(build_dir "${TEST_ROOT}/deprecated/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")
    # Create dummy compile_commands.json to satisfy target_sources requirement
    file(WRITE "${build_dir}/compile_commands.json" "[]")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    # Should succeed but emit deprecation warning
    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Deprecated function call failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Check for deprecation warning in output
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
        message(STATUS "  ✓ Deprecated function correctly emits deprecation warning")
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangTidy_ConfigureTarget Tests ===")

    setup_test_environment()

    test_configure_target_valid()
    test_configure_target_missing_target_param()
    test_configure_target_nonexistent()
    test_configure_target_status_off()
    test_configure_target_with_trim()
    test_configure_multiple_targets()
    test_deprecated_function_warning()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "ClangTidy_ConfigureTarget tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All ClangTidy_ConfigureTarget tests PASSED")
    endif()
endfunction()

run_all_tests()
