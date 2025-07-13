# Test: Edge Cases and Error Conditions
# Tests various edge cases and error handling scenarios

set(TEST_NAME "Edge Cases and Error Conditions")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Save original values
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")

# Create test environment
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_edge_test")
file(REMOVE_RECURSE "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}")

set(CMAKE_SOURCE_DIR "${TEST_DIR}")

# Test 1: No source files found scenario
message(STATUS "Test 1: No source files found scenario")

set(CLANG_FORMAT_SOURCE_DIRS "nonexistent_dir;also_missing")
set(CLANG_FORMAT_EXTENSIONS "*.c" "*.h" "*.cpp" "*.hpp")

set(ALL_SOURCE_FILES "")
set(MISSING_DIRS 0)
foreach(SOURCE_DIR IN LISTS CLANG_FORMAT_SOURCE_DIRS)
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    else()
        math(EXPR MISSING_DIRS "${MISSING_DIRS} + 1")
    endif()
endforeach()

list(LENGTH ALL_SOURCE_FILES SOURCE_COUNT)
if(SOURCE_COUNT EQUAL 0 AND MISSING_DIRS EQUAL 2)
    message(STATUS "  ✓ Correctly handles missing source directories")
else()
    message(STATUS "  ✗ Failed to handle missing directories properly")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 2: Empty source directories
message(STATUS "Test 2: Empty source directories")

file(MAKE_DIRECTORY "${TEST_DIR}/empty1")
file(MAKE_DIRECTORY "${TEST_DIR}/empty2")

set(CLANG_FORMAT_SOURCE_DIRS "empty1;empty2")
set(ALL_SOURCE_FILES "")

foreach(SOURCE_DIR IN LISTS CLANG_FORMAT_SOURCE_DIRS)
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(LENGTH ALL_SOURCE_FILES EMPTY_DIR_COUNT)
if(EMPTY_DIR_COUNT EQUAL 0)
    message(STATUS "  ✓ Correctly handles empty directories")
else()
    message(STATUS "  ✗ Empty directories returned unexpected files")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 3: Mixed valid and invalid directories
message(STATUS "Test 3: Mixed valid and invalid directories")

file(MAKE_DIRECTORY "${TEST_DIR}/valid_dir")
file(WRITE "${TEST_DIR}/valid_dir/test.c" "int main() { return 0; }")

set(CLANG_FORMAT_SOURCE_DIRS "valid_dir;invalid_dir")
set(ALL_SOURCE_FILES "")
set(VALID_DIRS 0)
set(INVALID_DIRS 0)

foreach(SOURCE_DIR IN LISTS CLANG_FORMAT_SOURCE_DIRS)
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        math(EXPR VALID_DIRS "${VALID_DIRS} + 1")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    else()
        math(EXPR INVALID_DIRS "${INVALID_DIRS} + 1")
    endif()
endforeach()

list(LENGTH ALL_SOURCE_FILES MIXED_DIR_COUNT)
if(MIXED_DIR_COUNT EQUAL 1 AND VALID_DIRS EQUAL 1 AND INVALID_DIRS EQUAL 1)
    message(STATUS "  ✓ Correctly handles mixed valid/invalid directories")
else()
    message(STATUS "  ✗ Failed to handle mixed directories: ${MIXED_DIR_COUNT} files, ${VALID_DIRS} valid, ${INVALID_DIRS} invalid")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 4: Configuration file edge cases
message(STATUS "Test 4: Configuration file edge cases")

# Test with missing config file
set(CLANG_FORMAT_USE_FILE ON)
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/missing.clang-format")

set(CONFIG_ERROR_DETECTED FALSE)
if(CLANG_FORMAT_USE_FILE)
    if(NOT EXISTS "${CLANG_FORMAT_CONFIG_FILE}")
        set(CONFIG_ERROR_DETECTED TRUE)
    endif()
endif()

if(CONFIG_ERROR_DETECTED)
    message(STATUS "  ✓ Correctly detects missing config file")
else()
    message(STATUS "  ✗ Failed to detect missing config file")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test with valid config file
file(WRITE "${TEST_DIR}/.clang-format" "BasedOnStyle: LLVM")
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/.clang-format")

if(EXISTS "${CLANG_FORMAT_CONFIG_FILE}")
    message(STATUS "  ✓ Correctly validates existing config file")
else()
    message(STATUS "  ✗ Failed to validate existing config file")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: File extension edge cases
message(STATUS "Test 5: File extension edge cases")

# Create files with various extensions and names
file(MAKE_DIRECTORY "${TEST_DIR}/extension_test")
set(TEST_FILES
    "normal.c"
    "normal.cpp"
    "normal.h"
    "normal.hpp"
    "file.with.dots.c"
    "FILE.C"  # Different case
    "no_extension"
    "README.md"
    ".hidden.c"
    "script.sh"
)

foreach(test_file IN LISTS TEST_FILES)
    file(WRITE "${TEST_DIR}/extension_test/${test_file}" "// content")
endforeach()

set(CLANG_FORMAT_EXTENSIONS "*.c" "*.cpp" "*.h" "*.hpp")
set(ALL_SOURCE_FILES "")

set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/extension_test")
foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
    file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
    list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES EXTENSION_COUNT)

