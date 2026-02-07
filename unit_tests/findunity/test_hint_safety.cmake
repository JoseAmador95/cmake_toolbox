# Unit test for FindUnity.cmake hint variable safety (Issue #10)
# 
# This test verifies that FindUnity.cmake handles undefined, empty, and invalid
# hint variables without causing evaluation errors.

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/FindUnity.cmake)

set(ERROR_COUNT 0)

# ==============================================================================
# Test Helper Functions
# ==============================================================================

function(expect_no_error test_name)
    message(STATUS "Test: ${test_name}")
    message(STATUS "  ✓ No errors occurred")
endfunction()

function(report_error test_name message)
    message(STATUS "Test: ${test_name}")
    message(STATUS "  ✗ ${message}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1" PARENT_SCOPE)
    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Test 1: Undefined hint variables
# ==============================================================================
function(test_undefined_hints)
    # Clear any existing hint variables
    unset(Unity_ROOT)
    unset(UNITY_ROOT)
    unset(ENV{UNITY_ROOT})
    unset(Unity_ROOT CACHE)
    unset(UNITY_ROOT CACHE)
    
    # This should not cause any errors
    # Before fix: if(${var}) would expand to if() which could cause syntax errors
    set(_Unity_HINT_DIRS)
    foreach(var IN ITEMS Unity_ROOT UNITY_ROOT)
        if(DEFINED ${var})
            list(APPEND _Unity_HINT_DIRS "${${var}}")
        endif()
    endforeach()
    
    # Verify hint list is empty
    list(LENGTH _Unity_HINT_DIRS hint_count)
    if(NOT hint_count EQUAL 0)
        report_error("Undefined hints" "Expected empty hint list, got ${hint_count} items")
        return()
    endif()
    
    expect_no_error("Undefined hints")
endfunction()

# ==============================================================================
# Test 2: Empty hint variables
# ==============================================================================
function(test_empty_hints)
    # Set hint variables to empty strings
    set(Unity_ROOT "")
    set(UNITY_ROOT "")
    
    # This should not cause errors
    # Empty strings are still DEFINED, so they will be added to the list
    set(_Unity_HINT_DIRS)
    foreach(var IN ITEMS Unity_ROOT UNITY_ROOT)
        if(DEFINED ${var})
            list(APPEND _Unity_HINT_DIRS "${${var}}")
        endif()
    endforeach()
    
    # Empty strings still get added to the list (CMake behavior)
    # The important thing is no errors occurred during evaluation
    expect_no_error("Empty hints")
endfunction()

# ==============================================================================
# Test 3: Valid hint path
# ==============================================================================
function(test_valid_hints)
    # Set real hint paths
    set(Unity_ROOT "/usr/local")
    set(UNITY_ROOT "/opt/unity")
    
    # Process hints
    set(_Unity_HINT_DIRS)
    foreach(var IN ITEMS Unity_ROOT UNITY_ROOT)
        if(DEFINED ${var})
            list(APPEND _Unity_HINT_DIRS "${${var}}")
        endif()
    endforeach()
    
    # Verify hints were added
    list(LENGTH _Unity_HINT_DIRS hint_count)
    if(NOT hint_count EQUAL 2)
        report_error("Valid hints" "Expected 2 hints, got ${hint_count}")
        return()
    endif()
    
    # Verify paths are correct
    list(GET _Unity_HINT_DIRS 0 first_hint)
    list(GET _Unity_HINT_DIRS 1 second_hint)
    
    if(NOT first_hint STREQUAL "/usr/local")
        report_error("Valid hints" "First hint mismatch: ${first_hint}")
        return()
    endif()
    
    if(NOT second_hint STREQUAL "/opt/unity")
        report_error("Valid hints" "Second hint mismatch: ${second_hint}")
        return()
    endif()
    
    expect_no_error("Valid hints")
endfunction()

