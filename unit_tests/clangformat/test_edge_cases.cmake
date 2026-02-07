# Test: Edge Cases and Error Conditions
# Tests various edge cases and error handling scenarios

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormat.cmake)

set(ERROR_COUNT 0)
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_edge_test")

function(setup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    
    set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}" PARENT_SCOPE)
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_nonexistent_directories)
    message(STATUS "Test 1: Nonexistent source directories")
    
    ClangFormat_CollectFiles(EMPTY_RESULT
        SOURCE_DIRS nonexistent_dir also_missing
    )
    
    list(LENGTH EMPTY_RESULT result_count)
    if(result_count EQUAL 0)
        message(STATUS "  ✓ Correctly handles nonexistent directories")
    else()
        message(STATUS "  ✗ Expected 0 files from nonexistent directories, got ${result_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_empty_directories)
    message(STATUS "Test 2: Empty source directories")
    
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/empty1")
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/empty2")
    
    ClangFormat_CollectFiles(EMPTY_DIR_RESULT
        SOURCE_DIRS empty1 empty2
    )
    
    list(LENGTH EMPTY_DIR_RESULT empty_count)
    if(empty_count EQUAL 0)
        message(STATUS "  ✓ Correctly handles empty directories")
    else()
        message(STATUS "  ✗ Expected 0 files from empty directories, got ${empty_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_special_filenames)
    message(STATUS "Test 3: Special filenames and characters")
    
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/special")
    
    # Create files with special characters
    file(WRITE "${CMAKE_SOURCE_DIR}/special/file with spaces.c" "// content")
    file(WRITE "${CMAKE_SOURCE_DIR}/special/file-with-dashes.cpp" "// content")
    file(WRITE "${CMAKE_SOURCE_DIR}/special/file_with_underscores.h" "// content")
    file(WRITE "${CMAKE_SOURCE_DIR}/special/UPPERCASE.C" "// content")
    
    ClangFormat_CollectFiles(SPECIAL_FILES
        SOURCE_DIRS special
    )
    
    list(LENGTH SPECIAL_FILES special_count)
    if(special_count EQUAL 4)
        message(STATUS "  ✓ Handles special filenames correctly")
    else()
        message(STATUS "  ✗ Expected 4 special files, got ${special_count}")
        message(STATUS "    Files: ${SPECIAL_FILES}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_config_validation_edge_cases)
    message(STATUS "Test 4: Config validation edge cases")
    
    # Test with empty string
    ClangFormat_ValidateConfig("" EMPTY_RESULT)
    if(EMPTY_RESULT STREQUAL "")
        message(STATUS "  ✓ Empty config path handled correctly")
    else()
        message(STATUS "  ✗ Empty config should return empty, got: '${EMPTY_RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Test with directory instead of file
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/config_dir")
    ClangFormat_ValidateConfig("${CMAKE_SOURCE_DIR}/config_dir" DIR_RESULT)
    if(DIR_RESULT STREQUAL "")
        message(STATUS "  ✓ Directory path correctly rejected")
    else()
        message(STATUS "  ✗ Directory should be rejected, got: '${DIR_RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_command_creation_edge_cases)
    message(STATUS "Test 5: Command creation edge cases")
    
    # Test with empty file list
    ClangFormat_CreateCommand(EMPTY_COMMAND
        EXECUTABLE clang-format
        MODE FORMAT
        FILES ""
    )
    
    if(EMPTY_COMMAND)
        message(STATUS "  ✓ Command created even with empty file list")
    else()
        message(STATUS "  ✗ Command should be created with empty file list")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Test with no style argument
    ClangFormat_CreateCommand(NO_STYLE_COMMAND
        EXECUTABLE clang-format
        MODE FORMAT
        FILES "test.c"
    )
    
    if(NO_STYLE_COMMAND)
        message(STATUS "  ✓ Command created without style argument")
    else()
        message(STATUS "  ✗ Command should be created without style argument")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_exclusion_edge_cases)
    message(STATUS "Test 6: Exclusion pattern edge cases")
    
    file(MAKE_DIRECTORY "${CMAKE_SOURCE_DIR}/exclude_test")
    file(WRITE "${CMAKE_SOURCE_DIR}/exclude_test/normal.c" "// content")
    file(WRITE "${CMAKE_SOURCE_DIR}/exclude_test/test.c" "// content")
    
    # Test with empty exclusion patterns
    ClangFormat_CollectFiles(NO_EXCLUDE_RESULT
        SOURCE_DIRS exclude_test
        EXCLUDE_PATTERNS ""
    )
    
    list(LENGTH NO_EXCLUDE_RESULT no_exclude_count)
    if(no_exclude_count EQUAL 2)
        message(STATUS "  ✓ Empty exclusion patterns work correctly")
    else()
        message(STATUS "  ✗ Expected 2 files with empty exclusions, got ${no_exclude_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Test exclusion that matches nothing
    ClangFormat_CollectFiles(NO_MATCH_RESULT
        SOURCE_DIRS exclude_test
        EXCLUDE_PATTERNS ".*nomatch.*"
    )
    
    list(LENGTH NO_MATCH_RESULT no_match_count)
    if(no_match_count EQUAL 2)
        message(STATUS "  ✓ Non-matching exclusion patterns work correctly")
    else()
        message(STATUS "  ✗ Expected 2 files with non-matching exclusions, got ${no_match_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat Edge Cases Tests ===")
    
    setup_test_environment()
    test_nonexistent_directories()
    test_empty_directories()
    test_special_filenames()
    test_config_validation_edge_cases()
    test_command_creation_edge_cases()
    test_exclusion_edge_cases()
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
