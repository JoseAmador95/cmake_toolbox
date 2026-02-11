if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: CompileCommands_Trim
# Verifies trim behavior using generated compile_commands.json

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_compilecommands")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_trim_with_jq)
    message(STATUS "Test 1: Build executes trim target and validates transformed output")

    # Check if jq is available
    find_program(JQ_EXE jq)
    if(NOT JQ_EXE)
        message(STATUS "  ⊘ jq not found, skipping")
        return()
    endif()

    set(src_dir "${TEST_ROOT}/trim_jq/src")
    set(build_dir "${TEST_ROOT}/trim_jq/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(CompileCommands)

add_library(mylib STATIC lib.c)
target_compile_options(mylib PRIVATE -DFROM_INTEGRATION=1 -O2)

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_custom_target(run_trim DEPENDS \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
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

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}" --target run_trim
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    if(NOT build_result EQUAL 0)
        message(STATUS "  ✗ Building run_trim failed: ${build_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(trimmed_file "${build_dir}/trimmed/compile_commands.json")
    if(NOT EXISTS "${trimmed_file}")
        message(STATUS "  ✗ Trimmed output file not generated")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${trimmed_file}" trimmed_content)
    if(NOT trimmed_content MATCHES "-DFROM_INTEGRATION=1")
        message(STATUS "  ✗ Expected define flag missing from trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-O2")
        message(STATUS "  ✗ Optimization flag should have been removed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    message(STATUS "  ✓ CompileCommands_Trim executes real trim path and validates output")
endfunction()

function(test_trim_jq_not_found)
    message(STATUS "Test 2: CompileCommands_Trim handles missing jq")

    set(src_dir "${TEST_ROOT}/no_jq/src")
    set(build_dir "${TEST_ROOT}/no_jq/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsNoJqTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# Force jq to not be found
set(Jq_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)
set(Jq_FOUND FALSE CACHE BOOL \"\" FORCE)

include(CompileCommands)

# This should emit warning but not fail
CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_library(mylib STATIC lib.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
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
    string(
        FIND "${output}${error}"
        "jq"
        has_jq_mention
    )
    if(has_jq_mention EQUAL -1)
        message(STATUS "  ✗ Expected mention of jq in output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ CompileCommands handles missing jq gracefully")
endfunction()

function(run_all_tests)
    message(STATUS "=== CompileCommands Integration Tests ===")

    if(DEFINED CMAKE_TOOLBOX_TEST_GENERATOR)
        string(
            REGEX MATCH
            "(Visual Studio|Xcode|Ninja Multi-Config)"
            _multi_config_match
            "${CMAKE_TOOLBOX_TEST_GENERATOR}"
        )
        if(_multi_config_match)
            message(STATUS "  ⊘ Multi-config generator detected, skipping CompileCommands tests")
            return()
        endif()
    endif()

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
