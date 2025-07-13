# Test: Regex Pattern Exclusion
# Tests the regex-based exclusion patterns functionality

set(TEST_NAME "Regex Pattern Exclusion")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Save original values
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")

# Create test environment
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_regex_test")
file(REMOVE_RECURSE "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}/src")
file(MAKE_DIRECTORY "${TEST_DIR}/include")
file(MAKE_DIRECTORY "${TEST_DIR}/generated")
file(MAKE_DIRECTORY "${TEST_DIR}/tests")

# Create test files with various patterns
set(TEST_FILES
    "src/main.c"
    "src/utils.cpp" 
    "src/helper.h"
    "src/test_file.c"
    "src/unit_test.cpp"
    "include/api.h"
    "include/types.hpp"
    "include/test_api.h"
    "generated/auto_gen.c"
    "generated/parser.h"
    "tests/test_main.c"
    "tests/unit_tests.cpp"
)

foreach(file_path IN LISTS TEST_FILES)
    file(WRITE "${TEST_DIR}/${file_path}" "// Test file content")
endforeach()

set(CMAKE_SOURCE_DIR "${TEST_DIR}")
set(CLANG_FORMAT_SOURCE_DIRS "src;include;generated;tests")
set(CLANG_FORMAT_EXTENSIONS "*.c" "*.cpp" "*.h" "*.hpp")

# Collect all files (baseline)
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

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES BASELINE_COUNT)

# Test 1: Simple regex pattern - exclude all test files
message(STATUS "Test 1: Simple regex pattern - exclude test files")

set(CLANG_FORMAT_EXCLUDE_PATTERNS ".*test.*")

