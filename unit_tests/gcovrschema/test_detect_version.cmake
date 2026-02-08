if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: GcovrSchema_DetectVersion
# Validates version detection from mock executables

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(GcovrSchema)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcovrschema_detect_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_ROOT}")
endfunction()

# Helper to create a mock gcovr script that returns a specific version.
# On Windows, batch scripts require a .bat extension to be executable,
# so the actual written path may differ from the requested one.
# The variable named by RESULT_VAR receives the real path.
function(create_mock_gcovr RESULT_VAR REQUESTED_PATH VERSION_STRING)
    if(WIN32)
        set(actual_path "${REQUESTED_PATH}.bat")
        file(WRITE "${actual_path}" "@echo off\necho ${VERSION_STRING}")
    else()
        set(actual_path "${REQUESTED_PATH}")
        file(WRITE "${actual_path}" "#!/bin/sh\necho '${VERSION_STRING}'")
        file(
            CHMOD
            "${actual_path}"
            PERMISSIONS
                OWNER_EXECUTE
                OWNER_READ
                OWNER_WRITE
        )
    endif()
    set(${RESULT_VAR} "${actual_path}" PARENT_SCOPE)
endfunction()

function(test_detect_supported_version_exact)
    message(STATUS "Test 1: Detect exact supported version (7.0)")

    create_mock_gcovr(mock_gcovr "${TEST_ROOT}/gcovr_7_0" "gcovr 7.0")

    GcovrSchema_DetectVersion("${mock_gcovr}" detected_version)

    if(NOT detected_version STREQUAL "7.0")
        message(STATUS "  ✗ Expected '7.0', got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly detected version 7.0")
endfunction()

function(test_detect_compatible_patch_version)
    message(STATUS "Test 2: Detect compatible patch version (7.2.1 -> 7.0)")

    create_mock_gcovr(mock_gcovr "${TEST_ROOT}/gcovr_7_2_1" "gcovr 7.2.1")

    GcovrSchema_DetectVersion("${mock_gcovr}" detected_version)

    if(NOT detected_version STREQUAL "7.0")
        message(STATUS "  ✗ Expected '7.0' for 7.2.1, got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly mapped 7.2.1 to schema 7.0")
endfunction()

function(test_detect_compatible_mapped_major_version)
    message(STATUS "Test 3: Detect compatible major version (8.6 -> 8.0)")

    create_mock_gcovr(mock_gcovr "${TEST_ROOT}/gcovr_8_6" "gcovr 8.6")

    GcovrSchema_DetectVersion("${mock_gcovr}" detected_version)

    if(NOT detected_version STREQUAL "8.0")
        message(STATUS "  ✗ Expected '8.0' for 8.6, got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly mapped 8.6 to schema 8.0")
endfunction()

function(test_detect_unsupported_version)
    message(STATUS "Test 4: Unsupported version returns empty string (6.0)")

    create_mock_gcovr(mock_gcovr "${TEST_ROOT}/gcovr_6_0" "gcovr 6.0")

    GcovrSchema_DetectVersion("${mock_gcovr}" detected_version)

    if(NOT detected_version STREQUAL "")
        message(STATUS "  ✗ Expected empty string for unsupported 6.0, got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly returned empty for unsupported version 6.0")
endfunction()

function(test_detect_nonexistent_executable)
    message(STATUS "Test 5: Non-existent executable returns empty string")

    set(fake_path "${TEST_ROOT}/nonexistent_gcovr_binary")

    GcovrSchema_DetectVersion("${fake_path}" detected_version)

    if(NOT detected_version STREQUAL "")
        message(STATUS "  ✗ Expected empty string for non-existent path, got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly returned empty for non-existent executable")
endfunction()

function(test_detect_malformed_output)
    message(STATUS "Test 6: Malformed version output returns empty string")

    create_mock_gcovr(mock_gcovr "${TEST_ROOT}/gcovr_malformed" "some random output without version")

    GcovrSchema_DetectVersion("${mock_gcovr}" detected_version)

    if(NOT detected_version STREQUAL "")
        message(STATUS "  ✗ Expected empty string for malformed output, got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly returned empty for malformed version output")
endfunction()

function(test_detect_empty_executable_path)
    message(STATUS "Test 7: Empty executable path returns empty string")

    GcovrSchema_DetectVersion("" detected_version)

    if(NOT detected_version STREQUAL "")
        message(STATUS "  ✗ Expected empty string for empty path, got '${detected_version}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Correctly returned empty for empty executable path")
endfunction()

function(test_output_variable_scope)
    message(STATUS "Test 8: Output variable is set in caller scope")

    create_mock_gcovr(mock_gcovr "${TEST_ROOT}/gcovr_scope_test" "gcovr 7.0")

    unset(my_result_var)
    GcovrSchema_DetectVersion("${mock_gcovr}" my_result_var)

    if(NOT DEFINED my_result_var)
        message(STATUS "  ✗ Output variable not defined in caller scope")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Output variable correctly set in caller scope: ${my_result_var}")
endfunction()

function(run_all_tests)
    message(STATUS "=== GcovrSchema_DetectVersion Tests ===")

    setup_test_environment()

    test_detect_supported_version_exact()
    test_detect_compatible_patch_version()
    test_detect_compatible_mapped_major_version()
    test_detect_unsupported_version()
    test_detect_nonexistent_executable()
    test_detect_malformed_output()
    test_detect_empty_executable_path()
    test_output_variable_scope()

    cleanup_test_environment()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "GcovrSchema DetectVersion tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All GcovrSchema DetectVersion tests PASSED")
    endif()
endfunction()

run_all_tests()
