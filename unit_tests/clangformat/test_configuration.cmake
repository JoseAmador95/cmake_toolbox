# Test: Configuration Options
# Tests various configuration options and validation

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormat.cmake)

set(ERROR_COUNT 0)
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_config_test")

function(setup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    
    # Create test config files
    file(WRITE "${TEST_DIR}/.clang-format" "BasedOnStyle: LLVM\nIndentWidth: 2")
    file(WRITE "${TEST_DIR}/custom.clang-format" "BasedOnStyle: Google\nIndentWidth: 4")
    
    set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}" PARENT_SCOPE)
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_default_config_file)
    message(STATUS "Test 1: Default .clang-format file validation")
    
    ClangFormat_ValidateConfig("${CMAKE_SOURCE_DIR}/.clang-format" RESULT)
    if(RESULT STREQUAL "--style=file:${CMAKE_SOURCE_DIR}/.clang-format")
        message(STATUS "  ✓ Default .clang-format file validation works")
    else()
        message(STATUS "  ✗ Default config validation failed, got: '${RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_custom_config_file)
    message(STATUS "Test 2: Custom config file validation")
    
    ClangFormat_ValidateConfig("${CMAKE_SOURCE_DIR}/custom.clang-format" RESULT)
    if(RESULT STREQUAL "--style=file:${CMAKE_SOURCE_DIR}/custom.clang-format")
        message(STATUS "  ✓ Custom config file validation works")
    else()
        message(STATUS "  ✗ Custom config validation failed, got: '${RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_missing_config_file)
    message(STATUS "Test 3: Missing config file handling")
    
    ClangFormat_ValidateConfig("${CMAKE_SOURCE_DIR}/nonexistent.clang-format" RESULT)
    if(RESULT STREQUAL "")
        message(STATUS "  ✓ Missing config file correctly returns empty")
    else()
        message(STATUS "  ✗ Missing config should return empty, got: '${RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_absolute_vs_relative_paths)
    message(STATUS "Test 4: Absolute vs relative path handling")
    
    # Test with absolute path
    ClangFormat_ValidateConfig("${CMAKE_SOURCE_DIR}/.clang-format" ABSOLUTE_RESULT)
    
    # Test with relative path (should still work as the function uses the path as-is)
    ClangFormat_ValidateConfig(".clang-format" RELATIVE_RESULT)
    
    if(ABSOLUTE_RESULT AND RELATIVE_RESULT)
        message(STATUS "  ✓ Both absolute and relative paths produce results")
    else()
        message(STATUS "  ✗ Path handling failed")
        message(STATUS "    Absolute: '${ABSOLUTE_RESULT}'")
        message(STATUS "    Relative: '${RELATIVE_RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat Configuration Tests ===")
    
    setup_test_environment()
    test_default_config_file()
    test_custom_config_file()
    test_missing_config_file()
    test_absolute_vs_relative_paths()
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
