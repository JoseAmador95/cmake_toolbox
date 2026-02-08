# Test: CMockSchema_DetectVersion
# Validates version detection from git tags (CMock typically uses tags rather than executable output)

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(CMockSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/cmockschema_detect_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_ROOT}")
endfunction()

function(test_detect_from_tag_v2_6_0)
    message(STATUS "Test 1: Detect version from tag 'v2.6.0'")

    # CMockSchema_DetectVersion takes: CMOCK_EXE, TAG, OUTPUT_VAR
    # When executable detection fails, it falls back to tag parsing
    CMockSchema_DetectVersion("" "v2.6.0" detected_version)

    if(NOT detected_version STREQUAL "2.6")
        message(STATUS "  ✗ Expected '2.6' from tag 'v2.6.0', got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly detected version 2.6 from tag v2.6.0")
endfunction()

function(test_detect_from_tag_without_v_prefix)
    message(STATUS "Test 2: Detect version from tag '2.6.3' (no v prefix)")

    CMockSchema_DetectVersion("" "2.6.3" detected_version)

    if(NOT detected_version STREQUAL "2.6")
        message(STATUS "  ✗ Expected '2.6' from tag '2.6.3', got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly detected version 2.6 from tag 2.6.3")
endfunction()

function(test_detect_unsupported_version)
    message(STATUS "Test 3: Unsupported version returns empty string (v3.0.0)")

    CMockSchema_DetectVersion("" "v3.0.0" detected_version)

    if(NOT detected_version STREQUAL "")
        message(
            STATUS
            "  ✗ Expected empty string for unsupported v3.0.0, got '${detected_version}'"
        )
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly returned empty for unsupported version 3.0")
endfunction()

function(test_detect_invalid_tag)
    message(STATUS "Test 4: Invalid tag format returns empty string")

    CMockSchema_DetectVersion("" "not_a_version" detected_version)

    if(NOT detected_version STREQUAL "")
        message(STATUS "  ✗ Expected empty string for invalid tag, got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly returned empty for invalid tag format")
endfunction()

function(test_detect_empty_tag)
    message(STATUS "Test 5: Empty tag returns empty string")

    CMockSchema_DetectVersion("" "" detected_version)

    if(NOT detected_version STREQUAL "")
        message(STATUS "  ✗ Expected empty string for empty tag, got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly returned empty for empty tag")
endfunction()

function(test_detect_from_tag_v2_5_3)
    message(STATUS "Test 6: Older version v2.5.3 returns empty (only 2.6 supported)")

    CMockSchema_DetectVersion("" "v2.5.3" detected_version)

    # 2.5 is not in supported versions list, so should return empty
    if(NOT detected_version STREQUAL "")
        message(
            STATUS
            "  ✗ Expected empty string for unsupported v2.5.3, got '${detected_version}'"
        )
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly returned empty for unsupported version 2.5")
endfunction()

function(test_output_variable_scope)
    message(STATUS "Test 7: Output variable is set in caller scope")

    unset(my_result_var)
    CMockSchema_DetectVersion("" "v2.6.0" my_result_var)

    if(NOT DEFINED my_result_var)
        message(STATUS "  ✗ Output variable not defined in caller scope")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Output variable correctly set in caller scope: ${my_result_var}")
endfunction()

function(test_detect_nonexistent_executable)
    message(STATUS "Test 8: Non-existent executable falls back to tag")

    CMockSchema_DetectVersion("/nonexistent/path/to/cmock" "v2.6.0" detected_version)

    # Should fall back to tag parsing
    if(NOT detected_version STREQUAL "2.6")
        message(
            STATUS
            "  ✗ Expected '2.6' when exe missing + tag 'v2.6.0', got '${detected_version}'"
        )
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly fell back to tag when executable not found")
endfunction()

function(run_all_tests)
    message(STATUS "=== CMockSchema_DetectVersion Tests ===")

    setup_test_environment()

    test_detect_from_tag_v2_6_0()
    test_detect_from_tag_without_v_prefix()
    test_detect_unsupported_version()
    test_detect_invalid_tag()
    test_detect_empty_tag()
    test_detect_from_tag_v2_5_3()
    test_output_variable_scope()
    test_detect_nonexistent_executable()

    cleanup_test_environment()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "CMockSchema DetectVersion tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All CMockSchema DetectVersion tests PASSED")
    endif()
endfunction()

run_all_tests()
