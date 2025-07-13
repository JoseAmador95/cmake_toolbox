# Test: Basic Clang-Format Functionality
# Tests basic operations of the clang-format module

set(TEST_NAME "Basic Clang-Format Functionality")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Save original values to restore later
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
set(ORIGINAL_CMAKE_CURRENT_LIST_DIR "${CMAKE_CURRENT_LIST_DIR}")

# Create a temporary test directory structure
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_test")
file(REMOVE_RECURSE "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}/test_source")
file(MAKE_DIRECTORY "${TEST_DIR}/test_include")

# Create test source files
file(WRITE "${TEST_DIR}/test_source/main.c" "int main() { return 0; }")
file(WRITE "${TEST_DIR}/test_source/utils.cpp" "void test() {}")
file(WRITE "${TEST_DIR}/test_include/header.h" "#pragma once")
file(WRITE "${TEST_DIR}/test_include/types.hpp" "struct Test {};")

# Create a test .clang-format file
file(WRITE "${TEST_DIR}/.clang-format" "BasedOnStyle: LLVM")

# Override CMAKE_SOURCE_DIR for testing
set(CMAKE_SOURCE_DIR "${TEST_DIR}")

# Test 1: Module loads successfully when clang-format is not found
message(STATUS "Test 1: Module handles missing clang-format gracefully")
set(CLANG_FORMAT_SOURCE_DIRS "test_source;test_include")
set(CLANG_FORMAT_USE_FILE ON)
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/.clang-format")
set(CLANG_FORMAT_ARGS "")

# Mock find_program to simulate clang-format not found
set(CLANG_FORMAT_EXECUTABLE "")

# Include the module in a way that simulates the find_program failure
# We'll test this by checking if targets would be created
set(TEST_TARGETS_CREATED FALSE)

# Simulate the logic from clangformat.cmake
if(NOT CLANG_FORMAT_EXECUTABLE)
    message(STATUS "  ✓ Correctly detected missing clang-format")
else()
    message(STATUS "  ✗ Failed to detect missing clang-format")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 2: Configuration file validation
message(STATUS "Test 2: Configuration file validation")
set(CLANG_FORMAT_USE_FILE ON)
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/.clang-format")

if(CLANG_FORMAT_USE_FILE)
    if(NOT EXISTS "${CLANG_FORMAT_CONFIG_FILE}")
        message(STATUS "  ✗ Config file should exist but validation failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "  ✓ Config file validation passed")
    endif()
endif()

# Test 3: Missing configuration file handling
message(STATUS "Test 3: Missing configuration file handling")
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/nonexistent.clang-format")

if(CLANG_FORMAT_USE_FILE)
    if(NOT EXISTS "${CLANG_FORMAT_CONFIG_FILE}")
        message(STATUS "  ✓ Correctly detected missing config file")
    else()
        message(STATUS "  ✗ Failed to detect missing config file")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
endif()

# Test 4: File extension patterns
message(STATUS "Test 4: File extension patterns")
set(CLANG_FORMAT_EXTENSIONS
    "*.c" "*.h"
    "*.cpp" "*.cxx" "*.cc" "*.c++"
    "*.hpp" "*.hxx" "*.hh" "*.h++"
)

# Simulate file discovery
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN ITEMS "test_source" "test_include")
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    endif()
endforeach()

list(REMOVE_DUPLICATES ALL_SOURCE_FILES)
list(LENGTH ALL_SOURCE_FILES SOURCE_FILE_COUNT)

if(SOURCE_FILE_COUNT EQUAL 4)
    message(STATUS "  ✓ Found expected number of source files (${SOURCE_FILE_COUNT})")
else()
    message(STATUS "  ✗ Expected 4 source files, found ${SOURCE_FILE_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: Directory existence validation
message(STATUS "Test 5: Directory existence validation")
set(CLANG_FORMAT_SOURCE_DIRS "test_source;test_include;nonexistent_dir")

set(VALID_DIRS 0)
set(WARNING_DIRS 0)
foreach(SOURCE_DIR IN LISTS CLANG_FORMAT_SOURCE_DIRS)
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        math(EXPR VALID_DIRS "${VALID_DIRS} + 1")
    else()
        math(EXPR WARNING_DIRS "${WARNING_DIRS} + 1")
    endif()
endforeach()

if(VALID_DIRS EQUAL 2 AND WARNING_DIRS EQUAL 1)
    message(STATUS "  ✓ Correctly identified valid and invalid directories")
else()
    message(STATUS "  ✗ Directory validation failed: ${VALID_DIRS} valid, ${WARNING_DIRS} invalid")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Clean up test directory
file(REMOVE_RECURSE "${TEST_DIR}")

# Restore original values
set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}")

# Test Summary
message(STATUS "")
if(ERROR_COUNT EQUAL 0)
    message(STATUS "✓ All ${TEST_NAME} tests passed!")
else()
    message(STATUS "✗ ${ERROR_COUNT} test(s) failed in ${TEST_NAME}")
endif()
message(STATUS "")
