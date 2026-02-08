if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: Error Handling
# Tests various error conditions and parameter validation

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(ERROR_COUNT 0)
file(MAKE_DIRECTORY "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}")

function(setup_test_environment)
    # No file system setup needed for policy tests
    message(STATUS "Setting up error handling test environment")
endfunction()

# Helper function to test that a command fails for the expected reason
function(test_command_fails DESCRIPTION COMMAND_STRING EXPECTED_ERROR_SUBSTRING)
    message(STATUS "  Testing: ${DESCRIPTION}")

    # Create a temporary script file
    string(MD5 temp_script_id "${DESCRIPTION};${COMMAND_STRING}")
    set(temp_script "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/temp_test_${temp_script_id}.cmake")
    string(REPLACE ";" "\n" command_script "${COMMAND_STRING}")
    file(WRITE "${temp_script}" "${command_script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${temp_script}"
        RESULT_VARIABLE cmd_result
        OUTPUT_VARIABLE cmd_output
        ERROR_VARIABLE cmd_error
    )

    # Clean up
    file(REMOVE "${temp_script}")

    if(cmd_result EQUAL 0)
        message(STATUS "    ✗ ${DESCRIPTION} - should have failed but succeeded")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    else()
        set(combined_output "${cmd_output}\n${cmd_error}")
        string(FIND "${combined_output}" "${EXPECTED_ERROR_SUBSTRING}" expected_pos)
        if(expected_pos EQUAL -1)
            message(STATUS "    ✗ ${DESCRIPTION} - failed for unexpected reason")
            message(STATUS "      Expected substring: ${EXPECTED_ERROR_SUBSTRING}")
            message(STATUS "      Actual output: ${combined_output}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            return()
        endif()
        message(STATUS "    ✓ ${DESCRIPTION} - correctly failed with expected diagnostic")
    endif()
endfunction()

function(test_policy_register_errors)
    message(STATUS "Test 1: Testing policy_register parameter validation")

    set(local_errors 0)

    # Missing required parameters for policy_register
    test_command_fails(
        "policy_register without NAME"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0)"
        "Policy_Register: requires NAME <policy_name>"
    )

    test_command_fails(
        "policy_register without DESCRIPTION"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DEFAULT OLD INTRODUCED_VERSION 1.0)"
        "Policy_Register: requires DESCRIPTION <description>"
    )

    test_command_fails(
        "policy_register without DEFAULT"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" INTRODUCED_VERSION 1.0)"
        "Policy_Register: requires DEFAULT <NEW|OLD>"
    )

    test_command_fails(
        "policy_register without INTRODUCED_VERSION"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD)"
        "Policy_Register: requires INTRODUCED_VERSION <version>"
    )

    # Invalid DEFAULT values
    test_command_fails(
        "policy_register with invalid DEFAULT"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT INVALID INTRODUCED_VERSION 1.0)"
        "POLICY: Value must be NEW or OLD"
    )

    test_command_fails(
        "policy_register with lowercase default"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT old INTRODUCED_VERSION 1.0)"
        "POLICY: Value must be NEW or OLD"
    )

    test_command_fails(
        "Duplicate policy registration"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME DUP DESCRIPTION \"first\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Register(NAME DUP DESCRIPTION \"second\" DEFAULT NEW INTRODUCED_VERSION 2.0)"
        "POLICY: Already registered: DUP"
    )

    message(STATUS "  ✓ All policy_register error conditions handled correctly")
    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(test_policy_set_errors)
    message(STATUS "Test 2: Testing policy_set parameter validation")

    test_command_fails(
        "policy_set without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Set(\"\" NEW)"
        "Policy_Set: POLICY parameter is required"
    )

    test_command_fails(
        "policy_set without VALUE"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Set(TEST \"\")"
        "Policy_Set: VALUE parameter is required"
    )

    test_command_fails(
        "policy_set with invalid value"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Set(TEST INVALID)"
        "POLICY: Value must be NEW or OLD"
    )

    test_command_fails(
        "policy_set with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Set(NONEXISTENT NEW)"
        "Policy_Set: NONEXISTENT not registered"
    )

    message(STATUS "  ✓ All policy_set error conditions handled correctly")
    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(test_policy_get_errors)
    message(STATUS "Test 3: Testing policy_get parameter validation")

    test_command_fails(
        "policy_get without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Get(\"\" result)"
        "Policy_Get: POLICY parameter is required"
    )

    test_command_fails(
        "policy_get without OUTVAR"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Get(TEST \"\")"
        "Policy_Get: OUTVAR parameter is required"
    )

    test_command_fails(
        "policy_get with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Get(NONEXISTENT result)"
        "Policy_Get: NONEXISTENT not registered"
    )

    message(STATUS "  ✓ All policy_get error conditions handled correctly")
    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(test_policy_version_errors)
    message(STATUS "Test 4: Testing policy_version parameter validation")

    test_command_fails(
        "policy_version without MINIMUM"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Version()"
        "Policy_Version: MINIMUM parameter is required"
    )

    test_command_fails(
        "policy_version with MAXIMUM < MINIMUM"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_Version(MINIMUM 4.0 MAXIMUM 3.5)"
        "Policy_Version: MAXIMUM (3.5) must be greater than or equal to MINIMUM"
    )

    message(STATUS "  ✓ All policy_version error conditions handled correctly")
    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(test_policy_info_errors)
    message(STATUS "Test 5: Testing policy_info parameter validation")

    test_command_fails(
        "policy_info without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Info(\"\")"
        "Policy_Info: POLICY parameter is required"
    )

    test_command_fails(
        "policy_info with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Info(NONEXISTENT)"
        "Policy_Info: NONEXISTENT not registered"
    )

    message(STATUS "  ✓ All policy_info error conditions handled correctly")
    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(test_policy_get_fields_errors)
    message(STATUS "Test 6: Testing policy_get_fields parameter validation")

    test_command_fails(
        "policy_get_fields without POLICY"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_GetFields(\"\" TEST)"
        "Policy_GetFields: POLICY parameter is required"
    )

    test_command_fails(
        "policy_get_fields without PREFIX"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_Register(NAME TEST DESCRIPTION \"test\" DEFAULT OLD INTRODUCED_VERSION 1.0); Policy_GetFields(TEST \"\")"
        "Policy_GetFields: PREFIX parameter is required"
    )

    test_command_fails(
        "policy_get_fields with unregistered policy"
        "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake); Policy_GetFields(NONEXISTENT TEST)"
        "Policy_GetFields: NONEXISTENT not registered"
    )

    message(STATUS "  ✓ All policy_get_fields error conditions handled correctly")
    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(cleanup_test_environment)
    # No cleanup needed for policy tests
    message(STATUS "Cleaning up error handling test environment")
endfunction()

function(run_all_tests)
    message(STATUS "=== Error Handling Unit Tests ===")

    setup_test_environment()
    test_policy_register_errors()
    test_policy_set_errors()
    test_policy_get_errors()
    test_policy_version_errors()
    test_policy_info_errors()
    test_policy_get_fields_errors()
    cleanup_test_environment()

    # Test Summary
    message(STATUS "")
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "✓ All tests passed!")
    else()
        message(STATUS "✗ ${ERROR_COUNT} test(s) failed")
    endif()
    message(STATUS "")

    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "${ERROR_COUNT} test(s) failed")
    endif()
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
    run_all_tests()
endif()