# Should find: normal.c, normal.cpp, normal.h, normal.hpp, file.with.dots.c, .hidden.c
# Note: FILE.C might not match on case-sensitive systems
if(EXTENSION_COUNT GREATER_EQUAL 5 AND EXTENSION_COUNT LESS_EQUAL 6)
    message(STATUS "  ✓ Extension matching works correctly (${EXTENSION_COUNT} files)")
else()
    message(STATUS "  ✗ Extension matching failed: expected 5-6 files, got ${EXTENSION_COUNT}")
    foreach(file IN LISTS ALL_SOURCE_FILES)
        message(STATUS "    Found: ${file}")
    endforeach()
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 6: Duplicate file handling
message(STATUS "Test 6: Duplicate file handling")

file(MAKE_DIRECTORY "${TEST_DIR}/dup_test/subdir")
file(WRITE "${TEST_DIR}/dup_test/test.c" "// content")
file(WRITE "${TEST_DIR}/dup_test/subdir/test.c" "// content")

set(ALL_SOURCE_FILES "")
# Simulate finding the same file through different patterns
foreach(EXTENSION IN ITEMS "*.c")
    file(GLOB_RECURSE FOUND_FILES "${TEST_DIR}/dup_test/${EXTENSION}")
    list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
    # Add again to simulate duplicate discovery
    list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
endforeach()

list(LENGTH ALL_SOURCE_FILES BEFORE_DEDUP)
list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES AFTER_DEDUP)

if(BEFORE_DEDUP EQUAL 4 AND AFTER_DEDUP EQUAL 2)
    message(STATUS "  ✓ Duplicate removal works correctly")
else()
    message(STATUS "  ✗ Duplicate removal failed: ${BEFORE_DEDUP} -> ${AFTER_DEDUP}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 7: Very long file paths
message(STATUS "Test 7: Very long file paths")

set(LONG_PATH "${TEST_DIR}/very/long/nested/directory/structure/that/goes/quite/deep")
file(MAKE_DIRECTORY "${LONG_PATH}")
file(WRITE "${LONG_PATH}/deep_file.c" "// deep content")

set(ALL_SOURCE_FILES "")
file(GLOB_RECURSE FOUND_FILES "${TEST_DIR}/very/**/*.c")
list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})

list(LENGTH ALL_SOURCE_FILES DEEP_FILE_COUNT)
if(DEEP_FILE_COUNT EQUAL 1)
    message(STATUS "  ✓ Handles deeply nested files correctly")
else()
    message(STATUS "  ✗ Failed to find deeply nested files")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 8: Empty source directories variable
message(STATUS "Test 8: Empty source directories variable")

set(CLANG_FORMAT_SOURCE_DIRS "")
set(ALL_SOURCE_FILES "")

# This should result in no directories to process
foreach(SOURCE_DIR IN LISTS CLANG_FORMAT_SOURCE_DIRS)
    # Should not execute since list is empty
    message(STATUS "  ✗ Should not process empty directory list")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endforeach()

list(LENGTH CLANG_FORMAT_SOURCE_DIRS EMPTY_DIR_LIST_COUNT)
if(EMPTY_DIR_LIST_COUNT EQUAL 0)
    message(STATUS "  ✓ Correctly handles empty source directories list")
else()
    message(STATUS "  ✗ Empty source directories list not handled correctly")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 9: Special characters in file names
message(STATUS "Test 9: Special characters in file names")

file(MAKE_DIRECTORY "${TEST_DIR}/special_chars")
set(SPECIAL_FILES
    "file with spaces.c"
    "file-with-dashes.cpp"
    "file_with_underscores.h"
    "file+with+plus.hpp"
)

foreach(special_file IN LISTS SPECIAL_FILES)
    file(WRITE "${TEST_DIR}/special_chars/${special_file}" "// special content")
endforeach()

set(ALL_SOURCE_FILES "")
file(GLOB_RECURSE FOUND_FILES "${TEST_DIR}/special_chars/*.c")
file(GLOB_RECURSE FOUND_FILES2 "${TEST_DIR}/special_chars/*.cpp")
file(GLOB_RECURSE FOUND_FILES3 "${TEST_DIR}/special_chars/*.h")
file(GLOB_RECURSE FOUND_FILES4 "${TEST_DIR}/special_chars/*.hpp")

list(APPEND ALL_SOURCE_FILES ${FOUND_FILES} ${FOUND_FILES2} ${FOUND_FILES3} ${FOUND_FILES4})
list(LENGTH ALL_SOURCE_FILES SPECIAL_CHAR_COUNT)

if(SPECIAL_CHAR_COUNT EQUAL 4)
    message(STATUS "  ✓ Handles special characters in filenames")
else()
    message(STATUS "  ✗ Failed with special characters: expected 4, got ${SPECIAL_CHAR_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Clean up
file(REMOVE_RECURSE "${TEST_DIR}")
set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}")

# Test Summary
message(STATUS "")
if(ERROR_COUNT EQUAL 0)
    message(STATUS "✓ All ${TEST_NAME} tests passed!")
else()
    message(STATUS "✗ ${ERROR_COUNT} test(s) failed in ${TEST_NAME}")
endif()
message(STATUS "")
