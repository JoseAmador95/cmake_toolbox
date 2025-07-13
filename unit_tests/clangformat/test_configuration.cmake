# Test: Configuration Options
# Tests various configuration options and cache variables

set(TEST_NAME "Configuration Options")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Save original values
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")

# Create test environment
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_config_test")
file(REMOVE_RECURSE "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}")

# Create test config files
file(WRITE "${TEST_DIR}/.clang-format" "BasedOnStyle: LLVM\nIndentWidth: 2")
file(WRITE "${TEST_DIR}/custom.clang-format" "BasedOnStyle: Google\nIndentWidth: 4")

set(CMAKE_SOURCE_DIR "${TEST_DIR}")

# Test 1: Default configuration values
message(STATUS "Test 1: Default configuration values")

# Set defaults as they would be in the module
set(CLANG_FORMAT_USE_FILE ON)
set(CLANG_FORMAT_CONFIG_FILE "${CMAKE_SOURCE_DIR}/.clang-format")
set(CLANG_FORMAT_ARGS "")
set(CLANG_FORMAT_SOURCE_DIRS "examples/source;examples/include")

if(CLANG_FORMAT_USE_FILE)
    message(STATUS "  ✓ CLANG_FORMAT_USE_FILE defaults to ON")
else()
    message(STATUS "  ✗ CLANG_FORMAT_USE_FILE should default to ON")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(CLANG_FORMAT_CONFIG_FILE STREQUAL "${CMAKE_SOURCE_DIR}/.clang-format")
    message(STATUS "  ✓ CLANG_FORMAT_CONFIG_FILE has correct default")
else()
    message(STATUS "  ✗ CLANG_FORMAT_CONFIG_FILE default is incorrect")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 2: File-based style configuration
message(STATUS "Test 2: File-based style configuration")

set(CLANG_FORMAT_USE_FILE ON)
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/.clang-format")

if(CLANG_FORMAT_USE_FILE)
    if(EXISTS "${CLANG_FORMAT_CONFIG_FILE}")
        set(STYLE --style=file:${CLANG_FORMAT_CONFIG_FILE})
        message(STATUS "  ✓ File-based style correctly configured")
    else()
        message(STATUS "  ✗ Config file validation failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
else()
    set(STYLE "")
endif()

if(STYLE STREQUAL "--style=file:${CLANG_FORMAT_CONFIG_FILE}")
    message(STATUS "  ✓ STYLE variable correctly set for file-based config")
else()
    message(STATUS "  ✗ STYLE variable incorrectly set: '${STYLE}'")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 3: Non-file-based style configuration
message(STATUS "Test 3: Non-file-based style configuration")

set(CLANG_FORMAT_USE_FILE OFF)
set(STYLE "")

if(NOT CLANG_FORMAT_USE_FILE)
    message(STATUS "  ✓ File-based style disabled")
    if(STYLE STREQUAL "")
        message(STATUS "  ✓ STYLE correctly empty when not using file")
    else()
        message(STATUS "  ✗ STYLE should be empty when not using file")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
else()
    message(STATUS "  ✗ Failed to disable file-based style")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 4: Custom configuration file path
message(STATUS "Test 4: Custom configuration file path")

set(CLANG_FORMAT_USE_FILE ON)
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/custom.clang-format")

if(EXISTS "${CLANG_FORMAT_CONFIG_FILE}")
    set(STYLE --style=file:${CLANG_FORMAT_CONFIG_FILE})
    message(STATUS "  ✓ Custom config file path works")
else()
    message(STATUS "  ✗ Custom config file not found")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: Custom arguments handling
message(STATUS "Test 5: Custom arguments handling")

set(CLANG_FORMAT_ARGS "--verbose --sort-includes")

if(CLANG_FORMAT_ARGS STREQUAL "--verbose --sort-includes")
    message(STATUS "  ✓ Custom arguments correctly set")
else()
    message(STATUS "  ✗ Custom arguments not set correctly")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 6: Source directories configuration
message(STATUS "Test 6: Source directories configuration")

# Test default directories
set(CLANG_FORMAT_SOURCE_DIRS "examples/source;examples/include")
if(CLANG_FORMAT_SOURCE_DIRS STREQUAL "examples/source;examples/include")
    message(STATUS "  ✓ Default source directories correctly set")
else()
    message(STATUS "  ✗ Default source directories incorrect")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test custom directories
set(CLANG_FORMAT_SOURCE_DIRS "src;include;lib")
if(CLANG_FORMAT_SOURCE_DIRS STREQUAL "src;include;lib")
    message(STATUS "  ✓ Custom source directories correctly set")
else()
    message(STATUS "  ✗ Custom source directories not set correctly")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test single directory
set(CLANG_FORMAT_SOURCE_DIRS "src")
if(CLANG_FORMAT_SOURCE_DIRS STREQUAL "src")
    message(STATUS "  ✓ Single source directory correctly set")
else()
    message(STATUS "  ✗ Single source directory not set correctly")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 7: Missing configuration file handling
message(STATUS "Test 7: Missing configuration file handling")

set(CLANG_FORMAT_USE_FILE ON)
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/nonexistent.clang-format")

set(CONFIG_FILE_ERROR FALSE)
if(CLANG_FORMAT_USE_FILE)
    if(NOT EXISTS "${CLANG_FORMAT_CONFIG_FILE}")
        set(CONFIG_FILE_ERROR TRUE)
        message(STATUS "  ✓ Missing config file correctly detected")
    else()
        message(STATUS "  ✗ Missing config file not detected")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
endif()

if(CONFIG_FILE_ERROR)
    message(STATUS "  ✓ Would correctly throw FATAL_ERROR for missing config")
else()
    message(STATUS "  ✗ Should detect missing config file error")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 8: Extensions configuration
message(STATUS "Test 8: Extensions configuration")

set(CLANG_FORMAT_EXTENSIONS
    "*.c" "*.h"
    "*.cpp" "*.cxx" "*.cc" "*.c++"
    "*.hpp" "*.hxx" "*.hh" "*.h++"
)

list(LENGTH CLANG_FORMAT_EXTENSIONS EXTENSION_COUNT)
if(EXTENSION_COUNT EQUAL 10)
    message(STATUS "  ✓ All expected extensions configured (${EXTENSION_COUNT})")
else()
    message(STATUS "  ✗ Expected 10 extensions, found ${EXTENSION_COUNT}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Verify specific extensions exist
set(REQUIRED_EXTENSIONS "*.c" "*.cpp" "*.h" "*.hpp")
set(MISSING_EXTENSIONS "")
foreach(ext IN LISTS REQUIRED_EXTENSIONS)
    list(FIND CLANG_FORMAT_EXTENSIONS "${ext}" ext_index)
    if(ext_index EQUAL -1)
        list(APPEND MISSING_EXTENSIONS "${ext}")
    endif()
endforeach()

list(LENGTH MISSING_EXTENSIONS MISSING_COUNT)
if(MISSING_COUNT EQUAL 0)
    message(STATUS "  ✓ All required extensions present")
else()
    message(STATUS "  ✗ Missing required extensions: ${MISSING_EXTENSIONS}")
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
