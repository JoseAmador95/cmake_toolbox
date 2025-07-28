# Test: Command Creation Functionality
# Tests the ClangFormat_CreateCommand function with various scenarios

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormat.cmake)

set(ERROR_COUNT 0)
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_command_test")

function(setup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}/src")

    # Create test files
    file(WRITE "${TEST_DIR}/src/test.c" "int main() { return 0; }")
    file(WRITE "${TEST_DIR}/src/test.h" "#pragma once")
    file(WRITE "${TEST_DIR}/.clang-format" "BasedOnStyle: LLVM")

    set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}" PARENT_SCOPE)
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_format_command_creation)
    message(STATUS "Test 1: FORMAT command creation")
    
    set(TEST_FILES "${CMAKE_SOURCE_DIR}/src/test.c" "${CMAKE_SOURCE_DIR}/src/test.h")
    
    ClangFormat_CreateCommand(FORMAT_CMD
        EXECUTABLE clang-format
        STYLE_ARG "--style=Google"
        MODE FORMAT
        FILES ${TEST_FILES}
        ADDITIONAL_ARGS "--verbose"
    )
    
    # Verify command structure
    list(GET FORMAT_CMD 0 exe)
    if(exe STREQUAL "clang-format")
        message(STATUS "  ✓ FORMAT command uses correct executable")
    else()
        message(STATUS "  ✗ Wrong executable: ${exe}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Check for -i flag
    list(FIND FORMAT_CMD "-i" i_index)
    if(i_index GREATER -1)
        message(STATUS "  ✓ FORMAT command includes -i flag")
    else()
        message(STATUS "  ✗ FORMAT command missing -i flag")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Check for style argument
    list(FIND FORMAT_CMD "--style=Google" style_index)
    if(style_index GREATER -1)
        message(STATUS "  ✓ FORMAT command includes style argument")
    else()
        message(STATUS "  ✗ FORMAT command missing style argument")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_check_command_creation)
    message(STATUS "Test 2: CHECK command creation")
    
    set(TEST_FILES "${CMAKE_SOURCE_DIR}/src/test.c")
    
    ClangFormat_CreateCommand(CHECK_CMD
        EXECUTABLE clang-format
        STYLE_ARG "--style=file:${CMAKE_SOURCE_DIR}/.clang-format"
        MODE CHECK
        FILES ${TEST_FILES}
    )
    
    # CHECK command should use CMAKE_COMMAND for cross-platform compatibility
    list(GET CHECK_CMD 0 cmd_exe)
    if(cmd_exe STREQUAL "${CMAKE_COMMAND}")
        message(STATUS "  ✓ CHECK command uses CMAKE_COMMAND")
    else()
        message(STATUS "  ✗ CHECK command should use CMAKE_COMMAND, got: ${cmd_exe}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Check command should NOT include -i flag
    list(FIND CHECK_CMD "-i" i_index)
    if(i_index EQUAL -1)
        message(STATUS "  ✓ CHECK command correctly excludes -i flag")
    else()
        message(STATUS "  ✗ CHECK command should not include -i flag")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_command_without_style)
    message(STATUS "Test 3: Command creation without style argument")
    
    ClangFormat_CreateCommand(NO_STYLE_CMD
        EXECUTABLE clang-format
        MODE FORMAT
        FILES "${CMAKE_SOURCE_DIR}/src/test.c"
    )
    
    if(NO_STYLE_CMD)
        message(STATUS "  ✓ Command created successfully without style")
        
        # Should still have executable and -i flag for FORMAT mode
        list(GET NO_STYLE_CMD 0 exe)
        list(FIND NO_STYLE_CMD "-i" i_index)
        
        if(exe STREQUAL "clang-format" AND i_index GREATER -1)
            message(STATUS "  ✓ Command structure correct without style")
        else()
            message(STATUS "  ✗ Command structure incorrect without style")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    else()
        message(STATUS "  ✗ Command creation failed without style")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_command_with_additional_args)
    message(STATUS "Test 4: Command creation with additional arguments")
    
    ClangFormat_CreateCommand(EXTRA_ARGS_CMD
        EXECUTABLE clang-format
        MODE FORMAT
        FILES "${CMAKE_SOURCE_DIR}/src/test.c"
        ADDITIONAL_ARGS "--verbose" "--assume-filename=.cpp"
    )
    
    # Check for additional arguments
    list(FIND EXTRA_ARGS_CMD "--verbose" verbose_index)
    list(FIND EXTRA_ARGS_CMD "--assume-filename=.cpp" assume_index)
    
    if(verbose_index GREATER -1 AND assume_index GREATER -1)
        message(STATUS "  ✓ Additional arguments included correctly")
    else()
        message(STATUS "  ✗ Additional arguments missing")
        message(STATUS "    Command: ${EXTRA_ARGS_CMD}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_command_with_multiple_files)
    message(STATUS "Test 5: Command creation with multiple files")
    
    set(MULTIPLE_FILES 
        "${CMAKE_SOURCE_DIR}/src/test.c"
        "${CMAKE_SOURCE_DIR}/src/test.h"
    )
    
    ClangFormat_CreateCommand(MULTI_FILE_CMD
        EXECUTABLE clang-format
        MODE FORMAT
        FILES ${MULTIPLE_FILES}
    )
    
    # Check that both files are included
    set(all_files_found TRUE)
    foreach(test_file IN LISTS MULTIPLE_FILES)
        list(FIND MULTI_FILE_CMD "${test_file}" file_index)
        if(file_index EQUAL -1)
            set(all_files_found FALSE)
            break()
        endif()
    endforeach()
    
    if(all_files_found)
        message(STATUS "  ✓ Multiple files included correctly")
    else()
        message(STATUS "  ✗ Not all files included in command")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat Command Creation Tests ===")
    
    setup_test_environment()
    test_format_command_creation()
    test_check_command_creation()
    test_command_without_style()
    test_command_with_additional_args()
    test_command_with_multiple_files()
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
