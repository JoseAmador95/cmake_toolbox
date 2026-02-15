# Ensure CTest captures full output for this test.
message("CTEST_FULL_OUTPUT")

if(DEFINED TEST_FILE AND NOT TEST_FILE STREQUAL "")
    include("${TEST_FILE}")
    return()
endif()

if(DEFINED TEST_COMMAND AND NOT TEST_COMMAND STREQUAL "")
    set(_tb_working_dir_args "")
    if(DEFINED TEST_WORKING_DIR AND NOT TEST_WORKING_DIR STREQUAL "")
        set(_tb_working_dir_args WORKING_DIRECTORY "${TEST_WORKING_DIR}")
    endif()

    # Echo output so CTest captures the full stream.
    execute_process(
        COMMAND "${TEST_COMMAND}" ${TEST_ARGS}
        ${_tb_working_dir_args}
        RESULT_VARIABLE _tb_result
        OUTPUT_VARIABLE _tb_output
        ERROR_VARIABLE _tb_error
        ECHO_OUTPUT_VARIABLE
        ECHO_ERROR_VARIABLE
    )

    if(NOT _tb_result EQUAL 0)
        message(FATAL_ERROR "Test command failed with exit code ${_tb_result}")
    endif()
    return()
endif()

message(FATAL_ERROR "CTestFullOutput requires TEST_FILE or TEST_COMMAND")
