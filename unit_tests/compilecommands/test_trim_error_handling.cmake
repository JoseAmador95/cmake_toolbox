# Test: CompileCommands_Trim - Error handling
# Validates error conditions and parameter validation

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/compilecommands_error_test")

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

function(test_missing_input_fails)
    message(STATUS "Test 1: CompileCommands_Trim without INPUT fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

add_library(mylib STATIC dummy.c)

# Missing INPUT parameter
CompileCommands_Trim(
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed.json
)
"
    )

    set(src_dir "${TEST_ROOT}/missing_input/src")
    set(build_dir "${TEST_ROOT}/missing_input/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("Missing INPUT parameter" "${src_dir}" "${build_dir}")
endfunction()

function(test_missing_output_fails)
    message(STATUS "Test 2: CompileCommands_Trim without OUTPUT fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

add_library(mylib STATIC dummy.c)

# Missing OUTPUT parameter
CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
)
"
    )

    set(src_dir "${TEST_ROOT}/missing_output/src")
    set(build_dir "${TEST_ROOT}/missing_output/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("Missing OUTPUT parameter" "${src_dir}" "${build_dir}")
endfunction()

function(test_missing_both_params_fails)
    message(STATUS "Test 3: CompileCommands_Trim without any parameters fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

add_library(mylib STATIC dummy.c)

# No parameters at all
CompileCommands_Trim()
"
    )

    set(src_dir "${TEST_ROOT}/no_params/src")
    set(build_dir "${TEST_ROOT}/no_params/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("No parameters" "${src_dir}" "${build_dir}")
endfunction()

function(test_empty_input_fails)
    message(STATUS "Test 4: CompileCommands_Trim with empty INPUT fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

add_library(mylib STATIC dummy.c)

# Empty INPUT
CompileCommands_Trim(
    INPUT \"\"
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed.json
)
"
    )

    set(src_dir "${TEST_ROOT}/empty_input/src")
    set(build_dir "${TEST_ROOT}/empty_input/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("Empty INPUT parameter" "${src_dir}" "${build_dir}")
endfunction()

function(test_empty_output_fails)
    message(STATUS "Test 5: CompileCommands_Trim with empty OUTPUT fails")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

add_library(mylib STATIC dummy.c)

# Empty OUTPUT
CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \"\"
)
"
    )

    set(src_dir "${TEST_ROOT}/empty_output/src")
    set(build_dir "${TEST_ROOT}/empty_output/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    test_project_fails("Empty OUTPUT parameter" "${src_dir}" "${build_dir}")
endfunction()

function(test_unknown_parameters_ignored)
    message(STATUS "Test 6: Unknown parameters are silently ignored")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
include(CompileCommands)

add_library(mylib STATIC dummy.c)

# With unknown parameter - should be ignored (cmake_parse_arguments behavior)
CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed.json
    UNKNOWN_PARAM somevalue
)

message(STATUS \"Unknown parameters were ignored\")
"
    )

    set(src_dir "${TEST_ROOT}/unknown_params/src")
    set(build_dir "${TEST_ROOT}/unknown_params/build")
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

    # Unknown parameters are silently ignored by cmake_parse_arguments
    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Unknown parameters caused failure: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Unknown parameters are silently ignored (cmake_parse_arguments behavior)")
endfunction()

function(run_all_tests)
    message(STATUS "=== CompileCommands_Trim Error Handling Tests ===")

    setup_test_environment()

    test_missing_input_fails()
    test_missing_output_fails()
    test_missing_both_params_fails()
    test_empty_input_fails()
    test_empty_output_fails()
    test_unknown_parameters_ignored()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(
            FATAL_ERROR
            "CompileCommands_Trim error handling tests failed with ${ERROR_COUNT} error(s)"
        )
    else()
        message(STATUS "All CompileCommands_Trim error handling tests PASSED")
    endif()
endfunction()

run_all_tests()
