# Test: File Exclusion Functionality
# Tests the exclude patterns feature for filtering out unwanted files

set(TEST_NAME "File Exclusion Functionality")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Create a temporary test directory with various file types
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_exclusion_demo")
file(REMOVE_RECURSE "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}/src")
file(MAKE_DIRECTORY "${TEST_DIR}/include")
file(MAKE_DIRECTORY "${TEST_DIR}/tests")
file(MAKE_DIRECTORY "${TEST_DIR}/generated")

# Create test files with different names and locations
set(TEST_FILES
    "src/main.c"
    "src/utils.cpp"
    "src/test_helper.c"      # Should be excluded by pattern "*test*"
    "src/mock_device.c"      # Should be excluded by pattern "*mock*"
    "include/api.h"
    "include/test_api.h"     # Should be excluded by pattern "*test*"
    "include/generated.h"    # Should be excluded by pattern "generated*"
    "tests/unit_test.c"      # Should be excluded by directory pattern "tests/*"
    "generated/auto_gen.c"   # Should be excluded by directory pattern "generated/*"
    "generated/parser.h"     # Should be excluded by directory pattern "generated/*"
    "src/temp.c"             # Should be excluded by pattern "temp.*"
    "src/backup.c.bak"       # Should be excluded by pattern "*.bak"
)

foreach(file_path IN LISTS TEST_FILES)
    file(WRITE "${TEST_DIR}/${file_path}" "// Test file content")
endforeach()

# Override CMAKE_SOURCE_DIR for testing
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
set(CMAKE_SOURCE_DIR "${TEST_DIR}")

set(CLANG_FORMAT_EXTENSIONS
    "*.c" "*.h" "*.cpp" "*.hpp"
)

# Test 1: No exclusion patterns (baseline)
message(STATUS "Test 1: No exclusion patterns (baseline)")
set(CLANG_FORMAT_EXCLUDE_PATTERNS "")

set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "src" "include" "tests" "generated")
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

# Should find all 11 files (.bak file should not be found due to extension mismatch)
if(BASELINE_COUNT EQUAL 11)
    message(STATUS "  ✓ Found all ${BASELINE_COUNT} source files without exclusions")
else()
    message(STATUS "  ✗ Expected 11 files, found ${BASELINE_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    foreach(file IN LISTS ALL_SOURCE_FILES)
        message(STATUS "    Found: ${file}")
    endforeach()
endif()

# Test 2: Exclude files with "test" in the name
message(STATUS "Test 2: Exclude files with 'test' in the name")
set(CLANG_FORMAT_EXCLUDE_PATTERNS "*test*")

# Reset and collect files
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "src" "include" "tests" "generated")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES ORIGINAL_FILE_COUNT)

