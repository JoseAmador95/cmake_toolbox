# Test: File Discovery Functionality
# Tests source file discovery and pattern matching

set(TEST_NAME "File Discovery Functionality")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Create a temporary test directory with various file types
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_file_discovery_test")
file(REMOVE_RECURSE "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}/src")
file(MAKE_DIRECTORY "${TEST_DIR}/include")
file(MAKE_DIRECTORY "${TEST_DIR}/nested/deep")

# Create test files with different extensions
set(TEST_FILES
    "src/main.c"
    "src/utils.cpp" 
    "src/helper.cxx"
    "src/core.cc"
    "src/module.c++"
    "include/api.h"
    "include/types.hpp"
    "include/config.hxx"
    "include/defs.hh"
    "include/interface.h++"
    "nested/deep/buried.c"
    "README.md"  # Should be ignored
    "src/data.txt"  # Should be ignored
)

foreach(file_path IN LISTS TEST_FILES)
    file(WRITE "${TEST_DIR}/${file_path}" "// Test file content")
endforeach()

# Override CMAKE_SOURCE_DIR for testing
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
set(CMAKE_SOURCE_DIR "${TEST_DIR}")

# Test 1: All C/C++ extensions are discovered
message(STATUS "Test 1: All C/C++ extensions are discovered")
set(CLANG_FORMAT_EXTENSIONS
    "*.c" "*.h"
    "*.cpp" "*.cxx" "*.cc" "*.c++"
    "*.hpp" "*.hxx" "*.hh" "*.h++"
)

set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "src" "include" "nested")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES TOTAL_FILES)

# Should find 11 C/C++ files (excluding README.md and data.txt)
if(TOTAL_FILES EQUAL 11)
    message(STATUS "  ✓ Found all ${TOTAL_FILES} C/C++ source files")
else()
    message(STATUS "  ✗ Expected 11 files, found ${TOTAL_FILES}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    foreach(file IN LISTS ALL_SOURCE_FILES)
        message(STATUS "    Found: ${file}")
    endforeach()
endif()

# Test 2: Specific directory filtering
message(STATUS "Test 2: Specific directory filtering")
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "src")  # Only src directory
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES SRC_FILES)

# Should find 5 files in src directory
if(SRC_FILES EQUAL 5)
    message(STATUS "  ✓ Found ${SRC_FILES} files in src directory")
else()
    message(STATUS "  ✗ Expected 5 files in src, found ${SRC_FILES}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 3: Header files only
message(STATUS "Test 3: Header files only")
set(HEADER_EXTENSIONS "*.h" "*.hpp" "*.hxx" "*.hh" "*.h++")
set(ALL_HEADER_FILES "")

foreach(SOURCE_DIR IN ITEMS "include")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS HEADER_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_HEADER_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_HEADER_FILES)
list(LENGTH ALL_HEADER_FILES HEADER_COUNT)

# Should find 5 header files
if(HEADER_COUNT EQUAL 5)
    message(STATUS "  ✓ Found ${HEADER_COUNT} header files")
else()
    message(STATUS "  ✗ Expected 5 header files, found ${HEADER_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 4: Recursive discovery in nested directories
message(STATUS "Test 4: Recursive discovery in nested directories")
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "nested")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES NESTED_FILES)

# Should find 1 file in nested directory
if(NESTED_FILES EQUAL 1)
    message(STATUS "  ✓ Found ${NESTED_FILES} file in nested directory")
else()
    message(STATUS "  ✗ Expected 1 file in nested directory, found ${NESTED_FILES}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: Non-existent directory handling
message(STATUS "Test 5: Non-existent directory handling")
set(MISSING_DIR_COUNT 0)
foreach(SOURCE_DIR IN ITEMS "nonexistent" "also_missing")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(NOT IS_DIRECTORY "${FULL_SOURCE_DIR}")
        math(EXPR MISSING_DIR_COUNT "${MISSING_DIR_COUNT} + 1")
    endif()
endforeach()

if(MISSING_DIR_COUNT EQUAL 2)
    message(STATUS "  ✓ Correctly identified ${MISSING_DIR_COUNT} missing directories")
else()
    message(STATUS "  ✗ Failed to identify missing directories")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 6: Empty directory handling
message(STATUS "Test 6: Empty directory handling")
file(MAKE_DIRECTORY "${TEST_DIR}/empty_dir")

set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "empty_dir")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(LENGTH ALL_SOURCE_FILES EMPTY_DIR_FILES)

if(EMPTY_DIR_FILES EQUAL 0)
    message(STATUS "  ✓ Empty directory correctly returned no files")
else()
    message(STATUS "  ✗ Empty directory unexpectedly returned ${EMPTY_DIR_FILES} files")
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
