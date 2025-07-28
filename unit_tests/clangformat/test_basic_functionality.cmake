# Test: Basic Clang-Format Functionality
# Tests basic operations of the clang-format module

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormat.cmake)

set(ERROR_COUNT 0)
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_test")

function(setup_test_environment)
    # Create test directories and files
    file(REMOVE_RECURSE "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}/src")
    file(MAKE_DIRECTORY "${TEST_DIR}/include")
    
    # Create test source files
    file(WRITE "${TEST_DIR}/src/main.c" "int main() { return 0; }")
    file(WRITE "${TEST_DIR}/src/utils.cpp" "void test() {}")
    file(WRITE "${TEST_DIR}/include/header.h" "#pragma once")
    file(WRITE "${TEST_DIR}/include/types.hpp" "struct Test {};")
    
    # Create a test .clang-format file
    file(WRITE "${TEST_DIR}/.clang-format" "BasedOnStyle: LLVM")
    
    # Set up test environment variables
    set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}" PARENT_SCOPE)
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_config_validation)
    message(STATUS "Test 1: ClangFormat_ValidateConfig with existing file")
    
    ClangFormat_ValidateConfig("${CMAKE_SOURCE_DIR}/.clang-format" RESULT)
    if(RESULT STREQUAL "--style=file:${CMAKE_SOURCE_DIR}/.clang-format")
        message(STATUS "  ✓ Config validation works with existing file")
    else()
        message(STATUS "  ✗ Expected style argument, got '${RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_config_missing_file)
    message(STATUS "Test 2: ClangFormat_ValidateConfig with missing file")
    
    ClangFormat_ValidateConfig("${CMAKE_SOURCE_DIR}/nonexistent.clang-format" RESULT)
    if(RESULT STREQUAL "")
        message(STATUS "  ✓ Config validation correctly handles missing file")
    else()
        message(STATUS "  ✗ Expected empty result for missing file, got '${RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_file_collection)
    message(STATUS "Test 3: ClangFormat_CollectFiles basic functionality")
    
    ClangFormat_CollectFiles(COLLECTED_FILES
        SOURCE_DIRS src include
    )
    
    list(LENGTH COLLECTED_FILES file_count)
    set(EXPECTED_FILES "main.c" "utils.cpp" "header.h" "types.hpp")
    list(LENGTH EXPECTED_FILES expected_count)
    
    if(file_count EQUAL expected_count)
        message(STATUS "  ✓ Found expected ${expected_count} files")
    else()
        message(STATUS "  ✗ Expected ${expected_count} files, found ${file_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_file_collection_error_handling)
    message(STATUS "Test 4: ClangFormat_CollectFiles error handling")
    
    # Test missing SOURCE_DIRS parameter - this should cause FATAL_ERROR
    # We can't easily test FATAL_ERROR in unit tests, so we'll test the validation
    set(TEST_PASSED FALSE)
    
    # Test with nonexistent directory (should produce warning but continue)
    ClangFormat_CollectFiles(COLLECTED_FILES
        SOURCE_DIRS nonexistent_dir
    )
    
    list(LENGTH COLLECTED_FILES file_count)
    if(file_count EQUAL 0)
        message(STATUS "  ✓ Correctly handled nonexistent directory")
        set(TEST_PASSED TRUE)
    else()
        message(STATUS "  ✗ Expected 0 files from nonexistent directory, found ${file_count}")
    endif()
    
    if(NOT TEST_PASSED)
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_command_creation)
    message(STATUS "Test 5: ClangFormat_CreateCommand functionality")
    
    # Test FORMAT mode
    set(TEST_FILES "${CMAKE_SOURCE_DIR}/src/main.c" "${CMAKE_SOURCE_DIR}/include/header.h")
    ClangFormat_CreateCommand(FORMAT_COMMAND
        EXECUTABLE clang-format
        STYLE_ARG "--style=file:${CMAKE_SOURCE_DIR}/.clang-format"
        MODE FORMAT
        FILES ${TEST_FILES}
    )
    
    list(GET FORMAT_COMMAND 0 exe)
    list(FIND FORMAT_COMMAND "-i" i_flag_index)
    
    if(exe STREQUAL "clang-format" AND i_flag_index GREATER -1)
        message(STATUS "  ✓ FORMAT command created correctly")
    else()
        message(STATUS "  ✗ FORMAT command not created correctly")
        message(STATUS "    Expected: clang-format with -i flag")
        message(STATUS "    Got: ${FORMAT_COMMAND}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    # Clean up test files and restore original state
    file(REMOVE_RECURSE "${TEST_DIR}")
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat Basic Functionality Tests ===")
    
    setup_test_environment()
    test_config_validation()
    test_config_missing_file()
    test_file_collection()
    test_file_collection_error_handling()
    test_command_creation()
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