# Helper function to apply exclusion patterns
function(apply_exclusion_patterns input_files output_files_var)
    if(CLANG_FORMAT_EXCLUDE_PATTERNS)
        set(FILTERED_SOURCE_FILES "")
        foreach(source_file IN LISTS input_files)
            set(EXCLUDE_FILE FALSE)
            foreach(pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
                string(REPLACE "*" ".*" regex_pattern "${pattern}")
                string(REPLACE "?" "." regex_pattern "${regex_pattern}")
                
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
        
        set(${output_files_var} "${FILTERED_SOURCE_FILES}" PARENT_SCOPE)
    else()
        set(${output_files_var} "${input_files}" PARENT_SCOPE)
    endif()
endfunction()

list(LENGTH ALL_SOURCE_FILES FILTERED_COUNT)

# Should exclude: test_helper.c, test_api.h, unit_test.c = 3 files
# Remaining: 11 - 3 = 8 files
if(FILTERED_COUNT EQUAL 8)
    message(STATUS "  ✓ Correctly excluded test files (${FILTERED_COUNT} remaining)")
else()
    message(STATUS "  ✗ Expected 8 files after exclusion, found ${FILTERED_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    foreach(file IN LISTS ALL_SOURCE_FILES)
        message(STATUS "    Remaining: ${file}")
    endforeach()
endif()

# Test 3: Exclude multiple patterns
message(STATUS "Test 3: Exclude multiple patterns")
set(CLANG_FORMAT_EXCLUDE_PATTERNS "*test*;*mock*;generated*")

# Reset and collect files again
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "src" "include" "tests" "generated")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

# Apply exclude patterns
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            string(REPLACE "*" ".*" regex_pattern "${pattern}")
            string(REPLACE "?" "." regex_pattern "${regex_pattern}")
            
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

list(LENGTH ALL_SOURCE_FILES MULTI_FILTERED_COUNT)

# Should exclude: test_helper.c, test_api.h, unit_test.c, mock_device.c, generated.h = 5 files
# Remaining: 11 - 5 = 6 files
if(MULTI_FILTERED_COUNT EQUAL 6)
    message(STATUS "  ✓ Correctly excluded multiple patterns (${MULTI_FILTERED_COUNT} remaining)")
else()
    message(STATUS "  ✗ Expected 6 files after multiple exclusions, found ${MULTI_FILTERED_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    foreach(file IN LISTS ALL_SOURCE_FILES)
        message(STATUS "    Remaining: ${file}")
    endforeach()
endif()

# Test 4: Exclude by directory pattern
message(STATUS "Test 4: Exclude by directory pattern")
set(CLANG_FORMAT_EXCLUDE_PATTERNS "*/tests/*;*/generated/*")

# Reset and collect files again
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "src" "include" "tests" "generated")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

# Apply exclude patterns
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            string(REPLACE "*" ".*" regex_pattern "${pattern}")
            string(REPLACE "?" "." regex_pattern "${regex_pattern}")
            
            if(source_file MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
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

list(LENGTH ALL_SOURCE_FILES DIR_FILTERED_COUNT)

# Should exclude: unit_test.c, auto_gen.c, parser.h = 3 files
# Remaining: 11 - 3 = 8 files
if(DIR_FILTERED_COUNT EQUAL 8)
    message(STATUS "  ✓ Correctly excluded directory patterns (${DIR_FILTERED_COUNT} remaining)")
else()
    message(STATUS "  ✗ Expected 8 files after directory exclusions, found ${DIR_FILTERED_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    foreach(file IN LISTS ALL_SOURCE_FILES)
        message(STATUS "    Remaining: ${file}")
    endforeach()
endif()

# Test 5: Exclude with wildcard patterns
message(STATUS "Test 5: Exclude with wildcard patterns")
set(CLANG_FORMAT_EXCLUDE_PATTERNS "temp.*")

# Reset and collect files again
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "src" "include" "tests" "generated")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

# Apply exclude patterns
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            string(REPLACE "*" ".*" regex_pattern "${pattern}")
            string(REPLACE "?" "." regex_pattern "${regex_pattern}")
            
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
            
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
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

list(LENGTH ALL_SOURCE_FILES WILDCARD_FILTERED_COUNT)

# Should exclude: temp.c = 1 file
# Remaining: 11 - 1 = 10 files
if(WILDCARD_FILTERED_COUNT EQUAL 10)
    message(STATUS "  ✓ Correctly excluded wildcard patterns (${WILDCARD_FILTERED_COUNT} remaining)")
else()
    message(STATUS "  ✗ Expected 10 files after wildcard exclusions, found ${WILDCARD_FILTERED_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 6: Empty exclusion patterns
message(STATUS "Test 6: Empty exclusion patterns")
set(CLANG_FORMAT_EXCLUDE_PATTERNS "")

# Reset and collect files again
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "src" "include" "tests" "generated")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES EMPTY_PATTERN_COUNT)

# No exclusion logic should run, so should find all files
if(EMPTY_PATTERN_COUNT EQUAL 11)
    message(STATUS "  ✓ Empty exclusion patterns work correctly (${EMPTY_PATTERN_COUNT} files)")
else()
    message(STATUS "  ✗ Expected 11 files with empty exclusions, found ${EMPTY_PATTERN_COUNT}")
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
