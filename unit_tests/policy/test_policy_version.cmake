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
