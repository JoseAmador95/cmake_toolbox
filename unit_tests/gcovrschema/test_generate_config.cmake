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
# Validates that config files are correctly generated from schema settings

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(TestHelpers)
include(GcovrSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcovrschema_generate_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_generate_without_capabilities)
    message(STATUS "Test 1: GenerateConfigFile without explicit capabilities")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults()

set(config_file \"${TEST_ROOT}/generated_no_caps.cfg\")
GcovrSchema_GenerateConfigFile(\"${TEST_ROOT}/generated_no_caps.cfg\")

if(NOT EXISTS \"${TEST_ROOT}/generated_no_caps.cfg\")
    message(FATAL_ERROR \"Config file was not created\")
endif()
"
    )

    set(script_file "${TEST_ROOT}/test_no_caps.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Config generation without capabilities failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Config created without explicit capabilities")
endfunction()

function(test_generate_creates_file)
    message(STATUS "Test 2: GenerateConfigFile creates output file with capabilities")

    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_default")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults()
GcovrSchema_DetectCapabilities(\"${mock_gcovr_path}\" detected_flags)

set(config_file \"${TEST_ROOT}/generated_config.cfg\")
GcovrSchema_GenerateConfigFile(\"${TEST_ROOT}/generated_config.cfg\")

if(NOT EXISTS \"${TEST_ROOT}/generated_config.cfg\")
    message(FATAL_ERROR \"Config file was not created\")
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

    message(STATUS "  ✓ Config file successfully created")
endfunction()

function(test_generate_creates_directories)
    message(STATUS "Test 3: GenerateConfigFile creates parent directories")

    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_nested")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)

    set(nested_path "${TEST_ROOT}/deep/nested/path/config.cfg")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults()
GcovrSchema_DetectCapabilities(\"${mock_gcovr_path}\" detected_flags)

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

    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_keys")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)

    set(config_file "${TEST_ROOT}/keys_test.cfg")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults()
GcovrSchema_DetectCapabilities(\"${mock_gcovr_path}\" detected_flags)

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

    if(EXISTS "${config_file}")
        file(READ "${config_file}" config_content)
        string(
            FIND "${config_content}"
            "html-high-threshold"
            has_html
        )

        if(has_html EQUAL -1)
            message(STATUS "  ✗ Config missing expected HTML threshold key")
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

    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_custom")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)

    set(config_file "${TEST_ROOT}/custom_values.cfg")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults()
GcovrSchema_DetectCapabilities(\"${mock_gcovr_path}\" detected_flags)

set(CMT_GCOVR_HTML_TITLE \"Custom Test Title\" CACHE STRING \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_LINE \"75\" CACHE STRING \"\" FORCE)
set(CMT_GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)

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

function(test_unsupported_flag_is_skipped)
    message(STATUS "Test 6: Unsupported flags are skipped in generated config")

    set(custom_help "gcovr mock help\n  --fail-under-line\n")
    TestHelpers_CreateMockGcovr(
        mock_gcovr
        OUTPUT_DIR "${TEST_ROOT}/mock_limited"
        HELP_TEXT "${custom_help}"
    )
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)

    set(config_file "${TEST_ROOT}/unsupported_flags.cfg")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults()
GcovrSchema_DetectCapabilities(\"${mock_gcovr_path}\" detected_flags)

set(CMT_GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)
set(CMT_GCOVR_FAIL_UNDER_DECISION 60 CACHE STRING \"\" FORCE)

GcovrSchema_GenerateConfigFile(\"${config_file}\")
"
    )

    set(script_file "${TEST_ROOT}/test_unsupported_flags.cmake")
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
        file(READ "${config_file}" config_content)

        string(
            FIND "${config_content}"
            "fail-under-line"
            has_line
        )
        string(
            FIND "${config_content}"
            "fail-under-decision"
            has_decision
        )

        if(has_line EQUAL -1)
            message(STATUS "  ✗ fail-under-line should be present")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()

        if(NOT has_decision EQUAL -1)
            message(STATUS "  ✗ fail-under-decision should be skipped when unsupported")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()

        message(STATUS "  ✓ Unsupported flags are skipped")
    else()
        message(STATUS "  ✗ Config file not found")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== GcovrSchema_GenerateConfigFile Tests ===")

    setup_test_environment()

    test_generate_without_capabilities()
    test_generate_creates_file()
    test_generate_creates_directories()
    test_config_contains_expected_keys()
    test_config_respects_cache_values()
    test_unsupported_flag_is_skipped()

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
