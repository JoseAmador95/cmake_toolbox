# Test: Regex Pattern Exclusion
# Tests the regex-based exclusion patterns functionality

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormat.cmake)

set(ERROR_COUNT 0)
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_regex_test")

function(setup_test_environment)
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
        "generated/auto_header.h"
        "generated/parser.c"
        "generated/lexer.cpp"
        "tests/mock_test.c"
        "tests/integration_test.cpp"
    )

    foreach(file_path IN LISTS TEST_FILES)
        file(WRITE "${TEST_DIR}/${file_path}" "// Test content")
    endforeach()

    set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}" PARENT_SCOPE)
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_simple_regex_patterns)
    message(STATUS "Test 1: Simple regex pattern exclusion")
    
    # Exclude files with 'test' in the name using regex
    ClangFormat_CollectFiles(NO_TEST_FILES
        SOURCE_DIRS src include generated tests
        EXCLUDE_PATTERNS ".*test.*"
    )
    
    # Should exclude: test_file.c, unit_test.cpp, test_api.h, mock_test.c, integration_test.cpp
    # Expected remaining: main.c, utils.cpp, helper.h, api.h, types.hpp, auto_header.h, parser.c, lexer.cpp
    set(EXPECTED_COUNT 8)
    list(LENGTH NO_TEST_FILES no_test_count)
    
    if(no_test_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Simple regex exclusion: ${no_test_count} files remain")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files after test exclusion, found ${no_test_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Verify no test files remain
    foreach(file IN LISTS NO_TEST_FILES)
        if(file MATCHES "test")
            message(STATUS "  ✗ Test file incorrectly included: ${file}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

function(test_directory_regex_patterns)
    message(STATUS "Test 2: Directory-based regex exclusion")
    
    # Exclude all files in generated/ directory
    ClangFormat_CollectFiles(NO_GENERATED
        SOURCE_DIRS src include generated tests
        EXCLUDE_PATTERNS "generated/.*"
    )
    
    # Should exclude: auto_header.h, parser.c, lexer.cpp from generated/
    # Expected remaining: all files from src/, include/, tests/ = 10 files
    set(EXPECTED_COUNT 10)
    list(LENGTH NO_GENERATED no_gen_count)
    
    if(no_gen_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Directory regex exclusion: ${no_gen_count} files remain")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files after generated exclusion, found ${no_gen_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_extension_regex_patterns)
    message(STATUS "Test 3: Extension-based regex exclusion")
    
    # Exclude all .cpp files using regex
    ClangFormat_CollectFiles(NO_CPP_FILES
        SOURCE_DIRS src include generated tests
        EXCLUDE_PATTERNS ".*\\.cpp$"
    )
    
    # Should exclude: utils.cpp, unit_test.cpp, lexer.cpp, integration_test.cpp
    # Expected remaining: .c and .h files = 9 files
    set(EXPECTED_COUNT 9)
    list(LENGTH NO_CPP_FILES no_cpp_count)
    
    if(no_cpp_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Extension regex exclusion: ${no_cpp_count} files remain")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files after .cpp exclusion, found ${no_cpp_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Verify no .cpp files remain
    foreach(file IN LISTS NO_CPP_FILES)
        if(file MATCHES "\\.cpp$")
            message(STATUS "  ✗ .cpp file incorrectly included: ${file}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

function(test_complex_regex_patterns)
    message(STATUS "Test 4: Complex regex patterns")
    
    # Exclude files that start with 'auto_' or 'mock_' or end with '_test'
    ClangFormat_CollectFiles(COMPLEX_FILTERED
        SOURCE_DIRS src include generated tests
        EXCLUDE_PATTERNS "auto_.*|mock_.*|.*_test\\."
    )
    
    # Should exclude: auto_header.h, mock_test.c
    # Expected remaining: main.c, utils.cpp, helper.h, test_file.c, unit_test.cpp, api.h, types.hpp, test_api.h, parser.c, lexer.cpp, integration_test.cpp
    set(EXPECTED_COUNT 11)
    list(LENGTH COMPLEX_FILTERED complex_count)
    
    if(complex_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Complex regex exclusion: ${complex_count} files remain")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files after complex exclusion, found ${complex_count}")
        message(STATUS "    Remaining: ${COMPLEX_FILTERED}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_multiple_regex_patterns)
    message(STATUS "Test 5: Multiple regex patterns")
    
    # Use multiple distinct patterns
    ClangFormat_CollectFiles(MULTI_REGEX
        SOURCE_DIRS src include generated tests
        EXCLUDE_PATTERNS ".*test.*" "generated/.*" ".*\\.hpp$"
    )
    
    # Should exclude: test_file.c, unit_test.cpp, test_api.h, all generated/, types.hpp, mock_test.c, integration_test.cpp
    # Expected remaining: main.c, utils.cpp, helper.h, api.h, parser.c, lexer.cpp would be excluded by generated/ pattern
    # Actually remaining: main.c, utils.cpp, helper.h, api.h = 4 files
    set(EXPECTED_COUNT 4)
    list(LENGTH MULTI_REGEX multi_count)
    
    if(multi_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Multiple regex patterns: ${multi_count} files remain")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files after multiple regex, found ${multi_count}")
        message(STATUS "    Files: ${MULTI_REGEX}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat Regex Exclusion Tests ===")
    
    setup_test_environment()
    test_simple_regex_patterns()
    test_directory_regex_patterns()
    test_extension_regex_patterns()
    test_complex_regex_patterns()
    test_multiple_regex_patterns()
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
