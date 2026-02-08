if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: cmake_toolbox consumption via add_subdirectory

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_consumption_add_subdirectory")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    if(NOT EXISTS "${TEST_ROOT}")
        message(FATAL_ERROR "Failed to create test root directory: ${TEST_ROOT}")
    endif()
endfunction()

function(test_add_subdirectory_consumption)
    message(STATUS "Test: add_subdirectory consumption")

    set(src_dir "${TEST_ROOT}/consumer/src")
    set(build_dir "${TEST_ROOT}/consumer/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_project
        "
cmake_minimum_required(VERSION 3.22)
project(ConsumerAddSubdirectory LANGUAGES C)

add_subdirectory(\"${REPO_ROOT}\" \"\${CMAKE_BINARY_DIR}/cmake_toolbox\")
list(PREPEND CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(Policy)
include(ClangFormat)

add_library(consumer STATIC consumer.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_project}")
    file(WRITE "${src_dir}/consumer.c" "int consumer(void) { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  [FAIL] add_subdirectory configure failed")
        message(STATUS "  stdout: ${output}")
        message(STATUS "  stderr: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  [PASS] add_subdirectory consumption works")
endfunction()

function(run_all_tests)
    message(STATUS "=== Consumption Integration Tests (add_subdirectory) ===")

    setup_test_environment()
    test_add_subdirectory_consumption()

    if(ERROR_COUNT GREATER 0)
        message(
            FATAL_ERROR
            "add_subdirectory consumption tests failed with ${ERROR_COUNT} error(s)"
        )
    endif()

    message(STATUS "All add_subdirectory consumption tests passed")
endfunction()

run_all_tests()
