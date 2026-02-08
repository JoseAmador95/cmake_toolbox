# Test: CMockSchema_GenerateConfigFile
# Validates that YAML config files are correctly generated from schema

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(CMockSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/cmockschema_generate_test")

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
        "GenerateConfigFile without _CMOCK_SCHEMA_VERSION"
        "cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)
# Intentionally not setting _CMOCK_SCHEMA_VERSION
CMockSchema_GenerateConfigFile(\"${TEST_ROOT}/output.yml\")"
    )
endfunction()

function(test_generate_creates_file)
    message(STATUS "Test 2: GenerateConfigFile creates output file")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

# Set schema version (normally done by DetectVersion)
set(_CMOCK_SCHEMA_VERSION \"2.6\" CACHE INTERNAL \"\")

# Set defaults
CMockSchema_SetDefaults(\"2.6\")

# Generate config file
set(config_file \"${TEST_ROOT}/generated_config.yml\")
CMockSchema_GenerateConfigFile(\"\${config_file}\")

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
    if(NOT EXISTS "${TEST_ROOT}/generated_config.yml")
        message(STATUS "  ✗ Config file does not exist after generation")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Config file successfully created")
endfunction()

function(test_generate_creates_directories)
    message(STATUS "Test 3: GenerateConfigFile creates parent directories")

    set(nested_path "${TEST_ROOT}/deep/nested/path/config.yml")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

set(_CMOCK_SCHEMA_VERSION \"2.6\" CACHE INTERNAL \"\")
CMockSchema_SetDefaults(\"2.6\")

CMockSchema_GenerateConfigFile(\"${nested_path}\")

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

function(test_yaml_contains_cmock_key)
    message(STATUS "Test 4: Generated YAML contains :cmock: key")

    set(config_file "${TEST_ROOT}/yaml_keys_test.yml")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

set(_CMOCK_SCHEMA_VERSION \"2.6\" CACHE INTERNAL \"\")
CMockSchema_SetDefaults(\"2.6\")

CMockSchema_GenerateConfigFile(\"${config_file}\")
"
    )

    set(script_file "${TEST_ROOT}/test_yaml_keys.cmake")
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

    # Read and check YAML content
    if(EXISTS "${config_file}")
        file(READ "${config_file}" yaml_content)

        # Check for :cmock: key (YAML Ruby style)
        string(
            FIND "${yaml_content}"
            ":cmock:"
            has_cmock_key
        )

        if(has_cmock_key EQUAL -1)
            message(STATUS "  ✗ YAML missing ':cmock:' key")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()

        message(STATUS "  ✓ YAML contains ':cmock:' key")
    else()
        message(STATUS "  ✗ Config file not found for content check")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_yaml_contains_mock_prefix)
    message(STATUS "Test 5: Generated YAML contains mock_prefix configuration")

    set(config_file "${TEST_ROOT}/mock_prefix_test.yml")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

set(_CMOCK_SCHEMA_VERSION \"2.6\" CACHE INTERNAL \"\")
CMockSchema_SetDefaults(\"2.6\")

CMockSchema_GenerateConfigFile(\"${config_file}\")
"
    )

    set(script_file "${TEST_ROOT}/test_mock_prefix_yaml.cmake")
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

    if(EXISTS "${config_file}")
        file(READ "${config_file}" yaml_content)

        string(
            FIND "${yaml_content}"
            "mock_prefix"
            has_mock_prefix
        )

        if(has_mock_prefix EQUAL -1)
            message(STATUS "  ✗ YAML missing 'mock_prefix' configuration")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()

        message(STATUS "  ✓ YAML contains mock_prefix configuration")
    else()
        message(STATUS "  ✗ Config file not found")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_yaml_contains_plugins)
    message(STATUS "Test 6: Generated YAML contains plugins configuration")

    set(config_file "${TEST_ROOT}/plugins_test.yml")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

set(_CMOCK_SCHEMA_VERSION \"2.6\" CACHE INTERNAL \"\")
CMockSchema_SetDefaults(\"2.6\")

CMockSchema_GenerateConfigFile(\"${config_file}\")
"
    )

    set(script_file "${TEST_ROOT}/test_plugins_yaml.cmake")
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

    if(EXISTS "${config_file}")
        file(READ "${config_file}" yaml_content)

        string(
            FIND "${yaml_content}"
            ":plugins:"
            has_plugins
        )

        if(has_plugins EQUAL -1)
            message(STATUS "  ✗ YAML missing ':plugins:' configuration")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()

        message(STATUS "  ✓ YAML contains plugins configuration")
    else()
        message(STATUS "  ✗ Config file not found")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_custom_values_in_yaml)
    message(STATUS "Test 7: Custom cache values appear in generated YAML")

    set(config_file "${TEST_ROOT}/custom_values.yml")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CMockSchema)

set(_CMOCK_SCHEMA_VERSION \"2.6\" CACHE INTERNAL \"\")
CMockSchema_SetDefaults(\"2.6\")

# Override with custom values
set(CMOCK_MOCK_PREFIX \"custom_mock_\" CACHE STRING \"\" FORCE)

CMockSchema_GenerateConfigFile(\"${config_file}\")
"
    )

    set(script_file "${TEST_ROOT}/test_custom_yaml.cmake")
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

    if(EXISTS "${config_file}")
        file(READ "${config_file}" yaml_content)

        string(
            FIND "${yaml_content}"
            "custom_mock_"
            has_custom_prefix
        )

        if(has_custom_prefix EQUAL -1)
            message(STATUS "  ✗ Custom prefix not found in YAML")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()

        message(STATUS "  ✓ Custom values correctly written to YAML")
    else()
        message(STATUS "  ✗ Config file not found")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== CMockSchema_GenerateConfigFile Tests ===")

    setup_test_environment()

    test_generate_without_schema_version_fails()
    test_generate_creates_file()
    test_generate_creates_directories()
    test_yaml_contains_cmock_key()
    test_yaml_contains_mock_prefix()
    test_yaml_contains_plugins()
    test_custom_values_in_yaml()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(
            FATAL_ERROR
            "CMockSchema GenerateConfigFile tests failed with ${ERROR_COUNT} error(s)"
        )
    else()
        message(STATUS "All CMockSchema GenerateConfigFile tests PASSED")
    endif()
endfunction()

run_all_tests()
