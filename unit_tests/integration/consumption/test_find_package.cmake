if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: installed package consumption via find_package

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_consumption_find_package")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    if(NOT EXISTS "${TEST_ROOT}")
        message(FATAL_ERROR "Failed to create test root directory: ${TEST_ROOT}")
    endif()
endfunction()

function(test_find_package_consumption)
    message(STATUS "Test: find_package consumption from installed toolbox")

    set(toolbox_build_dir "${TEST_ROOT}/toolbox/build")
    set(toolbox_install_prefix "${TEST_ROOT}/toolbox/install")
    set(consumer_src_dir "${TEST_ROOT}/consumer/src")
    set(consumer_build_dir "${TEST_ROOT}/consumer/build")

    file(MAKE_DIRECTORY "${consumer_src_dir}")

    set(test_project
        "
cmake_minimum_required(VERSION 3.22)
project(ConsumerFindPackage LANGUAGES C)

find_package(cmake_toolbox CONFIG REQUIRED)

include(Policy)
include(ClangFormat)

 add_library(consumer_lib STATIC consumer_lib.c)
 add_executable(consumer_app consumer_app.c)
 target_link_libraries(consumer_app PRIVATE consumer_lib)
  file(GENERATE OUTPUT \${CMAKE_BINARY_DIR}/$<CONFIG>/consumer_app.target_path CONTENT $<TARGET_FILE:consumer_app>)
 "
    )

    file(WRITE "${consumer_src_dir}/CMakeLists.txt" "${test_project}")
    file(WRITE "${consumer_src_dir}/consumer_lib.c" "int consumer_lib_value(void) { return 13; }")
    file(
        WRITE "${consumer_src_dir}/consumer_app.c"
        "int consumer_lib_value(void); int main(void) { return consumer_lib_value() == 13 ? 0 : 1; }"
    )

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${REPO_ROOT}" -B "${toolbox_build_dir}" ${configure_args}
            -DCMAKE_TOOLBOX_BUILD_EXAMPLES=OFF -DCMAKE_INSTALL_LIBDIR=lib
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(NOT configure_result EQUAL 0)
        message(STATUS "  [FAIL] Toolbox configure failed")
        message(STATUS "  stdout: ${configure_output}")
        message(STATUS "  stderr: ${configure_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${toolbox_build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    if(NOT build_result EQUAL 0)
        message(STATUS "  [FAIL] Toolbox build failed")
        message(STATUS "  stdout: ${build_output}")
        message(STATUS "  stderr: ${build_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --install "${toolbox_build_dir}" --prefix "${toolbox_install_prefix}"
        RESULT_VARIABLE install_result
        OUTPUT_VARIABLE install_output
        ERROR_VARIABLE install_error
    )

    if(NOT install_result EQUAL 0)
        message(STATUS "  [FAIL] Toolbox install failed")
        message(STATUS "  stdout: ${install_output}")
        message(STATUS "  stderr: ${install_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(installed_package_dir "${toolbox_install_prefix}/lib/cmake/cmake_toolbox")
    if(NOT EXISTS "${installed_package_dir}/cmake_toolboxConfig.cmake")
        message(STATUS "  [FAIL] cmake_toolboxConfig.cmake was not installed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    if(NOT EXISTS "${installed_package_dir}/Policy.cmake")
        message(STATUS "  [FAIL] Policy.cmake was not installed")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${consumer_src_dir}" -B "${consumer_build_dir}" ${configure_args}
            -DCMAKE_PREFIX_PATH=${toolbox_install_prefix}
        RESULT_VARIABLE consumer_result
        OUTPUT_VARIABLE consumer_output
        ERROR_VARIABLE consumer_error
    )

    if(NOT consumer_result EQUAL 0)
        message(STATUS "  [FAIL] Consumer configure with find_package failed")
        message(STATUS "  stdout: ${consumer_output}")
        message(STATUS "  stderr: ${consumer_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${consumer_build_dir}" --target consumer_app
        RESULT_VARIABLE consumer_build_result
        OUTPUT_VARIABLE consumer_build_output
        ERROR_VARIABLE consumer_build_error
    )

    if(NOT consumer_build_result EQUAL 0)
        message(STATUS "  [FAIL] Consumer build with find_package failed")
        message(STATUS "  stdout: ${consumer_build_output}")
        message(STATUS "  stderr: ${consumer_build_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(target_path_file "")
    if(EXISTS "${consumer_build_dir}/consumer_app.target_path")
        set(target_path_file "${consumer_build_dir}/consumer_app.target_path")
    else()
        file(GLOB config_target_files "${consumer_build_dir}/*/consumer_app.target_path")
        list(LENGTH config_target_files config_target_count)
        if(config_target_count GREATER 0)
            list(GET config_target_files 0 target_path_file)
        endif()
    endif()

    if(target_path_file STREQUAL "")
        message(STATUS "  [FAIL] find_package target path metadata was not generated")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${target_path_file}" consumer_app_path)
    string(STRIP "${consumer_app_path}" consumer_app_path)
    if(consumer_app_path STREQUAL "" OR NOT EXISTS "${consumer_app_path}")
        message(
            STATUS
            "  [FAIL] find_package linked consumer target was not produced at resolved path"
        )
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  [PASS] find_package consumption configures and builds linked consumer target")
endfunction()

function(run_all_tests)
    message(STATUS "=== Consumption Integration Tests (find_package) ===")

    setup_test_environment()
    test_find_package_consumption()

    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "find_package consumption tests failed with ${ERROR_COUNT} error(s)")
    endif()

    message(STATUS "All find_package consumption tests passed")
endfunction()

run_all_tests()
