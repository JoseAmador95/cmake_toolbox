# Test: MAPPING_FILE parameter handling
# Purpose: Verify that mapping file parameter is processed correctly
# Expected: PASS
# Executable: cmake -P test_mapping_file_handling.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the IWYU module
include(IWYU)

# Use test directory instead of /tmp for portability
set(test_artifacts_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
file(MAKE_DIRECTORY "${test_artifacts_dir}")

set(mapping_file_path "${test_artifacts_dir}/test_iwyu_mapping.imp")
set(nonexistent_mapping "${test_artifacts_dir}/nonexistent_mapping.imp")

# Test 1: Configure with a non-existent mapping file
# When IWYU is found: module should drop the missing file (advisory) → --mapping_file= absent
# When IWYU is not found: advisory mode, no-op
message(STATUS "INFO: Testing MAPPING_FILE with non-existent file")

IWYU_Configure(STATUS ON MAPPING_FILE "${nonexistent_mapping}")

if(IWYU_FOUND)
    set(iwyu_cmd "${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}")
    if("${iwyu_cmd}" MATCHES "--mapping_file=")
        message(
            FATAL_ERROR
            "FAIL: Non-existent mapping file should be silently dropped but is in command: ${iwyu_cmd}"
        )
    endif()
    message(STATUS "PASS: MAPPING_FILE (non-existent) correctly dropped in advisory mode")
else()
    message(STATUS "PASS: MAPPING_FILE (non-existent) - advisory mode completed without tool")
endif()

# Test 2: Create a real mapping file — when IWYU found, command must include --mapping_file=
file(WRITE "${mapping_file_path}" "# Test IWYU mapping file\n")

IWYU_Configure(STATUS ON MAPPING_FILE "${mapping_file_path}")

if(IWYU_FOUND)
    set(iwyu_cmd "${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}")
    if(NOT ("${iwyu_cmd}" MATCHES "--mapping_file="))
        message(
            FATAL_ERROR
            "FAIL: MAPPING_FILE not found in command after providing existing file. Command: ${iwyu_cmd}"
        )
    endif()
    message(STATUS "PASS: MAPPING_FILE correctly included in command: ${iwyu_cmd}")
else()
    message(STATUS "PASS: MAPPING_FILE (existing) - advisory mode completed without tool")
endif()

message(STATUS "PASS: MAPPING_FILE test completed successfully")

# Cleanup
file(REMOVE_RECURSE "${test_artifacts_dir}")