# Apply regex exclusion (simulate the module logic)
set(ORIGINAL_FILE_COUNT ${BASELINE_COUNT})
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(regex_pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            # Check relative path from CMAKE_SOURCE_DIR
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            # Check just the filename
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
        endforeach()
        
        if(NOT EXCLUDE_FILE)
            list(APPEND FILTERED_SOURCE_FILES "${source_file}")
        endif()
    endforeach()
    
    set(ALL_SOURCE_FILES "${FILTERED_SOURCE_FILES}")
endif()

list(LENGTH ALL_SOURCE_FILES AFTER_TEST_EXCLUDE_COUNT)
math(EXPR EXCLUDED_TEST_COUNT "${ORIGINAL_FILE_COUNT} - ${AFTER_TEST_EXCLUDE_COUNT}")

# Should exclude 4 files: test_file.c, unit_test.cpp, test_api.h, test_main.c, unit_tests.cpp
if(EXCLUDED_TEST_COUNT EQUAL 5 AND AFTER_TEST_EXCLUDE_COUNT EQUAL 7)
    message(STATUS "  ✓ Correctly excluded ${EXCLUDED_TEST_COUNT} test files with regex")
else()
    message(STATUS "  ✗ Expected to exclude 5 test files, excluded ${EXCLUDED_TEST_COUNT}, remaining ${AFTER_TEST_EXCLUDE_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 2: Directory-specific regex pattern
message(STATUS "Test 2: Directory-specific regex pattern")

# Reset to baseline
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
list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

set(CLANG_FORMAT_EXCLUDE_PATTERNS "^generated/.*")

# Apply exclusion
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(regex_pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
        endforeach()
        
        if(NOT EXCLUDE_FILE)
            list(APPEND FILTERED_SOURCE_FILES "${source_file}")
        endif()
    endforeach()
    
    set(ALL_SOURCE_FILES "${FILTERED_SOURCE_FILES}")
endif()

list(LENGTH ALL_SOURCE_FILES AFTER_DIR_EXCLUDE_COUNT)
math(EXPR EXCLUDED_DIR_COUNT "${ORIGINAL_FILE_COUNT} - ${AFTER_DIR_EXCLUDE_COUNT}")

# Should exclude 2 files from generated/ directory
if(EXCLUDED_DIR_COUNT EQUAL 2 AND AFTER_DIR_EXCLUDE_COUNT EQUAL 10)
    message(STATUS "  ✓ Correctly excluded ${EXCLUDED_DIR_COUNT} files from generated/ with regex")
else()
    message(STATUS "  ✗ Expected to exclude 2 files from generated/, excluded ${EXCLUDED_DIR_COUNT}, remaining ${AFTER_DIR_EXCLUDE_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 3: Complex regex with alternation
message(STATUS "Test 3: Complex regex with alternation")

# Reset to baseline
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
list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

set(CLANG_FORMAT_EXCLUDE_PATTERNS "(generated|tests)/.*")

# Apply exclusion
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(regex_pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
        endforeach()
        
        if(NOT EXCLUDE_FILE)
            list(APPEND FILTERED_SOURCE_FILES "${source_file}")
        endif()
    endforeach()
    
    set(ALL_SOURCE_FILES "${FILTERED_SOURCE_FILES}")
endif()

list(LENGTH ALL_SOURCE_FILES AFTER_COMPLEX_EXCLUDE_COUNT)
math(EXPR EXCLUDED_COMPLEX_COUNT "${ORIGINAL_FILE_COUNT} - ${AFTER_COMPLEX_EXCLUDE_COUNT}")

# Should exclude 4 files: 2 from generated/ + 2 from tests/
if(EXCLUDED_COMPLEX_COUNT EQUAL 4 AND AFTER_COMPLEX_EXCLUDE_COUNT EQUAL 8)
    message(STATUS "  ✓ Correctly excluded ${EXCLUDED_COMPLEX_COUNT} files with complex regex")
else()
    message(STATUS "  ✗ Expected to exclude 4 files with complex regex, excluded ${EXCLUDED_COMPLEX_COUNT}, remaining ${AFTER_COMPLEX_EXCLUDE_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 4: File extension regex
message(STATUS "Test 4: File extension regex")

# Reset to baseline
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
list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

set(CLANG_FORMAT_EXCLUDE_PATTERNS ".*\\.(cpp|hpp)$")

# Apply exclusion
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(regex_pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
        endforeach()
        
        if(NOT EXCLUDE_FILE)
            list(APPEND FILTERED_SOURCE_FILES "${source_file}")
        endif()
    endforeach()
    
    set(ALL_SOURCE_FILES "${FILTERED_SOURCE_FILES}")
endif()

list(LENGTH ALL_SOURCE_FILES AFTER_EXT_EXCLUDE_COUNT)
math(EXPR EXCLUDED_EXT_COUNT "${ORIGINAL_FILE_COUNT} - ${AFTER_EXT_EXCLUDE_COUNT}")

# Should exclude 3 files: utils.cpp, types.hpp, unit_test.cpp, unit_tests.cpp
if(EXCLUDED_EXT_COUNT EQUAL 4 AND AFTER_EXT_EXCLUDE_COUNT EQUAL 8)
    message(STATUS "  ✓ Correctly excluded ${EXCLUDED_EXT_COUNT} C++ files with extension regex")
else()
    message(STATUS "  ✗ Expected to exclude 4 C++ files, excluded ${EXCLUDED_EXT_COUNT}, remaining ${AFTER_EXT_EXCLUDE_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: Multiple regex patterns
message(STATUS "Test 5: Multiple regex patterns")

# Reset to baseline
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
list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

set(CLANG_FORMAT_EXCLUDE_PATTERNS "^generated/.*;.*test.*")

# Apply exclusion
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(regex_pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
        endforeach()
        
        if(NOT EXCLUDE_FILE)
            list(APPEND FILTERED_SOURCE_FILES "${source_file}")
        endif()
    endforeach()
    
    set(ALL_SOURCE_FILES "${FILTERED_SOURCE_FILES}")
endif()

list(LENGTH ALL_SOURCE_FILES AFTER_MULTI_EXCLUDE_COUNT)
math(EXPR EXCLUDED_MULTI_COUNT "${ORIGINAL_FILE_COUNT} - ${AFTER_MULTI_EXCLUDE_COUNT}")

# Should exclude: 2 from generated/ + 5 with "test" = 7 files
if(EXCLUDED_MULTI_COUNT EQUAL 7 AND AFTER_MULTI_EXCLUDE_COUNT EQUAL 5)
    message(STATUS "  ✓ Correctly excluded ${EXCLUDED_MULTI_COUNT} files with multiple regex patterns")
else()
    message(STATUS "  ✗ Expected to exclude 7 files with multiple patterns, excluded ${EXCLUDED_MULTI_COUNT}, remaining ${AFTER_MULTI_EXCLUDE_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 6: Case-sensitive regex
message(STATUS "Test 6: Case-sensitive regex")

# Add files with different cases
file(WRITE "${TEST_DIR}/src/Test_Upper.c" "// Test file")
file(WRITE "${TEST_DIR}/src/TEST_ALL.h" "// Test file")

# Rebuild file list
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
list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

set(CLANG_FORMAT_EXCLUDE_PATTERNS ".*test.*")  # lowercase only

# Apply exclusion
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(regex_pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
        endforeach()
        
        if(NOT EXCLUDE_FILE)
            list(APPEND FILTERED_SOURCE_FILES "${source_file}")
        endif()
    endforeach()
    
    set(ALL_SOURCE_FILES "${FILTERED_SOURCE_FILES}")
endif()

list(LENGTH ALL_SOURCE_FILES AFTER_CASE_EXCLUDE_COUNT)

# Should exclude lowercase "test" files but not "Test" or "TEST"
set(FOUND_TEST_UPPER FALSE)
set(FOUND_TEST_ALL FALSE)
foreach(file IN LISTS ALL_SOURCE_FILES)
    get_filename_component(filename "${file}" NAME)
    if(filename MATCHES "Test_Upper")
        set(FOUND_TEST_UPPER TRUE)
    endif()
    if(filename MATCHES "TEST_ALL")
        set(FOUND_TEST_ALL TRUE)
    endif()
endforeach()

if(FOUND_TEST_UPPER AND FOUND_TEST_ALL)
    message(STATUS "  ✓ Case-sensitive regex correctly preserved uppercase TEST files")
else()
    message(STATUS "  ✗ Case-sensitive regex failed to preserve uppercase files")
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
