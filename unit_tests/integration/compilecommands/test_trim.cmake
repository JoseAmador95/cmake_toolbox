# Integration Test: CompileCommands_Trim
# Verifies compile_commands.json trimming with jq

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH "${REPO_ROOT}/cmake" ${CMAKE_MODULE_PATH})

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/integration_compilecommands")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_trim_with_jq)
    message(STATUS "Test 1: CompileCommands_Trim with jq available")
    
    # Check if jq is available
    find_program(JQ_EXE jq)
    if(NOT JQ_EXE)
        message(STATUS "  ⊘ jq not found, skipping")
        return()
    endif()
    
    set(src_dir "${TEST_ROOT}/trim_jq/src")
    set(build_dir "${TEST_ROOT}/trim_jq/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")
    
    # Create a sample compile_commands.json
    file(WRITE "${build_dir}/compile_commands.json" "[
  {
    \"directory\": \"/build\",
    \"command\": \"gcc -I/include -DFOO=1 -o lib.o -c lib.c\",
    \"file\": \"lib.c\"
  }
]")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(CompileCommands)

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

# Verify output directory was created
if(NOT EXISTS \"\${CMAKE_BINARY_DIR}/trimmed\")
    message(FATAL_ERROR \"Output directory not created\")
endif()

message(STATUS \"CompileCommands_Trim completed\")
add_library(mylib STATIC lib.c)
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
        message(STATUS "  ✗ Trim with jq failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    message(STATUS "  ✓ CompileCommands_Trim with jq works")
endfunction()

function(test_trim_jq_not_found)
    message(STATUS "Test 2: CompileCommands_Trim handles missing jq")
    
    set(src_dir "${TEST_ROOT}/no_jq/src")
    set(build_dir "${TEST_ROOT}/no_jq/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")
    
    file(WRITE "${build_dir}/compile_commands.json" "[]")
    
    set(test_script "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsNoJqTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Force jq to not be found
set(JQ_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)
set(JQ_FOUND FALSE CACHE BOOL \"\" FORCE)

include(CompileCommands)

# This should emit warning but not fail
CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_library(mylib STATIC lib.c)
message(STATUS \"CompileCommands handled missing jq gracefully\")
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
        message(STATUS "  ✗ Should handle missing jq gracefully: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    # Check for warning about jq
    string(FIND "${output}${error}" "jq" has_jq_mention)
    if(has_jq_mention EQUAL -1)
        message(STATUS "  ⚠ Expected mention of jq in output")
    endif()
    
    message(STATUS "  ✓ CompileCommands handles missing jq gracefully")
endfunction()

function(run_all_tests)
    message(STATUS "=== CompileCommands Integration Tests ===")
    
    setup_test_environment()
    
    test_trim_with_jq()
    test_trim_jq_not_found()
    
    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "CompileCommands tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All CompileCommands tests PASSED")
    endif()
endfunction()

run_all_tests()
