if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: Sanitizer_AddToTarget - Flag Combinations
# Validates different combinations of sanitizer options

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/sanitizer_flags_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_address_sanitizer_only)
    message(STATUS "Test 1: Only AddressSanitizer enabled")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Enable only address sanitizer
set(ENABLE_SANITIZER_ADDRESS ON CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK OFF CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

# Get compile options for verification
get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")
"
    )

    set(src_dir "${TEST_ROOT}/address_only/src")
    set(build_dir "${TEST_ROOT}/address_only/build")
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
        message(STATUS "  ✗ Address-only configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Address-only sanitizer configuration works")
endfunction()

function(test_undefined_sanitizer_only)
    message(STATUS "Test 2: Only UndefinedBehaviorSanitizer enabled")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Enable only undefined sanitizer
set(ENABLE_SANITIZER_ADDRESS OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED ON CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK OFF CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")
"
    )

    set(src_dir "${TEST_ROOT}/undefined_only/src")
    set(build_dir "${TEST_ROOT}/undefined_only/build")
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
        message(STATUS "  ✗ Undefined-only configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Undefined-only sanitizer configuration works")
endfunction()

function(test_leak_sanitizer_only)
    message(STATUS "Test 3: Only LeakSanitizer enabled")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Enable only leak sanitizer
set(ENABLE_SANITIZER_ADDRESS OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK ON CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")
"
    )

    set(src_dir "${TEST_ROOT}/leak_only/src")
    set(build_dir "${TEST_ROOT}/leak_only/build")
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
        message(STATUS "  ✗ Leak-only configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Leak-only sanitizer configuration works")
endfunction()

function(test_all_sanitizers)
    message(STATUS "Test 4: All sanitizers enabled (default)")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# All sanitizers enabled (default)
set(ENABLE_SANITIZER_ADDRESS ON CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED ON CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK ON CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")
"
    )

    set(src_dir "${TEST_ROOT}/all_sanitizers/src")
    set(build_dir "${TEST_ROOT}/all_sanitizers/build")
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
        message(STATUS "  ✗ All sanitizers configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ All sanitizers configuration works")
endfunction()

function(test_no_sanitizers)
    message(STATUS "Test 5: No sanitizers enabled")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# No sanitizers enabled
set(ENABLE_SANITIZER_ADDRESS OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED OFF CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK OFF CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

# Should succeed with no flags applied
get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")
"
    )

    set(src_dir "${TEST_ROOT}/no_sanitizers/src")
    set(build_dir "${TEST_ROOT}/no_sanitizers/build")
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
        message(STATUS "  ✗ No sanitizers configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ No sanitizers configuration works")
endfunction()

function(test_address_and_undefined)
    message(STATUS "Test 6: Address + Undefined sanitizers")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(ENABLE_SANITIZER_ADDRESS ON CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED ON CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK OFF CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")
"
    )

    set(src_dir "${TEST_ROOT}/address_undefined/src")
    set(build_dir "${TEST_ROOT}/address_undefined/build")
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
        message(STATUS "  ✗ Address+Undefined configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Address+Undefined sanitizer configuration works")
endfunction()

function(test_custom_compile_flags_override)
    message(STATUS "Test 7: Custom SANITIZER_COMPILE_FLAGS override")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Set custom compile flags - should override automatic detection
set(SANITIZER_COMPILE_FLAGS \"-fsanitize=address\" CACHE STRING \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC dummy.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

# Should use custom flags
get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Compile options: \${compile_opts}\")

# Verify custom flag is present
set(opts_str \"\${compile_opts}\")
string(FIND \"\${opts_str}\" \"-fsanitize=address\" has_custom)
if(has_custom EQUAL -1)
    message(FATAL_ERROR \"Custom compile flags not applied\")
endif()
"
    )

    set(src_dir "${TEST_ROOT}/custom_flags/src")
    set(build_dir "${TEST_ROOT}/custom_flags/build")
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
        message(STATUS "  ✗ Custom compile flags override failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Custom SANITIZER_COMPILE_FLAGS override works")
endfunction()

function(test_multiple_targets)
    message(STATUS "Test 8: Apply sanitizers to multiple targets")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(Sanitizer)

add_library(lib1 STATIC lib1.c)
add_library(lib2 STATIC lib2.c)
add_executable(exe main.c)

Sanitizer_AddToTarget(TARGET lib1 SCOPE PUBLIC)
Sanitizer_AddToTarget(TARGET lib2 SCOPE PRIVATE)
Sanitizer_AddToTarget(TARGET exe SCOPE PRIVATE)

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

    message(STATUS "  ✓ Multiple targets can be configured")
endfunction()

function(test_environment_vars_set)
    message(STATUS "Test 9: Environment variables are set on tests")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SanitizerTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(CTest)
include(Sanitizer)

add_executable(mytest dummy.c)
add_test(NAME sanitizer_runtime_test COMMAND mytest)
Sanitizer_ApplyEnvironmentToTests(
    TESTS sanitizer_runtime_test
    ENVIRONMENT \"ASAN_OPTIONS=detect_leaks=0\"
)

# Verify ENVIRONMENT property is set on test
get_test_property(sanitizer_runtime_test ENVIRONMENT env_vars)
if(NOT \"\${env_vars}\")
    message(FATAL_ERROR \"Test ENVIRONMENT property not set\")
endif()

# Should contain ASAN_OPTIONS
string(FIND \"\${env_vars}\" \"ASAN_OPTIONS\" has_asan)

if(has_asan EQUAL -1)
    message(FATAL_ERROR \"ASAN_OPTIONS not in ENVIRONMENT\")
endif()

message(STATUS \"Environment variables: \${env_vars}\")
"
    )

    set(src_dir "${TEST_ROOT}/env_vars/src")
    set(build_dir "${TEST_ROOT}/env_vars/build")
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
        message(STATUS "  ✗ Environment variables check failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Environment variables correctly set on tests")
endfunction()

function(run_all_tests)
    message(STATUS "=== Sanitizer_AddToTarget Flag Combinations Tests ===")

    setup_test_environment()

    test_address_sanitizer_only()
    test_undefined_sanitizer_only()
    test_leak_sanitizer_only()
    test_all_sanitizers()
    test_no_sanitizers()
    test_address_and_undefined()
    test_custom_compile_flags_override()
    test_multiple_targets()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Sanitizer flag combination tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Sanitizer flag combination tests PASSED")
    endif()
endfunction()

run_all_tests()
