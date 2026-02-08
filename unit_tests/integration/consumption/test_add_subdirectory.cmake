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
set(CMAKE_MODULE_PATH "${REPO_ROOT}/cmake" ${CMAKE_MODULE_PATH})
include(TestHelpers)

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

 add_library(consumer_lib STATIC consumer_lib.c)
 add_executable(consumer_app consumer_app.c)
 target_link_libraries(consumer_app PRIVATE consumer_lib)
 file(GENERATE OUTPUT \${CMAKE_BINARY_DIR}/consumer_app.target_path CONTENT $<TARGET_FILE:consumer_app>)
 "
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_project}")
    file(WRITE "${src_dir}/consumer_lib.c" "int consumer_lib_value(void) { return 7; }")
    file(
        WRITE "${src_dir}/consumer_app.c"
        "int consumer_lib_value(void); int main(void) { return consumer_lib_value() == 7 ? 0 : 1; }"
    )

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
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

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}" --target consumer_app
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    if(NOT build_result EQUAL 0)
        message(STATUS "  [FAIL] add_subdirectory build failed")
        message(STATUS "  stdout: ${build_output}")
        message(STATUS "  stderr: ${build_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT EXISTS "${build_dir}/consumer_app.target_path")
        message(STATUS "  [FAIL] add_subdirectory target path metadata was not generated")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${build_dir}/consumer_app.target_path" consumer_app_path)
    string(STRIP "${consumer_app_path}" consumer_app_path)
    if(consumer_app_path STREQUAL "" OR NOT EXISTS "${consumer_app_path}")
        message(STATUS "  [FAIL] add_subdirectory linked consumer target was not produced at resolved path")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  [PASS] add_subdirectory consumption configures and builds linked consumer target")
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
