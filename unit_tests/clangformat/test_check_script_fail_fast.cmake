if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
endif()

# Test: ClangFormatCheck script fail-fast behavior

set(ERROR_COUNT 0)
set(TEST_DIR "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/clangformat_check_fail_fast_test")

function(setup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    file(WRITE "${TEST_DIR}/sample.c" "int  main(){return 0;}\n")
endfunction()

function(test_formatter_process_fail_fast)
    message(STATUS "Test 1: ClangFormatCheck fails fast on formatter error")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -D "CLANG_FORMAT_EXECUTABLE=${CMAKE_COMMAND}" -D
            "CLANG_FORMAT_ADDITIONAL_ARGS=--definitely-invalid-option" -D
            "CLANG_FORMAT_FILES=${TEST_DIR}/sample.c" -P
            "${CMAKE_CURRENT_LIST_DIR}/../../cmake/ClangFormatCheck.cmake"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(result EQUAL 0)
        message(STATUS "  ✗ Expected formatter invocation failure, but command succeeded")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    string(
        FIND "${output}${error}"
        "clang-format failed for"
        has_fail_fast_message
    )
    if(has_fail_fast_message EQUAL -1)
        message(STATUS "  ✗ Missing fail-fast error message")
        message(STATUS "    Output: ${output}")
        message(STATUS "    Error: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Formatter failures are reported immediately")
endfunction()

function(cleanup_test_environment)
    file(REMOVE_RECURSE "${TEST_DIR}")
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormatCheck Fail-Fast Tests ===")

    setup_test_environment()
    test_formatter_process_fail_fast()
    cleanup_test_environment()

    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "ClangFormatCheck fail-fast tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All ClangFormatCheck fail-fast tests PASSED")
    endif()
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
    run_all_tests()
endif()
