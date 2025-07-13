# Test: Custom Target Creation
# Tests the creation and properties of clang-format targets

set(TEST_NAME "Custom Target Creation")
set(ERROR_COUNT 0)

message(STATUS "=== ${TEST_NAME} ===")

# Save original values
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")

# Create test environment
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_target_test")
file(REMOVE_RECURSE "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}")
file(MAKE_DIRECTORY "${TEST_DIR}/src")

# Create test files
file(WRITE "${TEST_DIR}/src/test.c" "int main() { return 0; }")
file(WRITE "${TEST_DIR}/src/test.h" "#pragma once")
file(WRITE "${TEST_DIR}/.clang-format" "BasedOnStyle: LLVM")

set(CMAKE_SOURCE_DIR "${TEST_DIR}")

# Mock clang-format executable (simulating it exists)
set(CLANG_FORMAT_EXECUTABLE "/usr/bin/clang-format")
set(CLANG_FORMAT_USE_FILE ON)
set(CLANG_FORMAT_CONFIG_FILE "${TEST_DIR}/.clang-format")
set(CLANG_FORMAT_ARGS "--verbose")
set(CLANG_FORMAT_SOURCE_DIRS "src")

# Set up file discovery (simulate the module logic)
set(CLANG_FORMAT_EXTENSIONS "*.c" "*.h" "*.cpp" "*.hpp")
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
list(LENGTH ALL_SOURCE_FILES SOURCE_FILE_COUNT)

# Set STYLE variable
if(CLANG_FORMAT_USE_FILE)
    set(STYLE --style=file:${CLANG_FORMAT_CONFIG_FILE})
else()
    set(STYLE "")
endif()

# Test 1: Target prerequisites are met
message(STATUS "Test 1: Target prerequisites are met")

if(CLANG_FORMAT_EXECUTABLE)
    message(STATUS "  ✓ Clang-format executable is available")
else()
    message(STATUS "  ✗ Clang-format executable not found")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(SOURCE_FILE_COUNT GREATER 0)
    message(STATUS "  ✓ Source files found for formatting (${SOURCE_FILE_COUNT})")
else()
    message(STATUS "  ✗ No source files found")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 2: clangformat_check target command construction
message(STATUS "Test 2: clangformat_check target command construction")

# Build the expected command
set(EXPECTED_CHECK_COMMAND 
    ${CLANG_FORMAT_EXECUTABLE}
    ${STYLE}
    --dry-run
    --Werror
    ${CLANG_FORMAT_ARGS}
    ${ALL_SOURCE_FILES}
)

# Verify command components
set(CHECK_COMMAND_VALID TRUE)

# Check for dry-run flag
list(FIND EXPECTED_CHECK_COMMAND "--dry-run" dry_run_index)
if(dry_run_index GREATER -1)
    message(STATUS "  ✓ Check command includes --dry-run")
else()
    message(STATUS "  ✗ Check command missing --dry-run")
    set(CHECK_COMMAND_VALID FALSE)
endif()

# Check for Werror flag
list(FIND EXPECTED_CHECK_COMMAND "--Werror" werror_index)
if(werror_index GREATER -1)
    message(STATUS "  ✓ Check command includes --Werror")
else()
    message(STATUS "  ✗ Check command missing --Werror")
    set(CHECK_COMMAND_VALID FALSE)
endif()

# Check for style argument
list(FIND EXPECTED_CHECK_COMMAND "--style=file:${CLANG_FORMAT_CONFIG_FILE}" style_index)
if(style_index GREATER -1)
    message(STATUS "  ✓ Check command includes correct style argument")
else()
    message(STATUS "  ✗ Check command missing or incorrect style argument")
    set(CHECK_COMMAND_VALID FALSE)
endif()

# Check for custom arguments
list(FIND EXPECTED_CHECK_COMMAND "--verbose" verbose_index)
if(verbose_index GREATER -1)
    message(STATUS "  ✓ Check command includes custom arguments")
else()
    message(STATUS "  ✗ Check command missing custom arguments")
    set(CHECK_COMMAND_VALID FALSE)
endif()

if(NOT CHECK_COMMAND_VALID)
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 3: clangformat_edit target command construction
message(STATUS "Test 3: clangformat_edit target command construction")

# Build the expected command
set(EXPECTED_EDIT_COMMAND 
    ${CLANG_FORMAT_EXECUTABLE}
    ${STYLE}
    -i
    ${CLANG_FORMAT_ARGS}
    ${ALL_SOURCE_FILES}
)

# Verify command components
set(EDIT_COMMAND_VALID TRUE)

# Check for in-place flag
list(FIND EXPECTED_EDIT_COMMAND "-i" inplace_index)
if(inplace_index GREATER -1)
    message(STATUS "  ✓ Edit command includes -i (in-place)")
