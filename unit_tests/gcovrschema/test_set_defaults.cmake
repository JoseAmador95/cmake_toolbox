if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: GcovrSchema_SetDefaults
# Validates that defaults are correctly applied

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(GcovrSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcovrschema_defaults_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_defaults_set)
    message(STATUS "Test 1: SetDefaults applies cache defaults")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

unset(CMT_GCOVR_FAIL_UNDER_LINE CACHE)
unset(CMT_GCOVR_FAIL_UNDER_BRANCH CACHE)
unset(CMT_GCOVR_HTML_HIGH_THRESHOLD CACHE)

GcovrSchema_SetDefaults()

if(NOT DEFINED CMT_GCOVR_FAIL_UNDER_LINE)
    message(FATAL_ERROR \"CMT_GCOVR_FAIL_UNDER_LINE not set\")
endif()

if(NOT DEFINED CMT_GCOVR_HTML_HIGH_THRESHOLD)
    message(FATAL_ERROR \"CMT_GCOVR_HTML_HIGH_THRESHOLD not set\")
endif()

message(STATUS \"CMT_GCOVR_FAIL_UNDER_LINE = \${CMT_GCOVR_FAIL_UNDER_LINE}\")
message(STATUS \"CMT_GCOVR_HTML_HIGH_THRESHOLD = \${CMT_GCOVR_HTML_HIGH_THRESHOLD}\")
"
    )

    set(script_file "${TEST_ROOT}/test_defaults.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SetDefaults failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Defaults correctly applied")
endfunction()

function(test_schema_variables_defined)
    message(STATUS "Test 2: Verify schema variables are initialized")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults()

set(expected_vars
    CMT_GCOVR_ENFORCE_THRESHOLDS
    CMT_GCOVR_FAIL_UNDER_LINE
    CMT_GCOVR_FAIL_UNDER_BRANCH
    CMT_GCOVR_FAIL_UNDER_FUNCTION
    CMT_GCOVR_HTML_HIGH_THRESHOLD
    CMT_GCOVR_HTML_MEDIUM_THRESHOLD
    CMT_GCOVR_OUTPUT_FORMATS
    CMT_GCOVR_PRINT_SUMMARY
)

foreach(var IN LISTS expected_vars)
    if(NOT DEFINED \${var})
        message(FATAL_ERROR \"\${var} not defined after SetDefaults\")
    endif()
    message(STATUS \"\${var} = \${\${var}}\")
endforeach()
"
    )

    set(script_file "${TEST_ROOT}/test_schema_vars.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Schema variables check failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ All expected schema variables are defined")
endfunction()

function(test_threshold_defaults_are_zero)
    message(STATUS "Test 3: Verify fail-under thresholds default to 0")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(GcovrSchema)

GcovrSchema_SetDefaults()

if(NOT CMT_GCOVR_FAIL_UNDER_LINE STREQUAL \"0\")
    message(FATAL_ERROR \"CMT_GCOVR_FAIL_UNDER_LINE should be 0, got \${CMT_GCOVR_FAIL_UNDER_LINE}\")
endif()

if(NOT CMT_GCOVR_FAIL_UNDER_BRANCH STREQUAL \"0\")
    message(FATAL_ERROR \"CMT_GCOVR_FAIL_UNDER_BRANCH should be 0, got \${CMT_GCOVR_FAIL_UNDER_BRANCH}\")
endif()
"
    )

    set(script_file "${TEST_ROOT}/test_threshold_defaults.cmake")
    file(WRITE "${script_file}" "${test_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${script_file}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Threshold defaults check failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Fail-under thresholds correctly default to 0")
endfunction()

function(run_all_tests)
    message(STATUS "=== GcovrSchema_SetDefaults Tests ===")

    setup_test_environment()

    test_defaults_set()
    test_schema_variables_defined()
    test_threshold_defaults_are_zero()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "GcovrSchema SetDefaults tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All GcovrSchema SetDefaults tests PASSED")
    endif()
endfunction()

run_all_tests()
