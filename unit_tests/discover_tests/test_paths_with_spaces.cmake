if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# DiscoverTests path handling tests using test_artifacts in build tree.

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/discover_tests_paths_${CMAKE_PROCESS_ID}")
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
    set(test_labels "")
    set(test_fixtures "")
    if(ARGC GREATER 3)
        set(test_labels "${ARGV3}")
    endif()
    if(ARGC GREATER 4)
        set(test_fixtures "${ARGV4}")
    endif()
    set(label_args "")
    if(NOT test_labels STREQUAL "")
        string(REPLACE ";" "\\;" test_labels_escaped "${test_labels}")
        set(label_args -D "TEST_LABELS=${test_labels_escaped}")
    endif()
    set(fixture_args "")
    if(NOT test_fixtures STREQUAL "")
        string(REPLACE ";" "\\;" test_fixtures_escaped "${test_fixtures}")
        set(fixture_args -D "TEST_FIXTURES_REQUIRED=${test_fixtures_escaped}")
    endif()
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -D "TEST_EXECUTABLE=${exe_path}" -D "TEST_WORKING_DIR=${work_dir}" -D
            "TEST_SUITE=suite" -D "TEST_FILE=${out_file}" ${label_args} ${fixture_args} -P
            "${DISCOVER_TESTS_MODULE}"
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

function(test_labels_propagation)
    message(STATUS "Test 5: labels are applied to discovered tests")

    set(exe_path "${TEST_ROOT}/labels/test_app")
    set(work_dir "${TEST_ROOT}/labels")
    set(out_file "${TEST_ROOT}/labels/tests.cmake")

    create_mock_test_executable("${exe_path}" real_exe_path)
    run_discover("${real_exe_path}" "${work_dir}" "${out_file}" "unit;fast")

    if(NOT DISCOVER_RESULT EQUAL 0)
        fail("DiscoverTests failed for label propagation: ${DISCOVER_ERROR}")
        return()
    endif()

    file(READ "${out_file}" content)
    if(NOT content MATCHES "set_tests_properties\\(\\\"suite/test_one\\\" PROPERTIES LABELS \\\"unit;fast\\\"\\)")
        fail("Missing label properties in generated output")
        return()
    endif()

    message(STATUS "  PASS: labels applied in generated output")
endfunction()

function(test_fixtures_propagation)
    message(STATUS "Test 6: fixtures are applied to discovered tests")

    set(exe_path "${TEST_ROOT}/fixtures/test_app")
    set(work_dir "${TEST_ROOT}/fixtures")
    set(out_file "${TEST_ROOT}/fixtures/tests.cmake")

    create_mock_test_executable("${exe_path}" real_exe_path)
    run_discover("${real_exe_path}" "${work_dir}" "${out_file}" "" "gcovr_unit")

    if(NOT DISCOVER_RESULT EQUAL 0)
        fail("DiscoverTests failed for fixture propagation: ${DISCOVER_ERROR}")
        return()
    endif()

    file(READ "${out_file}" content)
    if(NOT content MATCHES "set_tests_properties\\(\\\"suite/test_one\\\" PROPERTIES FIXTURES_REQUIRED \\\"gcovr_unit\\\"\\)")
        fail("Missing fixture properties in generated output")
        return()
    endif()

    message(STATUS "  PASS: fixtures applied in generated output")
endfunction()

function(test_multiple_fixtures)
    message(STATUS "Test 7: multiple fixtures are applied to discovered tests")

    set(exe_path "${TEST_ROOT}/multi_fixtures/test_app")
    set(work_dir "${TEST_ROOT}/multi_fixtures")
    set(out_file "${TEST_ROOT}/multi_fixtures/tests.cmake")

    create_mock_test_executable("${exe_path}" real_exe_path)
    run_discover("${real_exe_path}" "${work_dir}" "${out_file}" "" "gcovr_unit;extra_fixture")

    if(NOT DISCOVER_RESULT EQUAL 0)
        fail("DiscoverTests failed for multiple fixtures: ${DISCOVER_ERROR}")
        return()
    endif()

    file(READ "${out_file}" content)
    if(NOT content MATCHES "set_tests_properties\\(\\\"suite/test_one\\\" PROPERTIES FIXTURES_REQUIRED \\\"gcovr_unit;extra_fixture\\\"\\)")
        fail("Missing multiple fixture properties in generated output")
        return()
    endif()

    message(STATUS "  PASS: multiple fixtures applied in generated output")
endfunction()

function(test_labels_and_fixtures)
    message(STATUS "Test 8: labels and fixtures are applied together")

    set(exe_path "${TEST_ROOT}/labels_and_fixtures/test_app")
    set(work_dir "${TEST_ROOT}/labels_and_fixtures")
    set(out_file "${TEST_ROOT}/labels_and_fixtures/tests.cmake")

    create_mock_test_executable("${exe_path}" real_exe_path)
    run_discover("${real_exe_path}" "${work_dir}" "${out_file}" "unit;fast" "gcovr_unit")

    if(NOT DISCOVER_RESULT EQUAL 0)
        fail("DiscoverTests failed for labels and fixtures: ${DISCOVER_ERROR}")
        return()
    endif()

    file(READ "${out_file}" content)
    if(NOT content MATCHES "set_tests_properties\\(\\\"suite/test_one\\\" PROPERTIES LABELS \\\"unit;fast\\\"\\)")
        fail("Missing label properties when fixtures are applied")
        return()
    endif()
    if(NOT content MATCHES "set_tests_properties\\(\\\"suite/test_one\\\" PROPERTIES FIXTURES_REQUIRED \\\"gcovr_unit\\\"\\)")
        fail("Missing fixture properties when labels are applied")
        return()
    endif()

    message(STATUS "  PASS: labels and fixtures applied in generated output")
endfunction()

message(STATUS "DiscoverTests path handling tests")
reset_test_root()
test_normal_path()
test_executable_with_spaces()
test_workdir_with_spaces()
test_nonexistent_executable()
test_labels_propagation()
test_fixtures_propagation()
test_multiple_fixtures()
test_labels_and_fixtures()

if(ERROR_COUNT EQUAL 0)
    message(STATUS "All tests passed")
else()
    message(FATAL_ERROR "Tests failed with ${ERROR_COUNT} error(s)")
endif()
