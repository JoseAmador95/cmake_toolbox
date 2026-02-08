if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: GcovrSchema_GenerateConfigFile
# Validates that config files are correctly generated from schema

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(GcovrSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcovrschema_generate_test")

# Helper to test that a command fails (FATAL_ERROR)
function(test_command_fails DESCRIPTION COMMAND_STRING)
    message(STATUS "  Testing: ${DESCRIPTION}")

    string(MD5 temp_script_id "${DESCRIPTION};${COMMAND_STRING}")
    set(temp_script "${TEST_ROOT}/temp_test_${temp_script_id}.cmake")
    file(WRITE "${temp_script}" "${COMMAND_STRING}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${temp_script}"
        RESULT_VARIABLE cmd_result
        OUTPUT_VARIABLE cmd_output
        ERROR_VARIABLE cmd_error
        OUTPUT_QUIET
        ERROR_QUIET
    )

    file(REMOVE "${temp_script}")

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

function(test_generate_without_schema_version_fails)
    message(STATUS "Test 1: GenerateConfigFile without schema version fails")

    test_command_fails(
        "GenerateConfigFile without _GCOVR_SCHEMA_VERSION"
        "cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)
# Intentionally not setting _GCOVR_SCHEMA_VERSION
GcovrSchema_GenerateConfigFile(\"${TEST_ROOT}/output.cfg\")"
    )
endfunction()

function(test_generate_creates_file)
    message(STATUS "Test 2: GenerateConfigFile creates output file")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

# Set schema version (normally done by DetectVersion)
set(_GCOVR_SCHEMA_VERSION \"7.0\" CACHE INTERNAL \"\")

# Set defaults
GcovrSchema_SetDefaults(\"7.0\")

# Generate config file
set(config_file \"${TEST_ROOT}/generated_config.cfg\")
GcovrSchema_GenerateConfigFile(\"\${config_file}\")

# Verify file was created
if(NOT EXISTS \"\${config_file}\")
    message(FATAL_ERROR \"Config file was not created: \${config_file}\")
endif()
"
    )

    set(script_file "${TEST_ROOT}/test_create_file.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Config file generation failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Verify file exists
    if(NOT EXISTS "${TEST_ROOT}/generated_config.cfg")
        message(STATUS "  ✗ Config file does not exist after generation")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Config file successfully created")
endfunction()

function(test_generate_creates_directories)
    message(STATUS "Test 3: GenerateConfigFile creates parent directories")

    set(nested_path "${TEST_ROOT}/deep/nested/path/config.cfg")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

set(_GCOVR_SCHEMA_VERSION \"7.0\" CACHE INTERNAL \"\")
GcovrSchema_SetDefaults(\"7.0\")

GcovrSchema_GenerateConfigFile(\"${nested_path}\")

if(NOT EXISTS \"${nested_path}\")
    message(FATAL_ERROR \"Config file was not created in nested path\")
endif()
"
    )

    set(script_file "${TEST_ROOT}/test_nested_dirs.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Nested directory creation failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Parent directories correctly created")
endfunction()

function(test_config_contains_expected_keys)
    message(STATUS "Test 4: Generated config contains expected gcovr keys")

    set(config_file "${TEST_ROOT}/keys_test.cfg")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

set(_GCOVR_SCHEMA_VERSION \"7.0\" CACHE INTERNAL \"\")
GcovrSchema_SetDefaults(\"7.0\")

GcovrSchema_GenerateConfigFile(\"${config_file}\")
"
    )

    set(script_file "${TEST_ROOT}/test_keys.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Config generation failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Read and check config content
    if(EXISTS "${config_file}")
        file(READ "${config_file}" config_content)

        # Check for expected gcovr config keys (format varies by version)
        string(
            FIND "${config_content}"
            "html"
            has_html
        )
        string(
            FIND "${config_content}"
            "print-summary"
            has_summary
        )

        if(has_html EQUAL -1)
            message(STATUS "  ✗ Config missing 'html' related key")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()

        message(STATUS "  ✓ Config contains expected gcovr configuration keys")
    else()
        message(STATUS "  ✗ Config file not found for content check")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_config_respects_cache_values)
    message(STATUS "Test 5: Generated config uses cache variable values")

    set(config_file "${TEST_ROOT}/custom_values.cfg")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

set(_GCOVR_SCHEMA_VERSION \"7.0\" CACHE INTERNAL \"\")
GcovrSchema_SetDefaults(\"7.0\")

# Override with custom values
set(GCOVR_HTML_TITLE \"Custom Test Title\" CACHE STRING \"\" FORCE)
set(GCOVR_FAIL_UNDER_LINE \"75\" CACHE STRING \"\" FORCE)

GcovrSchema_GenerateConfigFile(\"${config_file}\")
"
    )

    set(script_file "${TEST_ROOT}/test_custom_values.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Config with custom values failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Read config and verify custom value is present
    if(EXISTS "${config_file}")
        file(READ "${config_file}" config_content)

        string(
            FIND "${config_content}"
            "Custom Test Title"
            has_title
        )
        if(has_title EQUAL -1)
            message(STATUS "  ✗ Custom title not found in config")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()

        message(STATUS "  ✓ Config correctly uses custom cache values")
    else()
        message(STATUS "  ✗ Config file not found")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== GcovrSchema_GenerateConfigFile Tests ===")

    setup_test_environment()

    test_generate_without_schema_version_fails()
    test_generate_creates_file()
    test_generate_creates_directories()
    test_config_contains_expected_keys()
    test_config_respects_cache_values()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(
            FATAL_ERROR
            "GcovrSchema GenerateConfigFile tests failed with ${ERROR_COUNT} error(s)"
        )
    else()
        message(STATUS "All GcovrSchema GenerateConfigFile tests PASSED")
    endif()
endfunction()

run_all_tests()
