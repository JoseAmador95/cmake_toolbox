# Test: GcovrSchema_DetectCapabilities
# Validates that the function detects supported flags from gcovr --help output

if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(TestHelpers)
include(GcovrSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcovrschema_capabilities_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_detects_expected_flags)
    message(STATUS "Test 1: Detect expected flags from mock gcovr --help")

    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_default")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)

    GcovrSchema_DetectCapabilities("${mock_gcovr_path}" supported_flags)

    list(LENGTH supported_flags flag_count)
    if(flag_count EQUAL 0)
        message(STATUS "  ✗ Expected non-empty capabilities list")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    list(FIND supported_flags "--fail-under-line" has_fail_under_line)
    list(FIND supported_flags "--html" has_html)
    if(has_fail_under_line EQUAL -1 OR has_html EQUAL -1)
        message(STATUS "  ✗ Missing expected flags in capabilities: ${supported_flags}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Expected flags detected")
endfunction()

function(test_missing_flag_not_reported)
    message(STATUS "Test 2: Missing flag is not reported")

    set(custom_help "gcovr mock help\n  --html\n  --json\n")
    TestHelpers_CreateMockGcovr(
        mock_gcovr
        OUTPUT_DIR "${TEST_ROOT}/mock_partial"
        HELP_TEXT "${custom_help}"
    )
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)

    GcovrSchema_DetectCapabilities("${mock_gcovr_path}" supported_flags)

    list(FIND supported_flags "--fail-under-decision" has_decision)
    if(NOT has_decision EQUAL -1)
        message(STATUS "  ✗ Unexpected flag detected in capabilities: ${supported_flags}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Missing flag correctly excluded")
endfunction()

function(run_all_tests)
    message(STATUS "=== GcovrSchema_DetectCapabilities Tests ===")

    setup_test_environment()

    test_detects_expected_flags()
    test_missing_flag_not_reported()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(
            FATAL_ERROR
            "GcovrSchema DetectCapabilities tests failed with ${ERROR_COUNT} error(s)"
        )
    else()
        message(STATUS "All GcovrSchema DetectCapabilities tests PASSED")
    endif()
endfunction()

run_all_tests()
