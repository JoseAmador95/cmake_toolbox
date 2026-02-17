if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: ClangTidy_Configure
# Validates global clang-tidy configuration

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/clangtidy_configure_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_configure_status_on)
    message(STATUS "Test 1: ClangTidy_Configure(STATUS ON) succeeds")

    # Run in subprocess since it modifies cache variables
    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

ClangTidy_Configure(STATUS ON)

# Check that it didn't fail - actual clang-tidy may or may not be found
message(STATUS \"ClangTidy_Configure(STATUS ON) completed\")
"
    )

    set(src_dir "${TEST_ROOT}/status_on/src")
    set(build_dir "${TEST_ROOT}/status_on/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int main() { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ ClangTidy_Configure(STATUS ON) failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangTidy_Configure(STATUS ON) completed successfully")
endfunction()

function(test_configure_status_off)
    message(STATUS "Test 2: ClangTidy_Configure(STATUS OFF) clears config")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

# First enable, then disable
ClangTidy_Configure(STATUS ON)
ClangTidy_Configure(STATUS OFF)

# Verify cache variables are empty
if(NOT CMAKE_C_CLANG_TIDY STREQUAL \"\")
    message(FATAL_ERROR \"CMAKE_C_CLANG_TIDY should be empty after STATUS OFF, got '\${CMAKE_C_CLANG_TIDY}'\")
endif()

if(NOT CMAKE_CXX_CLANG_TIDY STREQUAL \"\")
    message(FATAL_ERROR \"CMAKE_CXX_CLANG_TIDY should be empty after STATUS OFF, got '\${CMAKE_CXX_CLANG_TIDY}'\")
endif()

message(STATUS \"ClangTidy_Configure(STATUS OFF) correctly cleared config\")
"
    )

    set(src_dir "${TEST_ROOT}/status_off/src")
    set(build_dir "${TEST_ROOT}/status_off/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int main() { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ ClangTidy_Configure(STATUS OFF) failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangTidy_Configure(STATUS OFF) correctly clears config")
endfunction()

function(test_configure_with_trim_option)
    message(STATUS "Test 3: ClangTidy_Configure with TRIM_COMPILE_COMMANDS option")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

# This should not fail when trim is enabled
ClangTidy_Configure(STATUS ON TRIM_COMPILE_COMMANDS)

message(STATUS \"ClangTidy_Configure with TRIM_COMPILE_COMMANDS completed\")
"
    )

    set(src_dir "${TEST_ROOT}/trim_option/src")
    set(build_dir "${TEST_ROOT}/trim_option/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int main() { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ ClangTidy_Configure with TRIM_COMPILE_COMMANDS failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangTidy_Configure with TRIM_COMPILE_COMMANDS works")
endfunction()

function(test_configure_idempotent)
    message(STATUS "Test 4: Multiple ClangTidy_Configure calls are idempotent")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

# Call multiple times - should not fail
ClangTidy_Configure(STATUS ON)
ClangTidy_Configure(STATUS ON)
ClangTidy_Configure(STATUS OFF)
ClangTidy_Configure(STATUS ON)

message(STATUS \"Multiple ClangTidy_Configure calls completed\")
"
    )

    set(src_dir "${TEST_ROOT}/idempotent/src")
    set(build_dir "${TEST_ROOT}/idempotent/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int main() { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Multiple ClangTidy_Configure calls failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Multiple ClangTidy_Configure calls are idempotent")
endfunction()

function(test_configure_without_status)
    message(STATUS "Test 5: ClangTidy_Configure without STATUS (default behavior)")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(ClangTidy)

# Without STATUS argument - should not enable (STATUS is empty/false)
ClangTidy_Configure()

# Should result in empty configs
if(NOT CMAKE_C_CLANG_TIDY STREQUAL \"\")
    message(FATAL_ERROR \"CMAKE_C_CLANG_TIDY should be empty without STATUS, got '\${CMAKE_C_CLANG_TIDY}'\")
endif()

message(STATUS \"ClangTidy_Configure without STATUS correctly does nothing\")
"
    )

    set(src_dir "${TEST_ROOT}/no_status/src")
    set(build_dir "${TEST_ROOT}/no_status/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int main() { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ ClangTidy_Configure without STATUS failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangTidy_Configure without STATUS works correctly")
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangTidy_Configure Tests ===")

    setup_test_environment()

    test_configure_status_on()
    test_configure_status_off()
    test_configure_with_trim_option()
    test_configure_idempotent()
    test_configure_without_status()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "ClangTidy_Configure tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All ClangTidy_Configure tests PASSED")
    endif()
endfunction()

run_all_tests()
