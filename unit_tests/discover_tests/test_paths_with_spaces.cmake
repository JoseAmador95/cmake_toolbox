# DiscoverTests path handling tests using /tmp for portability.

set(ERROR_COUNT 0)
set(TEST_ROOT "/tmp/discover_tests_paths_${CMAKE_PROCESS_ID}")
set(DISCOVER_TESTS_MODULE "${CMAKE_CURRENT_LIST_DIR}/../../cmake/DiscoverTests.cmake")

macro(fail message_text)
    message(STATUS "  FAIL: ${message_text}")
    math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
endmacro()

function(reset_test_root)
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(create_mock_test_executable base_path out_executable_var)
    if(WIN32)
        set(exe_path "${base_path}.bat")
    else()
        set(exe_path "${base_path}.sh")
    endif()

    get_filename_component(exe_dir "${exe_path}" DIRECTORY)
    file(MAKE_DIRECTORY "${exe_dir}")

    if(WIN32)
        file(
            WRITE "${exe_path}"
            "@echo off
if \"%1\"==\"-l\" (
  echo suite
  echo test_one
  echo test_two
  exit /b 0
)
exit /b 1
"
        )
    else()
        file(
            WRITE "${exe_path}"
            "#!/bin/sh
if [ \"$1\" = \"-l\" ]; then
  echo \"suite\"
  echo \"test_one\"
  echo \"test_two\"
  exit 0
fi
exit 1
"
        )
        execute_process(
            COMMAND
                chmod +x "${exe_path}"
            RESULT_VARIABLE chmod_result
        )
        if(NOT chmod_result EQUAL 0)
            message(FATAL_ERROR "Failed to make executable: ${exe_path}")
        endif()
    endif()

    set(${out_executable_var} "${exe_path}" PARENT_SCOPE)
endfunction()

function(run_discover exe_path work_dir out_file)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -D "TEST_EXECUTABLE=${exe_path}" -D "TEST_WORKING_DIR=${work_dir}" -D
            "TEST_SUITE=suite" -D "TEST_FILE=${out_file}" -P "${DISCOVER_TESTS_MODULE}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    set(DISCOVER_RESULT ${result} PARENT_SCOPE)
    set(DISCOVER_OUTPUT "${output}" PARENT_SCOPE)
    set(DISCOVER_ERROR "${error}" PARENT_SCOPE)
endfunction()

function(verify_output out_file)
    if(NOT EXISTS "${out_file}")
        fail("Output file not created: ${out_file}")
        return()
    endif()

    file(READ "${out_file}" content)
    if(NOT content MATCHES "add_test\\(\\\"suite/test_one\\\"")
        fail("Missing add_test entry for test_one")
        return()
    endif()
    if(NOT content MATCHES "add_test\\(\\\"suite/test_two\\\"")
        fail("Missing add_test entry for test_two")
        return()
    endif()

    message(STATUS "  PASS: add_test entries present")
endfunction()

function(test_normal_path)
    message(STATUS "Test 1: normal path")

    set(exe_path "${TEST_ROOT}/normal/test_app")
    set(work_dir "${TEST_ROOT}/normal")
    set(out_file "${TEST_ROOT}/normal/tests.cmake")

    create_mock_test_executable("${exe_path}" real_exe_path)
    run_discover("${real_exe_path}" "${work_dir}" "${out_file}")

    if(NOT DISCOVER_RESULT EQUAL 0)
        fail("DiscoverTests failed for normal path: ${DISCOVER_ERROR}")
        return()
    endif()

    verify_output("${out_file}")
endfunction()

function(test_executable_with_spaces)
    message(STATUS "Test 2: executable path with spaces and special chars")

    set(exe_path "${TEST_ROOT}/path with spaces/exe & chars/test app")
    set(work_dir "${TEST_ROOT}/path with spaces")
    set(out_file "${TEST_ROOT}/path with spaces/tests.cmake")

    create_mock_test_executable("${exe_path}" real_exe_path)
    run_discover("${real_exe_path}" "${work_dir}" "${out_file}")

    if(NOT DISCOVER_RESULT EQUAL 0)
        fail("DiscoverTests failed for exec path with spaces: ${DISCOVER_ERROR}")
        return()
    endif()

    verify_output("${out_file}")
endfunction()

function(test_workdir_with_spaces)
    message(STATUS "Test 3: working directory with spaces (nested)")

    set(work_dir "${TEST_ROOT}/nested dir/with spaces")
    set(exe_path "${work_dir}/test_app")
    set(out_file "${work_dir}/tests.cmake")

    create_mock_test_executable("${exe_path}" real_exe_path)
    run_discover("${real_exe_path}" "${work_dir}" "${out_file}")

    if(NOT DISCOVER_RESULT EQUAL 0)
        fail("DiscoverTests failed for workdir with spaces: ${DISCOVER_ERROR}")
        return()
    endif()

    verify_output("${out_file}")
endfunction()

function(test_nonexistent_executable)
    message(STATUS "Test 4: nonexistent executable error handling")

    set(exe_path "${TEST_ROOT}/missing path/does_not_exist")
    set(work_dir "${TEST_ROOT}")
    set(out_file "${TEST_ROOT}/missing/tests.cmake")

    run_discover("${exe_path}" "${work_dir}" "${out_file}")

    if(DISCOVER_RESULT EQUAL 0)
        fail("Expected failure for nonexistent executable")
    else()
        message(STATUS "  PASS: missing executable rejected")
    endif()
endfunction()

message(STATUS "DiscoverTests path handling tests")
reset_test_root()
test_normal_path()
test_executable_with_spaces()
test_workdir_with_spaces()
test_nonexistent_executable()

if(ERROR_COUNT EQUAL 0)
    message(STATUS "All tests passed")
else()
    message(FATAL_ERROR "Tests failed with ${ERROR_COUNT} error(s)")
endif()
