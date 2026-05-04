if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: GcovrSchema_Validate
# Validates threshold and format validation logic

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(GcovrSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcovrschema_validate_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_valid_thresholds_zero)
    message(STATUS "Test 1: Threshold 0 is valid")

    # Set up valid threshold at 0
    set(CMT_GCOVR_FAIL_UNDER_LINE "0")
    set(CMT_GCOVR_FAIL_UNDER_BRANCH "0")

    GcovrSchema_Validate()

    if(NOT CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Threshold 0 should be valid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Threshold 0 correctly accepted")
endfunction()

function(test_valid_thresholds_mid_range)
    message(STATUS "Test 2: Threshold 50 is valid")

    set(CMT_GCOVR_FAIL_UNDER_LINE "50")
    set(CMT_GCOVR_FAIL_UNDER_BRANCH "50")
    set(CMT_GCOVR_HTML_HIGH_THRESHOLD "50")

    GcovrSchema_Validate()

    if(NOT CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Threshold 50 should be valid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Threshold 50 correctly accepted")
endfunction()

function(test_valid_thresholds_max)
    message(STATUS "Test 3: Threshold 100 is valid")

    set(CMT_GCOVR_FAIL_UNDER_LINE "100")
    set(CMT_GCOVR_FAIL_UNDER_BRANCH "100")
    set(CMT_GCOVR_HTML_HIGH_THRESHOLD "100")

    GcovrSchema_Validate()

    if(NOT CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Threshold 100 should be valid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Threshold 100 correctly accepted")
endfunction()

function(test_invalid_threshold_over_100)
    message(STATUS "Test 4: Threshold > 100 is invalid")

    set(CMT_GCOVR_FAIL_UNDER_LINE "150")

    GcovrSchema_Validate()

    if(CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Threshold 150 should be invalid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Threshold 150 correctly rejected")
endfunction()

function(test_invalid_threshold_non_numeric)
    message(STATUS "Test 5: Non-numeric threshold is invalid")

    set(CMT_GCOVR_FAIL_UNDER_LINE "abc")

    GcovrSchema_Validate()

    if(CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Non-numeric threshold 'abc' should be invalid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Non-numeric threshold correctly rejected")
endfunction()

function(test_invalid_threshold_negative)
    message(STATUS "Test 6: Negative threshold is invalid (treated as non-numeric)")

    set(CMT_GCOVR_FAIL_UNDER_LINE "-10")

    GcovrSchema_Validate()

    # Negative numbers fail the ^[0-9]+$ regex, so they're treated as invalid
    if(CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Negative threshold '-10' should be invalid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Negative threshold correctly rejected")
endfunction()

function(test_invalid_threshold_decimal)
    message(STATUS "Test 7: Decimal threshold is invalid")

    set(CMT_GCOVR_FAIL_UNDER_LINE "50.5")

    GcovrSchema_Validate()

    if(CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Decimal threshold '50.5' should be invalid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Decimal threshold correctly rejected")
endfunction()

function(test_valid_output_format_html)
    message(STATUS "Test 8: Output format 'html' is valid")

    # Clear thresholds to avoid interference
    unset(CMT_GCOVR_FAIL_UNDER_LINE)
    set(CMT_GCOVR_OUTPUT_FORMATS "html")

    GcovrSchema_Validate()

    if(NOT CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Output format 'html' should be valid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Output format 'html' correctly accepted")
endfunction()

function(test_valid_output_formats_multiple)
    message(STATUS "Test 9: Multiple valid output formats")

    unset(CMT_GCOVR_FAIL_UNDER_LINE)
    set(CMT_GCOVR_OUTPUT_FORMATS "html;xml;json")

    GcovrSchema_Validate()

    if(NOT CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Multiple formats 'html;xml;json' should be valid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Multiple output formats correctly accepted")
endfunction()

function(test_invalid_output_format)
    message(STATUS "Test 10: Invalid output format is rejected")

    unset(CMT_GCOVR_FAIL_UNDER_LINE)
    set(CMT_GCOVR_OUTPUT_FORMATS "invalid_format")

    GcovrSchema_Validate()

    if(CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Invalid format 'invalid_format' should be rejected")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Invalid output format correctly rejected")
endfunction()

function(test_all_valid_formats)
    message(STATUS "Test 11: All documented formats are valid")

    unset(CMT_GCOVR_FAIL_UNDER_LINE)
    set(CMT_GCOVR_OUTPUT_FORMATS "html;xml;json;cobertura;coveralls;lcov;csv;txt")

    GcovrSchema_Validate()

    if(NOT CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ All documented formats should be valid")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ All documented output formats accepted")
endfunction()

function(test_undefined_variables_are_valid)
    message(STATUS "Test 12: Undefined threshold variables don't cause validation failure")

    # Unset all threshold variables
    unset(CMT_GCOVR_FAIL_UNDER_LINE)
    unset(CMT_GCOVR_FAIL_UNDER_BRANCH)
    unset(CMT_GCOVR_FAIL_UNDER_FUNCTION)
    unset(CMT_GCOVR_FAIL_UNDER_DECISION)
    unset(CMT_GCOVR_HTML_HIGH_THRESHOLD)
    unset(GCOVR_HTML_MEDIUM_THRESHOLD)
    unset(CMT_GCOVR_OUTPUT_FORMATS)

    GcovrSchema_Validate()

    if(NOT CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Undefined variables should not cause validation failure")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Undefined variables correctly handled")
endfunction()

function(test_multiple_invalid_values)
    message(STATUS "Test 13: Multiple invalid values all reported")

    set(CMT_GCOVR_FAIL_UNDER_LINE "invalid")
    set(CMT_GCOVR_FAIL_UNDER_BRANCH "200")
    set(CMT_GCOVR_OUTPUT_FORMATS "bad_format")

    GcovrSchema_Validate()

    if(CMT_GCOVR_SCHEMA_VALID)
        message(STATUS "  ✗ Multiple invalid values should fail validation")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Multiple invalid values correctly detected")
endfunction()

function(run_all_tests)
    message(STATUS "=== GcovrSchema_Validate Tests ===")

    setup_test_environment()

    test_valid_thresholds_zero()
    test_valid_thresholds_mid_range()
    test_valid_thresholds_max()
    test_invalid_threshold_over_100()
    test_invalid_threshold_non_numeric()
    test_invalid_threshold_negative()
    test_invalid_threshold_decimal()
    test_valid_output_format_html()
    test_valid_output_formats_multiple()
    test_invalid_output_format()
    test_all_valid_formats()
    test_undefined_variables_are_valid()
    test_multiple_invalid_values()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "GcovrSchema Validate tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All GcovrSchema Validate tests PASSED")
    endif()
endfunction()

run_all_tests()
