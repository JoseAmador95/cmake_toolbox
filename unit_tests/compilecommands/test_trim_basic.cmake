# Test: CompileCommands_Trim - Basic functionality
# Validates basic trim operations

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH "${REPO_ROOT}/cmake" ${CMAKE_MODULE_PATH})

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/compilecommands_basic_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_trim_with_valid_inputs)
    message(STATUS "Test 1: CompileCommands_Trim with valid INPUT and OUTPUT")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(CompileCommands)

add_library(mylib STATIC dummy.c)

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed_compile_commands.json
)

message(STATUS \"CompileCommands_Trim configured successfully\")
")
    
    set(src_dir "${TEST_ROOT}/valid_inputs/src")
    set(build_dir "${TEST_ROOT}/valid_inputs/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    
    if(NOT result EQUAL 0)
        message(STATUS "  ✗ CompileCommands_Trim with valid inputs failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ CompileCommands_Trim with valid inputs succeeds")
endfunction()

function(test_trim_creates_output_directory)
    message(STATUS "Test 2: CompileCommands_Trim creates output directory if needed")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(CompileCommands)

add_library(mylib STATIC dummy.c)

# Output in nested directory that doesn't exist
CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/nested/deep/path/trimmed.json
)

# Check that parent directory was created
if(NOT EXISTS \"\${CMAKE_BINARY_DIR}/nested/deep/path\")
    message(FATAL_ERROR \"Output directory was not created\")
endif()

message(STATUS \"Output directory correctly created\")
")
    
    set(src_dir "${TEST_ROOT}/creates_dir/src")
    set(build_dir "${TEST_ROOT}/creates_dir/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    
    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Output directory creation test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    # Verify directory was created
    if(NOT EXISTS "${build_dir}/nested/deep/path")
        message(STATUS "  ✗ Output directory was not created")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ CompileCommands_Trim creates output directory")
endfunction()

function(test_trim_handles_missing_jq)
    message(STATUS "Test 3: CompileCommands_Trim handles missing jq gracefully")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Force jq to not be found by clearing results
set(Jq_FOUND FALSE CACHE BOOL \"\" FORCE)
set(Jq_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)

include(CompileCommands)

add_library(mylib STATIC dummy.c)

# This should emit a WARNING but not fail
CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed.json
)

message(STATUS \"CompileCommands_Trim completed (may have emitted warning about jq)\")
")
    
    set(src_dir "${TEST_ROOT}/missing_jq/src")
    set(build_dir "${TEST_ROOT}/missing_jq/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    
    # Should succeed even without jq (just emits warning)
    if(NOT result EQUAL 0)
        message(STATUS "  ✗ CompileCommands_Trim should not fail when jq is missing: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ CompileCommands_Trim handles missing jq gracefully")
endfunction()

function(test_deprecated_function)
    message(STATUS "Test 4: Deprecated compile_commands_trim function works")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(CompileCommands)

add_library(mylib STATIC dummy.c)

# Use deprecated function
compile_commands_trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed.json
)

message(STATUS \"Deprecated function completed\")
")
    
    set(src_dir "${TEST_ROOT}/deprecated/src")
    set(build_dir "${TEST_ROOT}/deprecated/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")
    
    execute_process(
        COMMAND ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
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
    string(FIND "${output}${error}" "deprecated" has_deprecation)
    if(has_deprecation EQUAL -1)
        message(STATUS "  ⚠ Deprecated function did not emit deprecation warning (might be suppressed)")
    else()
        message(STATUS "  ✓ Deprecated function works and emits deprecation warning")
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== CompileCommands_Trim Basic Tests ===")
    
    setup_test_environment()
    
    test_trim_with_valid_inputs()
    test_trim_creates_output_directory()
    test_trim_handles_missing_jq()
    test_deprecated_function()
    
    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "CompileCommands_Trim basic tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All CompileCommands_Trim basic tests PASSED")
    endif()
endfunction()

run_all_tests()
