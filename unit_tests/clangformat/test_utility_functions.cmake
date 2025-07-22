# Test: ClangFormat Utility Functions
# Tests the actual ClangFormat utility function implementations

# Include the actual modules we want to test
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormat.cmake)

set(TEST_NAME "ClangFormat Utility Functions")
set(ERROR_COUNT 0)

# Save original CMAKE_SOURCE_DIR
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")

# Create test environment
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_utility_test")

function(setup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}/src")
    file(MAKE_DIRECTORY "${TEST_DIR}/include")
    file(MAKE_DIRECTORY "${TEST_DIR}/nested/deep")

    # Create test files with various extensions
    file(WRITE "${TEST_DIR}/src/main.c" "int main() { return 0; }")
    file(WRITE "${TEST_DIR}/src/utils.cpp" "void func() {}")
    file(WRITE "${TEST_DIR}/src/legacy.cxx" "class Test {};")
    file(WRITE "${TEST_DIR}/include/header.h" "#pragma once")
    file(WRITE "${TEST_DIR}/include/header.hpp" "#pragma once")
    file(WRITE "${TEST_DIR}/nested/deep/nested.c" "int nested() { return 1; }")
    file(WRITE "${TEST_DIR}/src/README.txt" "not a source file")
    file(WRITE "${TEST_DIR}/.clang-format" "BasedOnStyle: Google\nIndentWidth: 4\n")

    # Set test directory as CMAKE_SOURCE_DIR for testing
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_validate_config)
    message(STATUS "Test 1: ClangFormat_ValidateConfig function")

    # Test with existing config file
    ClangFormat_ValidateConfig("${TEST_DIR}/.clang-format" RESULT)
    if(RESULT STREQUAL "--style=file:${TEST_DIR}/.clang-format")
        message(STATUS "  ✓ ValidateConfig works with existing file")
    else()
        message(STATUS "  ✗ ValidateConfig failed: expected '--style=file:${TEST_DIR}/.clang-format', got '${RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()

    # Test with non-existing config file
    ClangFormat_ValidateConfig("${TEST_DIR}/missing.clang-format" RESULT)
    if(RESULT STREQUAL "")
        message(STATUS "  ✓ ValidateConfig correctly handles missing file")
    else()
        message(STATUS "  ✗ ValidateConfig should return empty for missing file, got '${RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_collect_files)
    message(STATUS "Test 2: ClangFormat_CollectFiles function")

    # Test with default patterns
    ClangFormat_CollectFiles(
        COLLECTED_FILES
        SOURCE_DIRS "src" "include" "nested"
    )

    # Verify specific files were found and .txt was excluded
    set(EXPECTED_FILES 
        "${TEST_DIR}/src/main.c"
        "${TEST_DIR}/src/utils.cpp"
        "${TEST_DIR}/src/legacy.cxx"
        "${TEST_DIR}/include/header.h"
        "${TEST_DIR}/include/header.hpp"
        "${TEST_DIR}/nested/deep/nested.c"
    )

    list(LENGTH EXPECTED_FILES expected_count)
    list(LENGTH COLLECTED_FILES file_count)
    if(file_count EQUAL expected_count)
        message(STATUS "  ✓ CollectFiles found expected ${expected_count} files")
    else()
        message(STATUS "  ✗ Expected ${expected_count} files, found ${file_count}")
        message(STATUS "    Found files: ${COLLECTED_FILES}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()

    foreach(expected_file IN LISTS EXPECTED_FILES)
        list(FIND COLLECTED_FILES "${expected_file}" file_index)
        if(file_index EQUAL -1)
            message(STATUS "  ✗ Missing expected file: ${expected_file}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endforeach()

    # Verify .txt file was not included
    list(FIND COLLECTED_FILES "${TEST_DIR}/src/README.txt" txt_index)
    if(txt_index EQUAL -1)
        message(STATUS "  ✓ Correctly excluded non-source files")
    else()
        message(STATUS "  ✗ Incorrectly included .txt file")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()

    # Test with custom patterns
    ClangFormat_CollectFiles(
        COLLECTED_FILES
        SOURCE_DIRS "src"
        PATTERNS "*.c"
    )

    list(LENGTH COLLECTED_FILES c_file_count)
    if(c_file_count EQUAL 1)
        message(STATUS "  ✓ Custom pattern *.c found 1 file")
    else()
        message(STATUS "  ✗ Expected 1 *.c file, found ${c_file_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_create_command)
    message(STATUS "Test 3: ClangFormat_CreateCommand function")

    set(TEST_FILES "${TEST_DIR}/src/main.c" "${TEST_DIR}/include/header.h")

    # Test FORMAT mode - this is the main use case
    ClangFormat_CreateCommand(
        FORMAT_COMMAND
        EXECUTABLE "clang-format-10"
        STYLE_ARG "--style=Google"
        MODE "FORMAT"
        FILES ${TEST_FILES}
        ADDITIONAL_ARGS "--verbose"
    )

    # Verify the command starts with the executable
    list(GET FORMAT_COMMAND 0 format_exe)
    if(format_exe STREQUAL "clang-format-10")
        message(STATUS "  ✓ FORMAT command uses correct executable")
    else()
        message(STATUS "  ✗ FORMAT command should start with clang-format-10, got: ${format_exe}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()

    # Check for -i flag (in-place editing)
    list(FIND FORMAT_COMMAND "-i" i_flag_index)
    if(i_flag_index GREATER -1)
        message(STATUS "  ✓ FORMAT command includes -i flag for in-place editing")
    else()
        message(STATUS "  ✗ FORMAT command missing -i flag")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()

    # Check that files are included
    foreach(test_file IN LISTS TEST_FILES)
        list(FIND FORMAT_COMMAND "${test_file}" file_index)
        if(file_index GREATER -1)
            message(STATUS "  ✓ FORMAT command includes file: ${test_file}")
        else()
            message(STATUS "  ✗ FORMAT command missing file: ${test_file}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            break()
        endif()
    endforeach()

    # Test CHECK mode - verify it's different from FORMAT mode
    ClangFormat_CreateCommand(
        CHECK_COMMAND
        EXECUTABLE "clang-format-10"
        STYLE_ARG "--style=Google"
        MODE "CHECK"
        FILES ${TEST_FILES}
    )

    # The check command should be different from format command
    if(NOT CHECK_COMMAND STREQUAL FORMAT_COMMAND)
        message(STATUS "  ✓ CHECK command is different from FORMAT command")
    else()
        message(STATUS "  ✗ CHECK and FORMAT commands should be different")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()

    # Check command should not include -i flag (since it's not formatting in-place)
    list(FIND CHECK_COMMAND "-i" check_i_flag)
    if(check_i_flag EQUAL -1)
        message(STATUS "  ✓ CHECK command correctly excludes -i flag")
    else()
        message(STATUS "  ✗ CHECK command should not include -i flag for in-place editing")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_error_handling)
    message(STATUS "Test 4: Error handling")

    # Test CollectFiles with missing SOURCE_DIRS - this should produce a warning
    # but we can't easily test FATAL_ERROR in script mode, so we'll test the warning case
    ClangFormat_CollectFiles(
        EMPTY_FILES
        SOURCE_DIRS "nonexistent"
    )

    list(LENGTH EMPTY_FILES empty_count)
    if(empty_count EQUAL 0)
        message(STATUS "  ✓ CollectFiles handles non-existent directories correctly")
    else()
        message(STATUS "  ✗ Non-existent directory should yield no files, got ${empty_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    # Clean up
    file(REMOVE_RECURSE "${TEST_DIR}")

    # Restore original CMAKE_SOURCE_DIR
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== ${TEST_NAME} ===")
    
    setup_test_environment()
    test_validate_config()
    test_collect_files()
    test_create_command()
    test_error_handling()
    cleanup_test_environment()

    # Test Summary
    message(STATUS "")
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "✓ All ${TEST_NAME} tests passed!")
    else()
        message(STATUS "✗ ${ERROR_COUNT} test(s) failed in ${TEST_NAME}")
    endif()
    message(STATUS "")
endfunction()

# Run tests if this file is executed directly
if(CMAKE_SCRIPT_MODE_FILE)
    run_all_tests()
endif()