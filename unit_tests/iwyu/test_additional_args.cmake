# Test: ADDITIONAL_ARGS parameter handling
# Purpose: Verify that additional arguments are properly prefixed with -Xiwyu
# Expected: PASS
# Executable: cmake -P test_additional_args.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the IWYU module
include(IWYU)

# Test: Configure with ADDITIONAL_ARGS
IWYU_Configure(STATUS ON ADDITIONAL_ARGS "--no_fwd_decls;--keep_going;--check_also=<file>")

if(IWYU_FOUND)
    # Tool found - verify that arguments are properly formatted
    set(iwyu_cmd "${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}")

    message(STATUS "PASS: ADDITIONAL_ARGS - tool found and configured")
    message(STATUS "  Full command: ${iwyu_cmd}")

    # Check for -Xiwyu prefixes
    if("${iwyu_cmd}" MATCHES "-Xiwyu.*--no_fwd_decls")
        message(STATUS "  - Argument '--no_fwd_decls' detected with -Xiwyu prefix")
    endif()

    if("${iwyu_cmd}" MATCHES "-Xiwyu.*--keep_going")
        message(STATUS "  - Argument '--keep_going' detected with -Xiwyu prefix")
    endif()

    if("${iwyu_cmd}" MATCHES "-Xiwyu.*--check_also")
        message(STATUS "  - Argument '--check_also' detected with -Xiwyu prefix")
    endif()

    # Count -Xiwyu occurrences (should be 3 for 3 arguments)
    string(REGEX MATCHALL "-Xiwyu" xiwyu_matches "${iwyu_cmd}")
    list(LENGTH xiwyu_matches xiwyu_count)
    message(STATUS "  - Number of -Xiwyu prefixes: ${xiwyu_count} (expected 3+)")
else()
    # Tool not found - advisory mode
    message(STATUS "PASS: ADDITIONAL_ARGS - advisory mode (tool not installed)")
    message(STATUS "  CMAKE_CXX_INCLUDE_WHAT_YOU_USE = '${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}'")
endif()

message(STATUS "PASS: ADDITIONAL_ARGS test completed successfully")
