if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: Unity module applies CMock memory configuration

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH "${REPO_ROOT}/cmake" ${CMAKE_MODULE_PATH})
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_unity_cmock_memory")
set(TEST_PROJECT_SOURCE_DIR "${TEST_ROOT}/project")
set(TEST_FIXTURE_ROOT "${TEST_ROOT}/fixtures")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_PROJECT_SOURCE_DIR}")

    set(unity_root "${TEST_FIXTURE_ROOT}/unity")
    file(MAKE_DIRECTORY "${unity_root}/src")
    file(MAKE_DIRECTORY "${unity_root}/scripts")
    file(MAKE_DIRECTORY "${unity_root}/auto")

    file(
        WRITE "${unity_root}/src/unity.h"
        "#define UNITY_VERSION_MAJOR 2\n#define UNITY_VERSION_MINOR 6\n#define UNITY_VERSION_BUILD 1\n"
    )
    file(WRITE "${unity_root}/src/unity.c" "int unity_stub(void) { return 0; }\n")

    file(WRITE "${unity_root}/src/cmock.h" "void cmock_stub(void);\n")
    file(WRITE "${unity_root}/src/cmock.c" "void cmock_stub(void) {}\n")
    file(WRITE "${unity_root}/scripts/cmock.rb" "puts 'cmock stub'\n")
    file(
        WRITE
        "${unity_root}/auto/generate_test_runner.rb"
        "puts 'runner stub'\n"
    )

    if(WIN32)
        set(ruby_stub "${TEST_FIXTURE_ROOT}/ruby.bat")
        file(WRITE "${ruby_stub}" "@echo off\r\nexit /b 0\r\n")
    else()
        set(ruby_stub "${TEST_FIXTURE_ROOT}/ruby")
        file(WRITE "${ruby_stub}" "#!/bin/sh\nexit 0\n")
        file(
            CHMOD
            "${ruby_stub}"
            PERMISSIONS
                OWNER_EXECUTE
                OWNER_READ
                OWNER_WRITE
        )
    endif()

    file(TO_CMAKE_PATH "${unity_root}" unity_root_norm)
    file(TO_CMAKE_PATH "${ruby_stub}" ruby_stub_norm)

    set(_project_file
        "
cmake_minimum_required(VERSION 3.22)
project(UnityCMockMemoryTest LANGUAGES C)

set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG FALSE)
set(CMAKE_FIND_USE_CMAKE_SYSTEM_PATH FALSE)
set(CMAKE_FIND_USE_SYSTEM_ENVIRONMENT_PATH FALSE)
set(CMAKE_FIND_USE_CMAKE_ENVIRONMENT_PATH FALSE)
set(CMAKE_FIND_USE_CMAKE_PATH FALSE)
set(CMAKE_PREFIX_PATH \"\")

set(Unity_ROOT \"${unity_root_norm}\")
set(Ruby_EXECUTABLE \"${ruby_stub_norm}\" CACHE FILEPATH \"\")

include(Unity)
Unity_Initialize()

if(NOT TARGET Unity::CMock)
    message(FATAL_ERROR \"Unity::CMock target was not created\")
endif()

get_target_property(cmock_target Unity::CMock ALIASED_TARGET)
if(NOT cmock_target OR cmock_target MATCHES \"-NOTFOUND$\")
    set(cmock_target Unity::CMock)
endif()

get_target_property(cmock_defs \${cmock_target} COMPILE_DEFINITIONS)
get_target_property(cmock_iface_defs \${cmock_target} INTERFACE_COMPILE_DEFINITIONS)

set(all_defs \"\")
if(cmock_defs)
    list(APPEND all_defs \${cmock_defs})
endif()
if(cmock_iface_defs)
    list(APPEND all_defs \${cmock_iface_defs})
endif()
if(all_defs)
    list(REMOVE_DUPLICATES all_defs)
endif()

list(FIND all_defs \"CMOCK_MEM_DYNAMIC\" has_dynamic)
if(has_dynamic EQUAL -1)
    message(FATAL_ERROR \"CMOCK_MEM_DYNAMIC was not applied to Unity::CMock\")
endif()

list(FIND all_defs \"CMOCK_MEM_SIZE=65536\" has_size)
if(has_size EQUAL -1)
    message(FATAL_ERROR \"CMOCK_MEM_SIZE=65536 was not applied to Unity::CMock\")
endif()
"
    )

    file(WRITE "${TEST_PROJECT_SOURCE_DIR}/CMakeLists.txt" "${_project_file}")
endfunction()

function(run_configure_case name)
    set(build_dir "${TEST_ROOT}/${name}")
    TestHelpers_GetConfigureArgs(configure_args)

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${TEST_PROJECT_SOURCE_DIR}" -B "${build_dir}"
            ${configure_args}
            -DCMOCK_MEM_DYNAMIC=ON
            -DCMOCK_MEM_SIZE=65536
        RESULT_VARIABLE configure_result
        OUTPUT_VARIABLE configure_output
        ERROR_VARIABLE configure_error
    )

    if(NOT configure_result EQUAL 0)
        message(STATUS "  [FAIL] ${name}: configure failed")
        message(STATUS "  stdout: ${configure_output}")
        message(STATUS "  stderr: ${configure_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  [PASS] ${name}")
endfunction()

function(run_all_tests)
    message(STATUS "=== Unity Integration Tests (CMock memory) ===")

    setup_test_environment()
    run_configure_case("cmock_memory")

    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Unity integration tests failed with ${ERROR_COUNT} error(s)")
    endif()

    message(STATUS "All Unity integration tests PASSED")
endfunction()

run_all_tests()
