# Function that runs the unity test to extract the list of tests
# This function generates the '$TEST_FILE' file that contains the
# extracted tests
function(add_unit_test_impl)
    set(options "")
    set(oneValueArgs
        TEST_EXECUTABLE
        TEST_WORKING_DIR
        TEST_SUITE
        TEST_FILE
    )
    set(multiValueArgs "")
    cmake_parse_arguments(PARSE_ARGV 0 arg "${options}" "${oneValueArgs}" "${multiValueArgs}")

    # Run the executable and list the tests, extracting them one by one
    cmake_language(EVAL CODE
      "execute_process(
        COMMAND ${arg_TEST_EXECUTABLE} -l
        WORKING_DIRECTORY [==[${arg_TEST_WORKING_DIR}]==]
        OUTPUT_VARIABLE output
        RESULT_VARIABLE result
      )"
    )
    if(NOT ${result} EQUAL 0)
      message(FATAL_ERROR "Failed to get tests from '${arg_TEST_EXECUTABLE}'!")
    endif()

    # Convert the output to a cmake friendly string
    string(REPLACE "\n" ";" output "${output}")
    # The first entry/line is always the test name
    list(REMOVE_AT output 0)

    # Iterate each test and add a test for it
    set(script)
    foreach(line ${output})
      string(STRIP "${line}" test)
      string(APPEND script "add_test(\"${arg_TEST_SUITE}/${test}\" ${arg_TEST_SUITE} -f ${test})\n")
    endforeach()

    # Write the file to disk
    file(WRITE "${arg_TEST_FILE}" "${script}")

endfunction()

# This cmake script is called as a cmake -P command: Call the function and forward the args
# to generate the list of tests
if(CMAKE_SCRIPT_MODE_FILE)
    add_unit_test_impl(
        TEST_EXECUTABLE ${TEST_EXECUTABLE}
        TEST_WORKING_DIR ${TEST_WORKING_DIR}
        TEST_SUITE ${TEST_SUITE}
        TEST_FILE ${TEST_FILE}
    )
endif()
