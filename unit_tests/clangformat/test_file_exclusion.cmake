# Test: File Exclusion Functionality
# Tests the exclude patterns feature for filtering out unwanted files

include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormat.cmake)

set(ERROR_COUNT 0)
set(TEST_DIR "${CMAKE_BINARY_DIR}/clangformat_exclusion_test")

function(setup_test_environment)
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

    set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}" PARENT_SCOPE)
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_no_exclusion_baseline)
    message(STATUS "Test 1: No exclusion patterns (baseline)")
    
    ClangFormat_CollectFiles(ALL_FILES
        SOURCE_DIRS src include tests generated
    )
    
    # Count all .c, .cpp, .h files (should exclude .bak automatically due to default patterns)
    set(EXPECTED_COUNT 11)  # All files except .bak which isn't in default patterns
    list(LENGTH ALL_FILES actual_count)
    
    if(actual_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Baseline: found ${actual_count} files without exclusions")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files, found ${actual_count}")
        message(STATUS "    Files: ${ALL_FILES}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_wildcard_exclusion)
    message(STATUS "Test 2: Wildcard pattern exclusion")
    
    ClangFormat_CollectFiles(FILTERED_FILES
        SOURCE_DIRS src include tests generated
        EXCLUDE_PATTERNS ".*test.*"
    )
    
    # Should exclude: test_helper.c, test_api.h, unit_test.c
    # Expected remaining: main.c, utils.cpp, mock_device.c, api.h, generated.h, auto_gen.c, parser.h, temp.c
    set(EXPECTED_COUNT 8)
    list(LENGTH FILTERED_FILES filtered_count)
    
    if(filtered_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Wildcard exclusion: ${filtered_count} files remain after filtering")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files after wildcard exclusion, found ${filtered_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Verify specific files are excluded
    foreach(file IN LISTS FILTERED_FILES)
        file(RELATIVE_PATH rel_file "${CMAKE_SOURCE_DIR}" "${file}")
        if(rel_file MATCHES "test")
            message(STATUS "  ✗ File with 'test' incorrectly included: ${file}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

function(test_directory_exclusion)
    message(STATUS "Test 3: Directory pattern exclusion")
    
    ClangFormat_CollectFiles(NO_GENERATED_FILES
        SOURCE_DIRS src include tests generated
        EXCLUDE_PATTERNS "generated/.*"
    )
    
    # Should exclude: auto_gen.c, parser.h from generated/
    # Expected remaining: main.c, utils.cpp, test_helper.c, mock_device.c, api.h, test_api.h, generated.h, unit_test.c, temp.c
    set(EXPECTED_COUNT 9)
    list(LENGTH NO_GENERATED_FILES no_gen_count)
    
    if(no_gen_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Directory exclusion: ${no_gen_count} files remain")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files after directory exclusion, found ${no_gen_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
    
    # Verify generated/ directory files are excluded
    foreach(file IN LISTS NO_GENERATED_FILES)
        file(RELATIVE_PATH rel_file "${CMAKE_SOURCE_DIR}" "${file}")
        if(rel_file MATCHES "generated/")
            message(STATUS "  ✗ Generated directory file incorrectly included: ${file}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endforeach()
endfunction()

function(test_multiple_exclusions)
    message(STATUS "Test 4: Multiple exclusion patterns")
    
    ClangFormat_CollectFiles(MULTI_FILTERED_FILES
        SOURCE_DIRS src include tests generated
        EXCLUDE_PATTERNS ".*test.*" ".*mock.*" "generated/.*"
    )
    
    # Should exclude: test_helper.c, mock_device.c, test_api.h, unit_test.c, auto_gen.c, parser.h
    # Expected remaining: main.c, utils.cpp, api.h, generated.h, temp.c
    set(EXPECTED_COUNT 5)
    list(LENGTH MULTI_FILTERED_FILES multi_count)
    
    if(multi_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Multiple exclusions: ${multi_count} files remain")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} files after multiple exclusions, found ${multi_count}")
        message(STATUS "    Remaining files: ${MULTI_FILTERED_FILES}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_exclusion_with_custom_patterns)
    message(STATUS "Test 5: Exclusion with custom file patterns")
    
    ClangFormat_CollectFiles(C_ONLY_FILTERED
        SOURCE_DIRS src tests
        PATTERNS "*.c"
        EXCLUDE_PATTERNS ".*test.*"
    )
    
    # C files: main.c, test_helper.c, mock_device.c, unit_test.c, temp.c
    # After excluding test: main.c, mock_device.c, temp.c
    set(EXPECTED_COUNT 3)
    list(LENGTH C_ONLY_FILTERED c_filtered_count)
    
    if(c_filtered_count EQUAL EXPECTED_COUNT)
        message(STATUS "  ✓ Custom patterns with exclusion: ${c_filtered_count} C files remain")
    else()
        message(STATUS "  ✗ Expected ${EXPECTED_COUNT} C files after exclusion, found ${c_filtered_count}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat File Exclusion Tests ===")
    
    setup_test_environment()
    test_no_exclusion_baseline()
    test_wildcard_exclusion()
    test_directory_exclusion()
    test_multiple_exclusions()
    test_exclusion_with_custom_patterns()
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
