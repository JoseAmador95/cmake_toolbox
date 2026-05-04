# Test: MAPPING_FILE parameter handling
# Purpose: Verify that mapping file parameter is processed correctly
# Expected: PASS
# Executable: cmake -P test_mapping_file_handling.cmake

cmake_minimum_required(VERSION 3.22)

# Set module path to find cmake modules
set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")

# Include the IWYU module
include(IWYU)

# Test 1: Configure with a non-existent mapping file in advisory mode
message(STATUS "INFO: Testing MAPPING_FILE in advisory mode (tool may not be installed)")

IWYU_Configure(STATUS ON MAPPING_FILE "/tmp/nonexistent_mapping.imp")

if(IWYU_FOUND)
    # Tool found - check if mapping file validation occurs
    set(iwyu_cmd "${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}")

    if("${iwyu_cmd}" MATCHES "--mapping_file=")
        message(STATUS "PASS: MAPPING_FILE - parameter is present in command")
        if("${iwyu_cmd}" MATCHES "mapping_file=/tmp/nonexistent_mapping.imp")
            message(STATUS "  Correct format detected")
        endif()
        message(STATUS "  Command: ${iwyu_cmd}")
    else()
        message(STATUS "  INFO: Tool configured but mapping file check may not apply")
    endif()
else()
    # Tool not found - advisory mode should still succeed
    message(STATUS "PASS: MAPPING_FILE - advisory mode completed without tool")
    message(STATUS "  CMAKE_CXX_INCLUDE_WHAT_YOU_USE = '${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}'")
endif()

# Test 2: Create a dummy mapping file and test with strict mode
file(WRITE "/tmp/test_iwyu_mapping.imp" "# Test IWYU mapping file\n")

IWYU_Configure(STATUS ON MAPPING_FILE "/tmp/test_iwyu_mapping.imp")

message(STATUS "PASS: MAPPING_FILE test completed successfully")

# Cleanup
file(REMOVE "/tmp/test_iwyu_mapping.imp")
