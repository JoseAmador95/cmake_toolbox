# Policy Test Suite Runner
# Runs all policy-related unit tests

set(TEST_SUITE_NAME "Policy API Test Suite")
set(TOTAL_ERROR_COUNT 0)

message(STATUS "==========================================")
message(STATUS "Running ${TEST_SUITE_NAME}")
message(STATUS "==========================================")

# List of all policy test files
set(POLICY_TESTS
    test_basic_operations.cmake
    test_get_fields.cmake
    test_policy_info.cmake
    test_policy_version.cmake
    test_warning_handling.cmake
    test_error_handling.cmake
    test_edge_cases.cmake
)

# Run each test
foreach(test_file ${POLICY_TESTS})
    set(test_path "${CMAKE_CURRENT_LIST_DIR}/${test_file}")
    if(EXISTS "${test_path}")
        message(STATUS "")
        message(STATUS "Running ${test_file}...")
        include("${test_path}")
        # Each test sets ERROR_COUNT, add to total
        if(DEFINED ERROR_COUNT)
            math(EXPR TOTAL_ERROR_COUNT "${TOTAL_ERROR_COUNT} + ${ERROR_COUNT}")
        endif()
    else()
        message(WARNING "Test file not found: ${test_path}")
    endif()
endforeach()

# Final summary
message(STATUS "")
message(STATUS "==========================================")
if(TOTAL_ERROR_COUNT EQUAL 0)
    message(STATUS "${TEST_SUITE_NAME}: ALL TESTS PASSED")
else()
    message(STATUS "${TEST_SUITE_NAME}: FAILED (${TOTAL_ERROR_COUNT} total errors)")
endif()
message(STATUS "==========================================")

# Set the exit code for CTest
if(TOTAL_ERROR_COUNT GREATER 0)
    message(FATAL_ERROR "Test suite failed with ${TOTAL_ERROR_COUNT} errors")
endif()
