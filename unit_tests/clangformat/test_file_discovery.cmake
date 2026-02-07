# Test: File Discovery Functionality
# Tests source file discovery and pattern matching

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormat.cmake)

set(ERROR_COUNT 0)
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_file_discovery_test")

function(setup_test_environment)
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

    set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}" PARENT_SCOPE)
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_default_patterns)
    message(STATUS "Test 1: Default pattern file discovery")
    
    ClangFormat_CollectFiles(DISCOVERED_FILES
        SOURCE_DIRS src include nested
    )
    
    # Count expected source files (excluding README.md and data.txt)
    set(EXPECTED_SOURCE_FILES
        "${CMAKE_SOURCE_DIR}/src/main.c"
        "${CMAKE_SOURCE_DIR}/src/utils.cpp"
        "${CMAKE_SOURCE_DIR}/src/helper.cxx"
        "${CMAKE_SOURCE_DIR}/src/core.cc"
        "${CMAKE_SOURCE_DIR}/src/module.c++"
        "${CMAKE_SOURCE_DIR}/include/api.h"
        "${CMAKE_SOURCE_DIR}/include/types.hpp"
        "${CMAKE_SOURCE_DIR}/include/config.hxx"
        "${CMAKE_SOURCE_DIR}/include/defs.hh"
        "${CMAKE_SOURCE_DIR}/include/interface.h++"
        "${CMAKE_SOURCE_DIR}/nested/deep/buried.c"
    )
    
    list(LENGTH EXPECTED_SOURCE_FILES expected_count)
    list(LENGTH DISCOVERED_FILES actual_count)
    
    if(actual_count EQUAL expected_count)
        message(STATUS "  ✓ Found expected ${expected_count} source files")
    else()
        message(STATUS "  ✗ Expected ${expected_count} files, found ${actual_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Verify non-source files are excluded
    foreach(discovered_file IN LISTS DISCOVERED_FILES)
        if(discovered_file MATCHES "README\\.md|data\\.txt")
            message(STATUS "  ✗ Non-source file incorrectly included: ${discovered_file}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

function(test_custom_patterns)
    message(STATUS "Test 2: Custom pattern file discovery")
    
    # Test with only C files
    ClangFormat_CollectFiles(C_FILES
        SOURCE_DIRS src nested
        PATTERNS "*.c"
    )
    
    list(LENGTH C_FILES c_count)
    if(c_count EQUAL 2)  # main.c and buried.c
        message(STATUS "  ✓ Custom *.c pattern found 2 files")
    else()
        message(STATUS "  ✗ Expected 2 *.c files, found ${c_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Test with multiple custom patterns
    ClangFormat_CollectFiles(CPP_FILES
        SOURCE_DIRS src
        PATTERNS "*.cpp" "*.cxx"
    )
    
    list(LENGTH CPP_FILES cpp_count)
    if(cpp_count EQUAL 2)  # utils.cpp and helper.cxx
        message(STATUS "  ✓ Multiple custom patterns found 2 files")
    else()
        message(STATUS "  ✗ Expected 2 C++ files, found ${cpp_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_recursive_discovery)
    message(STATUS "Test 3: Recursive directory discovery")
    
    ClangFormat_CollectFiles(NESTED_FILES
        SOURCE_DIRS nested
        PATTERNS "*.c"
    )
    
    list(LENGTH NESTED_FILES nested_count)
    if(nested_count EQUAL 1)  # only buried.c in nested/deep/
        message(STATUS "  ✓ Recursive discovery found nested file")
        
        # Verify it's the correct file
        list(GET NESTED_FILES 0 found_file)
        if(found_file STREQUAL "${CMAKE_SOURCE_DIR}/nested/deep/buried.c")
            message(STATUS "  ✓ Found correct nested file path")
        else()
            message(STATUS "  ✗ Wrong nested file found: ${found_file}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    else()
        message(STATUS "  ✗ Expected 1 nested file, found ${nested_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_nonexistent_directory)
    message(STATUS "Test 4: Nonexistent directory handling")
    
    ClangFormat_CollectFiles(EMPTY_FILES
        SOURCE_DIRS nonexistent_dir
    )
    
    list(LENGTH EMPTY_FILES empty_count)
    if(empty_count EQUAL 0)
        message(STATUS "  ✓ Nonexistent directory correctly returns no files")
    else()
        message(STATUS "  ✗ Nonexistent directory should return no files, got ${empty_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat File Discovery Tests ===")
    
    setup_test_environment()
    test_default_patterns()
    test_custom_patterns()
    test_recursive_discovery()
    test_nonexistent_directory()
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
