# Test: Gcovr Threshold Enforcement Toggle
# Validates that fail-under options are emitted only when enforcement is ON

set(ERROR_COUNT 0)
set(REPO_ROOT "")
set(TEST_ROOT "${CMAKE_CURRENT_LIST_DIR}/_thresholds_temp")

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(MODULE_DIR "${REPO_ROOT}/cmake")

function(run_case NAME ENFORCE LINE BRANCH EXPECT_FAIL_UNDER)
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
    string(APPEND cmake_lists "set(GCOVR_FAIL_UNDER_BRANCH \"${BRANCH}\" CACHE STRING \"\" FORCE)\n")
    string(APPEND cmake_lists "set(GCOVR_ENFORCE_THRESHOLDS ${ENFORCE} CACHE BOOL \"\" FORCE)\n")
    string(APPEND cmake_lists "include(Gcov)\n")

    file(WRITE "${src_dir}/CMakeLists.txt" "${cmake_lists}")

    execute_process(
        COMMAND "${CMAKE_COMMAND}" -S "${src_dir}" -B "${build_dir}"
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
    string(FIND "${config_content}" "fail-under-line" line_pos)
    string(FIND "${config_content}" "fail-under-branch" branch_pos)

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

file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${TEST_ROOT}")

run_case("enforce_on" ON 80 70 TRUE)
run_case("enforce_off" OFF 80 70 FALSE)

if(ERROR_COUNT GREATER 0)
    message(FATAL_ERROR "Gcov thresholds test failed with ${ERROR_COUNT} errors")
else()
    message(STATUS "Gcov thresholds test PASSED")
endif()