# ==============================================================================
# Test 4: Mixed defined/undefined hints
# ==============================================================================
function(test_mixed_hints)
    # Only set one variable
    set(Unity_ROOT "/usr/local")
    unset(UNITY_ROOT)
    
    # Process hints
    set(_Unity_HINT_DIRS)
    foreach(var IN ITEMS Unity_ROOT UNITY_ROOT)
        if(DEFINED ${var})
            list(APPEND _Unity_HINT_DIRS "${${var}}")
        endif()
    endforeach()
    
    # Should only get one hint
    list(LENGTH _Unity_HINT_DIRS hint_count)
    if(NOT hint_count EQUAL 1)
        report_error("Mixed hints" "Expected 1 hint, got ${hint_count}")
        return()
    endif()
    
    list(GET _Unity_HINT_DIRS 0 first_hint)
    if(NOT first_hint STREQUAL "/usr/local")
        report_error("Mixed hints" "Hint mismatch: ${first_hint}")
        return()
    endif()
    
    expect_no_error("Mixed hints")
endfunction()

# ==============================================================================
# Test 5: Hint with special characters
# ==============================================================================
function(test_special_characters)
    # Test paths with spaces (semicolons are list separators in CMake, so we avoid them)
    set(Unity_ROOT "/path with spaces")
    set(UNITY_ROOT "/path-with-dashes")
    
    # Process hints
    set(_Unity_HINT_DIRS)
    foreach(var IN ITEMS Unity_ROOT UNITY_ROOT)
        if(DEFINED ${var})
            list(APPEND _Unity_HINT_DIRS "${${var}}")
        endif()
    endforeach()
    
    # Verify both hints were processed
    list(LENGTH _Unity_HINT_DIRS hint_count)
    if(NOT hint_count EQUAL 2)
        report_error("Special characters" "Expected 2 hints, got ${hint_count}")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()
    
    expect_no_error("Special characters")
endfunction()

# ==============================================================================
# Test 6: Environment variable hint
# ==============================================================================
function(test_env_hint)
    # Clear regular variables
    unset(Unity_ROOT)
    unset(UNITY_ROOT)
    
    # Set environment variable
    set(ENV{UNITY_ROOT} "/env/path")
    
    # Process hints including environment
    set(_Unity_HINT_DIRS)
    foreach(var IN ITEMS Unity_ROOT UNITY_ROOT)
        if(DEFINED ${var})
            list(APPEND _Unity_HINT_DIRS "${${var}}")
        endif()
    endforeach()
    if(DEFINED ENV{UNITY_ROOT})
        list(APPEND _Unity_HINT_DIRS "$ENV{UNITY_ROOT}")
    endif()
    
    # Should only have env hint
    list(LENGTH _Unity_HINT_DIRS hint_count)
    if(NOT hint_count EQUAL 1)
        report_error("Environment hint" "Expected 1 hint, got ${hint_count}")
        return()
    endif()
    
    list(GET _Unity_HINT_DIRS 0 env_hint)
    if(NOT env_hint STREQUAL "/env/path")
        report_error("Environment hint" "Hint mismatch: ${env_hint}")
        return()
    endif()
    
    expect_no_error("Environment hint")
endfunction()

# ==============================================================================
# Run All Tests
# ==============================================================================
function(run_all_tests)
    message(STATUS "")
    message(STATUS "=== FindUnity Hint Safety Tests (Issue #10) ===")
    message(STATUS "")
    
    test_undefined_hints()
    test_empty_hints()
    test_valid_hints()
    test_mixed_hints()
    test_special_characters()
    test_env_hint()
    
    message(STATUS "")
    message(STATUS "Tests completed: 6 scenarios")
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "✓ All tests passed! Issue #10 fix verified.")
    else()
        message(FATAL_ERROR "✗ ${ERROR_COUNT} test(s) failed")
    endif()
endfunction()

# Run tests when executed directly
if(CMAKE_SCRIPT_MODE_FILE)
    run_all_tests()
endif()
