# Integration Test: Sanitizer build verification
# Actually builds and runs sanitized executables to verify flags work

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH "${REPO_ROOT}/cmake" ${CMAKE_MODULE_PATH})

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/integration_sanitizer_build")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_build_with_sanitizers)
    message(STATUS "Test 1: Build executable with AddressSanitizer")
    
    # Find a compiler that supports sanitizers
    find_program(CLANG_COMPILER clang)
    find_program(GCC_COMPILER gcc)
    
    if(CLANG_COMPILER)
        set(C_COMPILER ${CLANG_COMPILER})
        message(STATUS "  Using Clang: ${CLANG_COMPILER}")
    elseif(GCC_COMPILER)
        set(C_COMPILER ${GCC_COMPILER})
        message(STATUS "  Using GCC: ${GCC_COMPILER}")
    else()
        message(STATUS "  ⊘ No supported compiler found, skipping")
        return()
    endif()
    
    set(src_dir "${TEST_ROOT}/asan_build/src")
    set(build_dir "${TEST_ROOT}/asan_build/build")
    file(MAKE_DIRECTORY "${src_dir}")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
project(SanitizerBuildTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(ENABLE_SANITIZER_ADDRESS ON CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_UNDEFINED ON CACHE BOOL \"\" FORCE)
set(ENABLE_SANITIZER_LEAK OFF CACHE BOOL \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC lib.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

add_executable(mytest main.c)
target_link_libraries(mytest PRIVATE mylib)
")
    
    # Simple clean code (no bugs to detect)
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "
int lib_func(int x) {
    return x * 2;
}
")
    file(WRITE "${src_dir}/main.c" "
extern int lib_func(int x);
int main(void) {
    int result = lib_func(21);
    return result == 42 ? 0 : 1;
}
")
    
    # Configure
    execute_process(
        COMMAND ${CMAKE_COMMAND}
            -S "${src_dir}" -B "${build_dir}"
            -DCMAKE_C_COMPILER=${C_COMPILER}
        RESULT_VARIABLE config_result
        OUTPUT_VARIABLE config_output
        ERROR_VARIABLE config_error
    )
    
    if(NOT config_result EQUAL 0)
        message(STATUS "  ✗ Configuration failed: ${config_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    # Build
    execute_process(
        COMMAND ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )
    
    if(NOT build_result EQUAL 0)
        # Check if it's a missing runtime library issue (common in containers)
        string(FIND "${build_error}" "libclang_rt" has_clang_runtime_error)
        string(FIND "${build_error}" "cannot find" has_cannot_find)
        if(NOT has_clang_runtime_error EQUAL -1 OR NOT has_cannot_find EQUAL -1)
            message(STATUS "  ⊘ Sanitizer runtime libraries not installed, skipping")
            return()
        endif()
        message(STATUS "  ✗ Build failed: ${build_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    # Run the test (should pass - clean code)
    execute_process(
        COMMAND "${build_dir}/mytest"
        RESULT_VARIABLE run_result
        OUTPUT_VARIABLE run_output
        ERROR_VARIABLE run_error
    )
    
    if(NOT run_result EQUAL 0)
        message(STATUS "  ✗ Sanitized executable failed to run: ${run_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Sanitized build and run succeeded")
endfunction()

function(test_custom_flags_override)
    message(STATUS "Test 2: Custom sanitizer flags override")
    
    set(src_dir "${TEST_ROOT}/custom_flags/src")
    set(build_dir "${TEST_ROOT}/custom_flags/build")
    file(MAKE_DIRECTORY "${src_dir}")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
project(SanitizerCustomTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Override with custom flags
set(SANITIZER_COMPILE_FLAGS \"-fsanitize=address -fno-omit-frame-pointer\" CACHE STRING \"\" FORCE)
set(SANITIZER_LINK_FLAGS \"-fsanitize=address\" CACHE STRING \"\" FORCE)

include(Sanitizer)

add_library(mylib STATIC lib.c)
Sanitizer_AddToTarget(TARGET mylib SCOPE PUBLIC)

get_target_property(compile_opts mylib COMPILE_OPTIONS)
message(STATUS \"Custom flags applied: \${compile_opts}\")

# Verify custom flags are used
string(FIND \"\${compile_opts}\" \"fno-omit-frame-pointer\" has_custom)
if(has_custom EQUAL -1)
    message(FATAL_ERROR \"Custom flag -fno-omit-frame-pointer not found\")
endif()
")
    
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    
    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Custom flags test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ Custom sanitizer flags override works")
endfunction()

function(run_all_tests)
    message(STATUS "=== Sanitizer Build Integration Tests ===")
    
    setup_test_environment()
    
    test_build_with_sanitizers()
    test_custom_flags_override()
    
    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Sanitizer build tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Sanitizer build tests PASSED")
    endif()
endfunction()

run_all_tests()
