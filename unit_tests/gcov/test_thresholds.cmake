# Test: Gcovr Threshold Enforcement
# ==============================================================================
#
# This test validates the threshold enforcement behavior of Gcov.cmake:
#
# CONFIGURE-TIME TESTS (what our module controls):
#   1-2.  LINE/BRANCH thresholds with enforcement ON/OFF
#   3-4.  All 4 threshold types (LINE/BRANCH/FUNCTION/DECISION) ON/OFF
#   5.    CONFIG_FILE mode: GCOVR_ENFORCE_THRESHOLDS is ignored + warning emitted
#   6-9.  Zero thresholds (value=0) are excluded from config file
#   10-13. 100% thresholds work correctly (boundary case)
#   14.   ENFORCE=ON but no thresholds: informative message, no failure
#   15.   Status message format: includes metric=value for CI visibility
#
# RUNTIME BEHAVIORS (handled by gcovr, not our module):
#   - Threshold configured but metric unavailable: gcovr emits warning
#   - Failure message format: gcovr includes metric + observed + required
#   - "Equal to threshold" case: gcovr uses >= comparison (passes at exact match)
#
# ==============================================================================

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(MODULE_DIR "${REPO_ROOT}/cmake")
string(REGEX REPLACE "([][+.*()?^$\\\\])" "\\\\\\1" REPO_ROOT_REGEX "${REPO_ROOT}")

