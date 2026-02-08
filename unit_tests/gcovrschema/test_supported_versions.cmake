# Test: GcovrSchema_GetSupportedVersions
# Validates that the function returns valid supported versions list

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(GcovrSchema)

set(ERROR_COUNT 0)

function(test_returns_non_empty_list)
    message(STATUS "Test 1: GcovrSchema_GetSupportedVersions returns non-empty list")

    GcovrSchema_GetSupportedVersions(versions)

    list(LENGTH versions version_count)
    if(version_count EQUAL 0)
        message(STATUS "  ✗ Returned empty list")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Returned ${version_count} version(s): ${versions}")
endfunction()

function(test_contains_expected_version)
    message(STATUS "Test 2: Supported versions contains '7.0'")

    GcovrSchema_GetSupportedVersions(versions)

    list(
        FIND versions
        "7.0"
        version_index
    )
    if(version_index EQUAL -1)
        message(STATUS "  ✗ Version 7.0 not found in: ${versions}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Version 7.0 found in supported versions")
endfunction()

function(test_version_format)
    message(STATUS "Test 3: Versions follow MAJOR.MINOR format")

    GcovrSchema_GetSupportedVersions(versions)

    foreach(ver IN LISTS versions)
        if(NOT ver MATCHES "^[0-9]+\\.[0-9]+$")
            message(STATUS "  ✗ Invalid version format: ${ver}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()
    endforeach()

    message(STATUS "  ✓ All versions follow MAJOR.MINOR format")
endfunction()

function(test_output_variable_set)
    message(STATUS "Test 4: Output variable is set correctly")

    # Ensure variable doesn't exist before call
    unset(my_output)

    GcovrSchema_GetSupportedVersions(my_output)

    if(NOT DEFINED my_output)
        message(STATUS "  ✗ Output variable not defined after call")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Output variable set to: ${my_output}")
endfunction()

function(run_all_tests)
    message(STATUS "=== GcovrSchema_GetSupportedVersions Tests ===")

    test_returns_non_empty_list()
    test_contains_expected_version()
    test_version_format()
    test_output_variable_set()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(
            FATAL_ERROR
            "GcovrSchema GetSupportedVersions tests failed with ${ERROR_COUNT} error(s)"
        )
    else()
        message(STATUS "All GcovrSchema GetSupportedVersions tests PASSED")
    endif()
endfunction()

run_all_tests()
