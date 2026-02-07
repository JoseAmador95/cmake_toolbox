# Test: Policy Version Function
# Tests policy_version function with various version ranges

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)

set(ERROR_COUNT 0)

function(setup_test_environment)
    # Register test policies for version testing
    Policy_Register(NAME VER001 DESCRIPTION "Use new behavior for XYZ" DEFAULT OLD INTRODUCED_VERSION 1.0)
    Policy_Register(NAME VER002 DESCRIPTION "Enable advanced optimization" DEFAULT OLD INTRODUCED_VERSION 2.0)
    Policy_Register(NAME VER003 DESCRIPTION "New parser syntax" DEFAULT OLD INTRODUCED_VERSION 3.1)
    Policy_Register(NAME VER004 DESCRIPTION "Future feature" DEFAULT OLD INTRODUCED_VERSION 5.0)
    message(STATUS "Setting up policy version test environment")
endfunction()

function(test_version_minimum_2_5)
    message(STATUS "Test 1: Testing policy_version MINIMUM 2.5")
    
    Policy_Version(MINIMUM 2.5)

    Policy_Get(VER001 v1)
    Policy_Get(VER002 v2)
    Policy_Get(VER003 v3)
    Policy_Get(VER004 v4)

    # Verify expected values
    if(NOT v1 STREQUAL "NEW")
        message(SEND_ERROR "VER001 should be NEW but got ${v1}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v2 STREQUAL "NEW")
        message(SEND_ERROR "VER002 should be NEW but got ${v2}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v3 STREQUAL "OLD")
        message(SEND_ERROR "VER003 should be OLD but got ${v3}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v4 STREQUAL "OLD")
        message(SEND_ERROR "VER004 should be OLD but got ${v4}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Policy version MINIMUM 2.5 works correctly")
endfunction()

function(test_version_minimum_3_2)
    message(STATUS "Test 2: Testing policy_version MINIMUM 3.2")
    
    Policy_Version(MINIMUM 3.2)

    Policy_Get(VER001 v1)
    Policy_Get(VER002 v2)
    Policy_Get(VER003 v3)
    Policy_Get(VER004 v4)

    # Verify expected values
    if(NOT v1 STREQUAL "NEW")
        message(SEND_ERROR "VER001 should be NEW but got ${v1}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v2 STREQUAL "NEW")
        message(SEND_ERROR "VER002 should be NEW but got ${v2}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v3 STREQUAL "NEW")
        message(SEND_ERROR "VER003 should be NEW but got ${v3}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v4 STREQUAL "OLD")
        message(SEND_ERROR "VER004 should be OLD but got ${v4}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Policy version MINIMUM 3.2 works correctly")
endfunction()

function(test_version_range)
    message(STATUS "Test 3: Testing policy_version MINIMUM 1.0 MAXIMUM 2.5")
    
    Policy_Version(MINIMUM 1.0 MAXIMUM 2.5)

    Policy_Get(VER001 v1)
    Policy_Get(VER002 v2)
    Policy_Get(VER003 v3)
    Policy_Get(VER004 v4)

    # Verify expected values
    if(NOT v1 STREQUAL "NEW")
        message(SEND_ERROR "VER001 should be NEW but got ${v1}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v2 STREQUAL "NEW")
        message(SEND_ERROR "VER002 should be NEW but got ${v2}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v3 STREQUAL "OLD")
        message(SEND_ERROR "VER003 should be OLD but got ${v3}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v4 STREQUAL "OLD")
        message(SEND_ERROR "VER004 should be OLD but got ${v4}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Policy version range MINIMUM/MAXIMUM works correctly")
endfunction()

function(test_version_equal_boundaries)
    message(STATUS "Test 4: Testing MINIMUM == MAXIMUM (boundary case)")
    
    # This should be valid - all policies up to version 2.0 should be NEW
    Policy_Version(MINIMUM 2.0 MAXIMUM 2.0)

    Policy_Get(VER001 v1)
    Policy_Get(VER002 v2)
    Policy_Get(VER003 v3)
    Policy_Get(VER004 v4)

    # Verify expected values
    if(NOT v1 STREQUAL "NEW")
        message(SEND_ERROR "VER001 (introduced 1.0) should be NEW but got ${v1}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v2 STREQUAL "NEW")
        message(SEND_ERROR "VER002 (introduced 2.0) should be NEW but got ${v2}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v3 STREQUAL "OLD")
        message(SEND_ERROR "VER003 (introduced 3.1) should be OLD but got ${v3}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v4 STREQUAL "OLD")
        message(SEND_ERROR "VER004 (introduced 5.0) should be OLD but got ${v4}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ MINIMUM == MAXIMUM boundary case works correctly")
endfunction()

function(test_version_maximum_inclusive)
    message(STATUS "Test 5: Testing MAXIMUM is inclusive (policy at MAXIMUM should be NEW)")
    
    # VER003 is introduced at 3.1, so MAXIMUM 3.1 should include it as NEW
    Policy_Version(MINIMUM 1.0 MAXIMUM 3.1)

    Policy_Get(VER001 v1)
    Policy_Get(VER002 v2)
    Policy_Get(VER003 v3)
    Policy_Get(VER004 v4)

    # Verify expected values
    if(NOT v1 STREQUAL "NEW")
        message(SEND_ERROR "VER001 (introduced 1.0) should be NEW but got ${v1}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v2 STREQUAL "NEW")
        message(SEND_ERROR "VER002 (introduced 2.0) should be NEW but got ${v2}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v3 STREQUAL "NEW")
        message(SEND_ERROR "VER003 (introduced 3.1, at MAXIMUM) should be NEW but got ${v3}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    if(NOT v4 STREQUAL "OLD")
        message(SEND_ERROR "VER004 (introduced 5.0) should be OLD but got ${v4}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ MAXIMUM inclusive boundary works correctly")
endfunction()

function(test_version_invalid_range)
    message(STATUS "Test 6: Testing invalid range (MAXIMUM < MINIMUM should error)")

    set(temp_script "${CMAKE_BINARY_DIR}/temp_test_invalid_version_range.cmake")
    file(WRITE "${temp_script}" "include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/Policy.cmake)
Policy_Register(NAME RANGE_ERR DESCRIPTION \"Range validation\" DEFAULT OLD INTRODUCED_VERSION 1.0)
Policy_Version(MINIMUM 4.0 MAXIMUM 3.5)
")

    execute_process(
        COMMAND ${CMAKE_COMMAND} -P "${temp_script}"
        RESULT_VARIABLE range_result
        OUTPUT_VARIABLE range_output
        ERROR_VARIABLE range_error
    )

    file(REMOVE "${temp_script}")

    if(range_result EQUAL 0)
        message(SEND_ERROR "Policy_Version should fail when MAXIMUM < MINIMUM")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    string(FIND "${range_error}" "MAXIMUM (3.5) must be greater than or equal to MINIMUM" _err_match_main)
    string(FIND "${range_error}" "(4.0)" _err_match_value)
    if(_err_match_main EQUAL -1 OR _err_match_value EQUAL -1)
        message(SEND_ERROR "Expected MAXIMUM/MINIMUM validation message not found. Error: ${range_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Invalid range correctly fails with clear validation error")
endfunction()

function(cleanup_test_environment)
    # No cleanup needed for policy tests
    message(STATUS "Cleaning up policy version test environment")
endfunction()

function(run_all_tests)
    message(STATUS "=== Policy Version Function Unit Tests ===")
    
    setup_test_environment()
    test_version_minimum_2_5()
    test_version_minimum_3_2()
    test_version_range()
    test_version_equal_boundaries()
    test_version_maximum_inclusive()
    test_version_invalid_range()
    cleanup_test_environment()
    
    # Test Summary
    message(STATUS "")
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "✓ All tests passed!")
    else()
        message(STATUS "✗ ${ERROR_COUNT} test(s) failed")
    endif()
    message(STATUS "")
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
    run_all_tests()
endif()
