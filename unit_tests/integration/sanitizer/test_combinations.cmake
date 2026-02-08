if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: Sanitizer combinations
# Verifies different sanitizer combinations work correctly

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_sanitizer_combos")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

# Helper to run a sanitizer configuration test
function(
    test_sanitizer_combo
    NAME
    ASAN
    UBSAN
    LSAN
    EXPECTED_FLAGS
)
    message(STATUS "Testing: ${NAME}")

    set(src_dir "${TEST_ROOT}/${NAME}/src")
    set(build_dir "${TEST_ROOT}/${NAME}/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(ENABLE_SANITIZER_ADDRESS ${ASAN} CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED ${UBSAN} CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK ${LSAN} CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC lib.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"COMPILE_OPTIONS: \${compile_opts}\")
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ ${NAME} configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Check for expected flags in output
    foreach(flag ${EXPECTED_FLAGS})
        string(
            FIND "${output}"
            "${flag}"
            has_flag
        )
        if(has_flag EQUAL -1)
            message(STATUS "  ✗ ${NAME}: Expected flag '${flag}' not found")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        endif()
    endforeach()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    message(STATUS "  ✓ ${NAME} configured correctly")
endfunction()

function(test_asan_only)
    test_sanitizer_combo(
        "asan_only"
        ON OFF OFF
        "address"
    )
endfunction()

function(test_ubsan_only)
    test_sanitizer_combo(
        "ubsan_only"
        OFF ON OFF
        "undefined"
    )
endfunction()

function(test_lsan_only)
    test_sanitizer_combo(
        "lsan_only"
        OFF OFF ON
        "leak"
    )
endfunction()

function(test_all_sanitizers)
    test_sanitizer_combo(
        "all_sanitizers"
        ON ON ON
        "address;undefined;leak"
    )
endfunction()

function(test_no_sanitizers)
    message(STATUS "Testing: no_sanitizers")

    set(src_dir "${TEST_ROOT}/no_sanitizers/src")
    set(build_dir "${TEST_ROOT}/no_sanitizers/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(ENABLE_SANITIZER_ADDRESS OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK OFF CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC lib.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"COMPILE_OPTIONS: \${compile_opts}\")

# With all disabled, should have no fsanitize flags
string(FIND \"\${compile_opts}\" \"fsanitize\" has_sanitize)
if(NOT has_sanitize EQUAL -1)
    message(FATAL_ERROR \"Should not have fsanitize flags when all sanitizers disabled\")
endif()
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ no_sanitizers test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ no_sanitizers correctly has no flags")
endfunction()

function(run_all_tests)
    message(STATUS "=== Sanitizer Combinations Integration Tests ===")

    setup_test_environment()

    test_asan_only()
    test_ubsan_only()
    test_lsan_only()
    test_all_sanitizers()
    test_no_sanitizers()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Sanitizer combination tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Sanitizer combination tests PASSED")
    endif()
endfunction()

run_all_tests()