set(CMAKE_MODULE_PATH
    "${MODULE_DIR}"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(
        DEFINED
            CMAKE_CURRENT_BINARY_DIR
        AND NOT CMAKE_CURRENT_BINARY_DIR
            STREQUAL
            ""
        AND NOT CMAKE_CURRENT_BINARY_DIR
            MATCHES
            "^${REPO_ROOT_REGEX}(/|$)"
    )
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    elseif(
        DEFINED
            CMAKE_BINARY_DIR
        AND NOT CMAKE_BINARY_DIR
            STREQUAL
            ""
        AND NOT CMAKE_BINARY_DIR
            MATCHES
            "^${REPO_ROOT_REGEX}(/|$)"
    )
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    else()
        message(
            FATAL_ERROR
            "CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT must be set to a build-tree path when running gcov threshold tests from the source tree"
        )
    endif()
endif()

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcov_thresholds")
TestHelpers_GetConfigureArgs(_GCOV_CONFIGURE_ARGS)

# ==============================================================================
# Test Case: Basic LINE/BRANCH thresholds (existing)
# ==============================================================================
function(
    run_case
    NAME
    ENFORCE
    LINE
    BRANCH
    EXPECT_FAIL_UNDER
)
    set(case_dir "${TEST_ROOT}/${NAME}")
    set(src_dir "${case_dir}/src")
    set(build_dir "${case_dir}/build")

    file(REMOVE_RECURSE "${case_dir}")
    file(MAKE_DIRECTORY "${src_dir}")

    set(cmake_lists "")
    string(APPEND cmake_lists "cmake_minimum_required(VERSION 3.22)\n")
    string(APPEND cmake_lists "project(GcovThresholdsTest)\n")
    string(APPEND cmake_lists "list(APPEND CMAKE_MODULE_PATH \"${MODULE_DIR}\")\n")
    string(
        APPEND cmake_lists
        "set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)\n"
    )
    string(
        APPEND cmake_lists
        "set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)\n"
    )
    string(
        APPEND cmake_lists
        "set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)\n"
    )
    string(
        APPEND cmake_lists
        "set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)\n"
    )
    string(
        APPEND cmake_lists
        "set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)\n"
    )
    string(
        APPEND cmake_lists
        "set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)\n"
    )
    string(
        APPEND cmake_lists
        "set(GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)\n"
    )
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_LINE \"${LINE}\" CACHE STRING \"\" FORCE)\n")
    string(
        APPEND cmake_lists
        "set(GCOVR_FAIL_UNDER_BRANCH \"${BRANCH}\" CACHE STRING \"\" FORCE)\n"
    )
    string(APPEND cmake_lists "set(GCOVR_ENFORCE_THRESHOLDS ${ENFORCE} CACHE BOOL \"\" FORCE)\n")
    string(APPEND cmake_lists "include(Gcov)\n")

    file(WRITE "${src_dir}/CMakeLists.txt" "${cmake_lists}")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(NOT configure_result EQUAL 0)
        message(STATUS "[FAIL] ${NAME}: configure failed")
        message(STATUS "${configure_output}")
        message(STATUS "${configure_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    if(NOT EXISTS "${config_file}")
        message(STATUS "[FAIL] ${NAME}: missing config file: ${config_file}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${config_file}" config_content)
    string(
        FIND "${config_content}"
        "fail-under-line"
        line_pos
    )
    string(
        FIND "${config_content}"
        "fail-under-branch"
        branch_pos
    )

    if(EXPECT_FAIL_UNDER)
        if(line_pos EQUAL -1 OR branch_pos EQUAL -1)
            message(STATUS "[FAIL] ${NAME}: expected fail-under entries in config")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        else()
            message(STATUS "[PASS] ${NAME}: fail-under entries present")
        endif()
    else()
        if(line_pos GREATER -1 OR branch_pos GREATER -1)
            message(STATUS "[FAIL] ${NAME}: fail-under entries should be absent")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        else()
            message(STATUS "[PASS] ${NAME}: fail-under entries absent")
        endif()
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Test Case: FUNCTION and DECISION thresholds
# ==============================================================================
function(
    run_case_all_thresholds
    NAME
    ENFORCE
    LINE
    BRANCH
    FUNCTION
    DECISION
    EXPECT_FAIL_UNDER
)
    set(case_dir "${TEST_ROOT}/${NAME}")
    set(src_dir "${case_dir}/src")
    set(build_dir "${case_dir}/build")

    file(REMOVE_RECURSE "${case_dir}")
    file(MAKE_DIRECTORY "${src_dir}")

    set(cmake_lists "")
    string(APPEND cmake_lists "cmake_minimum_required(VERSION 3.22)\n")
    string(APPEND cmake_lists "project(GcovThresholdsTest)\n")
    string(APPEND cmake_lists "list(APPEND CMAKE_MODULE_PATH \"${MODULE_DIR}\")\n")
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_LINE \"${LINE}\" CACHE STRING \"\" FORCE)\n")
    string(
        APPEND cmake_lists
        "set(GCOVR_FAIL_UNDER_BRANCH \"${BRANCH}\" CACHE STRING \"\" FORCE)\n"
    )
    string(
        APPEND cmake_lists
        "set(GCOVR_FAIL_UNDER_FUNCTION \"${FUNCTION}\" CACHE STRING \"\" FORCE)\n"
    )
    string(
        APPEND cmake_lists
        "set(GCOVR_FAIL_UNDER_DECISION \"${DECISION}\" CACHE STRING \"\" FORCE)\n"
    )
    string(APPEND cmake_lists "set(GCOVR_ENFORCE_THRESHOLDS ${ENFORCE} CACHE BOOL \"\" FORCE)\n")
    string(APPEND cmake_lists "include(Gcov)\n")

    file(WRITE "${src_dir}/CMakeLists.txt" "${cmake_lists}")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(NOT configure_result EQUAL 0)
        message(STATUS "[FAIL] ${NAME}: configure failed")
        message(STATUS "${configure_output}")
        message(STATUS "${configure_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    if(NOT EXISTS "${config_file}")
        message(STATUS "[FAIL] ${NAME}: missing config file: ${config_file}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${config_file}" config_content)
    string(
        FIND "${config_content}"
        "fail-under-line"
        line_pos
    )
    string(
        FIND "${config_content}"
        "fail-under-branch"
        branch_pos
    )
    string(
        FIND "${config_content}"
        "fail-under-function"
        function_pos
    )
    string(
        FIND "${config_content}"
        "fail-under-decision"
        decision_pos
    )

    set(all_present TRUE)
    set(any_present FALSE)

    if(line_pos EQUAL -1 OR branch_pos EQUAL -1 OR function_pos EQUAL -1 OR decision_pos EQUAL -1)
        set(all_present FALSE)
    endif()
    if(
        line_pos
            GREATER
            -1
        OR branch_pos
            GREATER
            -1
        OR function_pos
            GREATER
            -1
        OR decision_pos
            GREATER
            -1
    )
        set(any_present TRUE)
    endif()

    if(EXPECT_FAIL_UNDER)
        if(NOT all_present)
            message(
                STATUS
                "[FAIL] ${NAME}: expected all fail-under entries in config (line=${line_pos}, branch=${branch_pos}, function=${function_pos}, decision=${decision_pos})"
            )
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        else()
            message(STATUS "[PASS] ${NAME}: all fail-under entries present")
        endif()
    else()
        if(any_present)
            message(STATUS "[FAIL] ${NAME}: fail-under entries should be absent")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        else()
            message(STATUS "[PASS] ${NAME}: fail-under entries absent")
        endif()
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Test Case: Zero threshold (should NOT appear in config)
# ==============================================================================
function(run_case_zero_threshold NAME THRESHOLD_VAR)
    set(case_dir "${TEST_ROOT}/${NAME}")
    set(src_dir "${case_dir}/src")
    set(build_dir "${case_dir}/build")

    file(REMOVE_RECURSE "${case_dir}")
    file(MAKE_DIRECTORY "${src_dir}")

    # Convert GCOVR_FAIL_UNDER_LINE to fail-under-line
    string(TOLOWER "${THRESHOLD_VAR}" threshold_key)
    string(REPLACE "gcovr_fail_under_" "fail-under-" threshold_key "${threshold_key}")

    set(cmake_lists "")
    string(APPEND cmake_lists "cmake_minimum_required(VERSION 3.22)\n")
    string(APPEND cmake_lists "project(GcovThresholdsTest)\n")
    string(APPEND cmake_lists "list(APPEND CMAKE_MODULE_PATH \"${MODULE_DIR}\")\n")
    # Set the specific threshold to 0
    string(APPEND cmake_lists "set(${THRESHOLD_VAR} \"0\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)\n")
    string(APPEND cmake_lists "include(Gcov)\n")

    file(WRITE "${src_dir}/CMakeLists.txt" "${cmake_lists}")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(NOT configure_result EQUAL 0)
        message(STATUS "[FAIL] ${NAME}: configure failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    if(NOT EXISTS "${config_file}")
        message(STATUS "[FAIL] ${NAME}: missing config file")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${config_file}" config_content)
    string(
        FIND "${config_content}"
        "${threshold_key}"
        threshold_pos
    )

    # Zero values should NOT appear in config (they're excluded)
    if(threshold_pos GREATER -1)
        message(STATUS "[FAIL] ${NAME}: zero threshold should NOT appear in config")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "[PASS] ${NAME}: zero threshold correctly excluded from config")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Test Case: 100% threshold (should appear in config)
# ==============================================================================
function(run_case_100_threshold NAME THRESHOLD_VAR)
    set(case_dir "${TEST_ROOT}/${NAME}")
    set(src_dir "${case_dir}/src")
    set(build_dir "${case_dir}/build")

    file(REMOVE_RECURSE "${case_dir}")
    file(MAKE_DIRECTORY "${src_dir}")

    # Convert GCOVR_FAIL_UNDER_LINE to fail-under-line
    string(TOLOWER "${THRESHOLD_VAR}" threshold_key)
    string(REPLACE "gcovr_fail_under_" "fail-under-" threshold_key "${threshold_key}")

    set(cmake_lists "")
    string(APPEND cmake_lists "cmake_minimum_required(VERSION 3.22)\n")
    string(APPEND cmake_lists "project(GcovThresholdsTest)\n")
    string(APPEND cmake_lists "list(APPEND CMAKE_MODULE_PATH \"${MODULE_DIR}\")\n")
    # Set the specific threshold to 100
    string(APPEND cmake_lists "set(${THRESHOLD_VAR} \"100\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)\n")
    string(APPEND cmake_lists "include(Gcov)\n")

    file(WRITE "${src_dir}/CMakeLists.txt" "${cmake_lists}")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(NOT configure_result EQUAL 0)
        message(STATUS "[FAIL] ${NAME}: configure failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    if(NOT EXISTS "${config_file}")
        message(STATUS "[FAIL] ${NAME}: missing config file")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${config_file}" config_content)
    string(
        FIND "${config_content}"
        "${threshold_key} = 100"
        threshold_pos
    )

    # 100 values SHOULD appear in config
    if(threshold_pos EQUAL -1)
        message(STATUS "[FAIL] ${NAME}: 100% threshold should appear in config")
        message(STATUS "  Config content: ${config_content}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "[PASS] ${NAME}: 100% threshold correctly included in config")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Test Case: ENFORCE=ON but no thresholds defined
# ==============================================================================
function(run_case_enforce_no_thresholds NAME)
    set(case_dir "${TEST_ROOT}/${NAME}")
    set(src_dir "${case_dir}/src")
    set(build_dir "${case_dir}/build")

    file(REMOVE_RECURSE "${case_dir}")
    file(MAKE_DIRECTORY "${src_dir}")

    set(cmake_lists "")
    string(APPEND cmake_lists "cmake_minimum_required(VERSION 3.22)\n")
    string(APPEND cmake_lists "project(GcovThresholdsTest)\n")
    string(APPEND cmake_lists "list(APPEND CMAKE_MODULE_PATH \"${MODULE_DIR}\")\n")
    # Enable enforcement but leave all thresholds at 0 (default)
    string(APPEND cmake_lists "set(GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)\n")
    # Explicitly set all to 0 to ensure defaults
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_LINE \"0\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_BRANCH \"0\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_FUNCTION \"0\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_DECISION \"0\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "include(Gcov)\n")

    file(WRITE "${src_dir}/CMakeLists.txt" "${cmake_lists}")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    # Configuration should NOT fail
    if(NOT configure_result EQUAL 0)
        message(
            STATUS
            "[FAIL] ${NAME}: configure should not fail when ENFORCE=ON but no thresholds"
        )
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Should emit informative message
    string(
        FIND "${configure_output}${configure_error}"
        "no thresholds are set"
        info_pos
    )
    if(info_pos EQUAL -1)
        message(STATUS "[FAIL] ${NAME}: expected informative message about no thresholds")
        message(STATUS "  Output: ${configure_output}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "[PASS] ${NAME}: informative message emitted, no failure")
    endif()

    # Config file should have no fail-under entries
    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    if(EXISTS "${config_file}")
        file(READ "${config_file}" config_content)
        string(
            FIND "${config_content}"
            "fail-under"
            failunder_pos
        )
        if(failunder_pos GREATER -1)
            message(STATUS "[FAIL] ${NAME}: config should have no fail-under entries")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        else()
            message(STATUS "[PASS] ${NAME}: config correctly has no fail-under entries")
        endif()
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Test Case: Status message format validation
# ==============================================================================
function(run_case_status_message_format NAME)
    set(case_dir "${TEST_ROOT}/${NAME}")
    set(src_dir "${case_dir}/src")
    set(build_dir "${case_dir}/build")

    file(REMOVE_RECURSE "${case_dir}")
    file(MAKE_DIRECTORY "${src_dir}")

    set(cmake_lists "")
    string(APPEND cmake_lists "cmake_minimum_required(VERSION 3.22)\n")
    string(APPEND cmake_lists "project(GcovThresholdsTest)\n")
    string(APPEND cmake_lists "list(APPEND CMAKE_MODULE_PATH \"${MODULE_DIR}\")\n")
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_LINE \"80\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_BRANCH \"70\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)\n")
    string(APPEND cmake_lists "include(Gcov)\n")

    file(WRITE "${src_dir}/CMakeLists.txt" "${cmake_lists}")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(NOT configure_result EQUAL 0)
        message(STATUS "[FAIL] ${NAME}: configure failed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Check that status message includes metric names and values
    set(combined_output "${configure_output}${configure_error}")

    # Should include "Enforcing coverage thresholds" message
    string(
        FIND "${combined_output}"
        "Enforcing coverage thresholds"
        enforce_pos
    )
    if(enforce_pos EQUAL -1)
        message(STATUS "[FAIL] ${NAME}: missing 'Enforcing coverage thresholds' message")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Should include metric names in the message
    string(
        FIND "${combined_output}"
        "GCOVR_FAIL_UNDER_LINE=80"
        line_pos
    )
    string(
        FIND "${combined_output}"
        "GCOVR_FAIL_UNDER_BRANCH=70"
        branch_pos
    )

    if(line_pos EQUAL -1 OR branch_pos EQUAL -1)
        message(STATUS "[FAIL] ${NAME}: status message should include metric=value format")
        message(STATUS "  Expected: GCOVR_FAIL_UNDER_LINE=80 and GCOVR_FAIL_UNDER_BRANCH=70")
        message(STATUS "  Output: ${combined_output}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "[PASS] ${NAME}: status message includes metric=value format")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Test Case: CONFIG_FILE mode ignores GCOVR_ENFORCE_THRESHOLDS
# ==============================================================================
function(run_case_config_file_mode NAME)
    set(case_dir "${TEST_ROOT}/${NAME}")
    set(src_dir "${case_dir}/src")
    set(build_dir "${case_dir}/build")

    file(REMOVE_RECURSE "${case_dir}")
    file(MAKE_DIRECTORY "${src_dir}")

    # Create a dummy gcovr config file
    file(WRITE "${src_dir}/gcovr.cfg" "# Custom gcovr config\nroot = .\n")

    set(cmake_lists "")
    string(APPEND cmake_lists "cmake_minimum_required(VERSION 3.22)\n")
    string(APPEND cmake_lists "project(GcovThresholdsTest)\n")
    string(APPEND cmake_lists "list(APPEND CMAKE_MODULE_PATH \"${MODULE_DIR}\")\n")
    # Set config file to trigger CONFIG_FILE mode
    string(
        APPEND cmake_lists
        "set(GCOVR_CONFIG_FILE \"\${CMAKE_CURRENT_SOURCE_DIR}/gcovr.cfg\" CACHE FILEPATH \"\" FORCE)\n"
    )
    # Enable enforcement - should be ignored and emit warning
    string(APPEND cmake_lists "set(GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_LINE 80 CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "include(Gcov)\n")

    file(WRITE "${src_dir}/CMakeLists.txt" "${cmake_lists}")

    execute_process(
        COMMAND
            "${CMAKE_COMMAND}" -S "${src_dir}" -B "${build_dir}" ${_GCOV_CONFIGURE_ARGS}
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(NOT configure_result EQUAL 0)
        message(STATUS "[FAIL] ${NAME}: configure failed")
        message(STATUS "${configure_output}")
        message(STATUS "${configure_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Check that the warning about GCOVR_ENFORCE_THRESHOLDS being ignored was emitted
    string(
        FIND "${configure_output}${configure_error}"
        "GCOVR_ENFORCE_THRESHOLDS is ignored in CONFIG_FILE mode"
        warning_pos
    )

    if(warning_pos EQUAL -1)
        message(
            STATUS
            "[FAIL] ${NAME}: expected warning about GCOVR_ENFORCE_THRESHOLDS being ignored"
        )
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "[PASS] ${NAME}: warning about ignored GCOVR_ENFORCE_THRESHOLDS emitted")
    endif()

    # Verify no generated config file was created (uses user-provided config)
    set(generated_config "${build_dir}/coverage/gcovr_generated.cfg")
    if(EXISTS "${generated_config}")
        message(STATUS "[FAIL] ${NAME}: generated config should not exist in CONFIG_FILE mode")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "[PASS] ${NAME}: no generated config in CONFIG_FILE mode")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Run all test cases
# ==============================================================================

file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${TEST_ROOT}")
TestHelpers_CreateMockGcovr(_gcovr_mock OUTPUT_DIR "${TEST_ROOT}/mock_gcovr")
file(TO_CMAKE_PATH "${_gcovr_mock}" GCOVR_MOCK_PATH)

message(STATUS "=== Gcovr Threshold Enforcement Tests ===")

# Basic LINE/BRANCH tests
message(STATUS "Test 1: LINE and BRANCH thresholds with enforcement ON")
run_case("enforce_on" ON 80 70 TRUE)

message(STATUS "Test 2: LINE and BRANCH thresholds with enforcement OFF")
run_case("enforce_off" OFF 80 70 FALSE)

# FUNCTION and DECISION threshold tests
message(STATUS "Test 3: All thresholds (LINE/BRANCH/FUNCTION/DECISION) with enforcement ON")
run_case_all_thresholds("all_thresholds_on" ON 80 70 90 60 TRUE)

message(STATUS "Test 4: All thresholds with enforcement OFF")
run_case_all_thresholds("all_thresholds_off" OFF 80 70 90 60 FALSE)

# CONFIG_FILE mode test
message(STATUS "Test 5: CONFIG_FILE mode ignores GCOVR_ENFORCE_THRESHOLDS")
run_case_config_file_mode("config_file_mode")

# Zero threshold tests (boundary: should NOT appear in config)
message(STATUS "Test 6: Zero LINE threshold (should be excluded from config)")
run_case_zero_threshold("zero_line" "GCOVR_FAIL_UNDER_LINE")

message(STATUS "Test 7: Zero BRANCH threshold (should be excluded from config)")
run_case_zero_threshold("zero_branch" "GCOVR_FAIL_UNDER_BRANCH")

message(STATUS "Test 8: Zero FUNCTION threshold (should be excluded from config)")
run_case_zero_threshold("zero_function" "GCOVR_FAIL_UNDER_FUNCTION")

message(STATUS "Test 9: Zero DECISION threshold (should be excluded from config)")
run_case_zero_threshold("zero_decision" "GCOVR_FAIL_UNDER_DECISION")

# 100% threshold tests (boundary: should appear in config)
message(STATUS "Test 10: 100% LINE threshold (should be included in config)")
run_case_100_threshold("100_line" "GCOVR_FAIL_UNDER_LINE")

message(STATUS "Test 11: 100% BRANCH threshold (should be included in config)")
run_case_100_threshold("100_branch" "GCOVR_FAIL_UNDER_BRANCH")

message(STATUS "Test 12: 100% FUNCTION threshold (should be included in config)")
run_case_100_threshold("100_function" "GCOVR_FAIL_UNDER_FUNCTION")

message(STATUS "Test 13: 100% DECISION threshold (should be included in config)")
run_case_100_threshold("100_decision" "GCOVR_FAIL_UNDER_DECISION")

# ENFORCE=ON but no thresholds defined
message(STATUS "Test 14: ENFORCE=ON but no thresholds defined (should not fail)")
run_case_enforce_no_thresholds("enforce_no_thresholds")

# Status message format validation
message(STATUS "Test 15: Status message format includes metric=value")
run_case_status_message_format("status_message_format")

message(STATUS "")
if(ERROR_COUNT GREATER 0)
    message(FATAL_ERROR "Gcov thresholds test failed with ${ERROR_COUNT} errors")
else()
    message(STATUS "All Gcov thresholds tests PASSED")
endif()