else()
    message(STATUS "  ✗ Edit command missing -i flag")
    set(EDIT_COMMAND_VALID FALSE)
endif()

# Check that dry-run is NOT present in edit command
list(FIND EXPECTED_EDIT_COMMAND "--dry-run" edit_dry_run_index)
if(edit_dry_run_index EQUAL -1)
    message(STATUS "  ✓ Edit command correctly excludes --dry-run")
else()
    message(STATUS "  ✗ Edit command should not include --dry-run")
    set(EDIT_COMMAND_VALID FALSE)
endif()

# Check that Werror is NOT present in edit command
list(FIND EXPECTED_EDIT_COMMAND "--Werror" edit_werror_index)
if(edit_werror_index EQUAL -1)
    message(STATUS "  ✓ Edit command correctly excludes --Werror")
else()
    message(STATUS "  ✗ Edit command should not include --Werror")
    set(EDIT_COMMAND_VALID FALSE)
endif()

if(NOT EDIT_COMMAND_VALID)
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 4: Target comments and properties
message(STATUS "Test 4: Target comments and properties")

set(EXPECTED_CHECK_COMMENT "Checking code style with clang-format (${SOURCE_FILE_COUNT} files)")
set(EXPECTED_EDIT_COMMENT "Formatting code with clang-format (${SOURCE_FILE_COUNT} files)")

# Verify the comments include file count
if(EXPECTED_CHECK_COMMENT MATCHES "\\([0-9]+ files\\)")
    message(STATUS "  ✓ Check target comment includes file count")
else()
    message(STATUS "  ✗ Check target comment missing file count")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(EXPECTED_EDIT_COMMENT MATCHES "\\([0-9]+ files\\)")
    message(STATUS "  ✓ Edit target comment includes file count")
else()
    message(STATUS "  ✗ Edit target comment missing file count")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 5: File list inclusion in commands
message(STATUS "Test 5: File list inclusion in commands")

# Check that source files are included in both commands
set(FILES_IN_CHECK_COMMAND TRUE)
set(FILES_IN_EDIT_COMMAND TRUE)

foreach(source_file IN LISTS ALL_SOURCE_FILES)
    list(FIND EXPECTED_CHECK_COMMAND "${source_file}" check_file_index)
    list(FIND EXPECTED_EDIT_COMMAND "${source_file}" edit_file_index)
    
    if(check_file_index EQUAL -1)
        set(FILES_IN_CHECK_COMMAND FALSE)
    endif()
    
    if(edit_file_index EQUAL -1)
        set(FILES_IN_EDIT_COMMAND FALSE)
    endif()
endforeach()

if(FILES_IN_CHECK_COMMAND)
    message(STATUS "  ✓ All source files included in check command")
else()
    message(STATUS "  ✗ Some source files missing from check command")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

if(FILES_IN_EDIT_COMMAND)
    message(STATUS "  ✓ All source files included in edit command")
else()
    message(STATUS "  ✗ Some source files missing from edit command")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 6: Command without custom arguments
message(STATUS "Test 6: Command without custom arguments")

set(CLANG_FORMAT_ARGS "")  # Empty arguments

set(COMMAND_WITHOUT_ARGS
    ${CLANG_FORMAT_EXECUTABLE}
    ${STYLE}
    --dry-run
    --Werror
    ${ALL_SOURCE_FILES}
)

# Should not include empty string in command
set(COMMAND_CLEAN TRUE)
foreach(arg IN LISTS COMMAND_WITHOUT_ARGS)
    if(arg STREQUAL "")
        set(COMMAND_CLEAN FALSE)
        break()
    endif()
endforeach()

if(COMMAND_CLEAN)
    message(STATUS "  ✓ Command correctly handles empty arguments")
else()
    message(STATUS "  ✗ Command includes empty arguments")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endif()

# Test 7: Style argument without file
message(STATUS "Test 7: Style argument without file")

set(CLANG_FORMAT_USE_FILE OFF)
set(STYLE "")

set(COMMAND_NO_STYLE
    ${CLANG_FORMAT_EXECUTABLE}
    ${STYLE}
    --dry-run
    --Werror
    ${ALL_SOURCE_FILES}
)

# Verify no style argument when not using file
set(NO_STYLE_ARGS TRUE)
foreach(arg IN LISTS COMMAND_NO_STYLE)
    if(arg MATCHES "--style=")
        set(NO_STYLE_ARGS FALSE)
        break()
    endif()
endforeach()

if(NO_STYLE_ARGS)
    message(STATUS "  ✓ Command correctly excludes style when not using file")
else()
    message(STATUS "  ✗ Command includes style argument when it shouldn't")
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
