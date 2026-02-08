if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
endif()

# Integration Test: cmake_toolbox consumption via FetchContent

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_consumption_fetchcontent")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    if(NOT EXISTS "${TEST_ROOT}")
        message(FATAL_ERROR "Failed to create test root directory: ${TEST_ROOT}")
    endif()
endfunction()

function(test_fetchcontent_consumption)
    message(STATUS "Test: FetchContent consumption")

    set(src_dir "${TEST_ROOT}/consumer/src")
    set(build_dir "${TEST_ROOT}/consumer/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_project
        "
cmake_minimum_required(VERSION 3.22)
project(ConsumerFetchContent LANGUAGES C)

include(FetchContent)

FetchContent_Declare(
    cmake_toolbox
    SOURCE_DIR \"${REPO_ROOT}\"
)
FetchContent_MakeAvailable(cmake_toolbox)

list(PREPEND CMAKE_MODULE_PATH \"\${cmake_toolbox_SOURCE_DIR}/cmake\")

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
        message(STATUS "  [FAIL] FetchContent configure failed")
        message(STATUS "  stdout: ${output}")
        message(STATUS "  stderr: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  [PASS] FetchContent consumption works")
endfunction()

function(run_all_tests)
    message(STATUS "=== Consumption Integration Tests (FetchContent) ===")

    setup_test_environment()
    test_fetchcontent_consumption()

    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "FetchContent consumption tests failed with ${ERROR_COUNT} error(s)")
    endif()

    message(STATUS "All FetchContent consumption tests passed")
endfunction()

run_all_tests()
