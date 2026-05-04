if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set_property(
    GLOBAL
    PROPERTY
        CMT_CEEDLING_GCOVR_POST_RUN_ERROR_COUNT
            0
)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_ceedling_gcovr_post_run")

set(_cmt_test_build_config "")
if(DEFINED CMAKE_TOOLBOX_TEST_BUILD_TYPE AND NOT CMAKE_TOOLBOX_TEST_BUILD_TYPE STREQUAL "")
    set(_cmt_test_build_config "${CMAKE_TOOLBOX_TEST_BUILD_TYPE}")
elseif(
    DEFINED
        CMAKE_TOOLBOX_TEST_GENERATOR
    AND CMAKE_TOOLBOX_TEST_GENERATOR
        MATCHES
        "Visual Studio|Xcode|Multi-Config|Ninja Multi-Config"
)
    set(_cmt_test_build_config "Debug")
endif()

if(_cmt_test_build_config)
    set(CMAKE_TOOLBOX_TEST_BUILD_TYPE "${_cmt_test_build_config}")
endif()

macro(fail message_text)
    message(STATUS "  FAIL: ${message_text}")
    get_property(_cmt_test_error_count GLOBAL PROPERTY CMT_CEEDLING_GCOVR_POST_RUN_ERROR_COUNT)
    if(NOT _cmt_test_error_count)
        set(_cmt_test_error_count 0)
    endif()
    math(EXPR _cmt_test_error_count "${_cmt_test_error_count} + 1")
    set_property(
        GLOBAL
        PROPERTY
            CMT_CEEDLING_GCOVR_POST_RUN_ERROR_COUNT
                ${_cmt_test_error_count}
    )
    set(ERROR_COUNT "${_cmt_test_error_count}" PARENT_SCOPE)
endmacro()

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_gcovr")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)
    set(GCOVR_MOCK_PATH "${mock_gcovr_path}" PARENT_SCOPE)
endfunction()

function(write_project src_dir)
    file(MAKE_DIRECTORY "${src_dir}/src")
    file(MAKE_DIRECTORY "${src_dir}/include")
    file(MAKE_DIRECTORY "${src_dir}/test")

    set(test_cmake_lists
        "cmake_minimum_required(VERSION 3.22)
project(CeedlingGcovrPostRun LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
enable_testing()

include(Ceedling)

add_library(testlib STATIC src/library.c)
target_include_directories(testlib PUBLIC \"\${CMAKE_CURRENT_SOURCE_DIR}/include\")

Ceedling_AddUnitTest(
    NAME gcovr_post_run_test
    UNIT_TEST \"\${CMAKE_CURRENT_SOURCE_DIR}/test/test_library.c\"
    TARGET testlib
)
"
    )

    set(library_header
        "#ifndef TEST_LIBRARY_H\n#define TEST_LIBRARY_H\n\nint library_value(void);\n\n#endif\n"
    )

    set(library_source "int library_value(void) { return 42; }\n")

    set(test_source
        "#include \"unity.h\"\n#include \"library.h\"\n\nvoid setUp(void) {}\nvoid tearDown(void) {}\n\nvoid test_library_value(void) {\n    TEST_ASSERT_EQUAL_INT(42, library_value());\n}\n"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_cmake_lists}")
    file(WRITE "${src_dir}/include/library.h" "${library_header}")
    file(WRITE "${src_dir}/src/library.c" "${library_source}")
    file(WRITE "${src_dir}/test/test_library.c" "${test_source}")
endfunction()

function(configure_project build_dir)
    set(options "")
    set(oneValueArgs CMT_GCOVR_EXECUTABLE)
    set(multiValueArgs EXTRA_ARGS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${SRC_DIR}" -B "${build_dir}" ${configure_args}
            -DCMT_CEEDLING_ENABLE_GCOV=ON "-DCMT_GCOVR_EXECUTABLE=${ARG_CMT_GCOVR_EXECUTABLE}"
            ${ARG_EXTRA_ARGS}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        fail("Configuration failed: ${error}")
        return()
    endif()
endfunction()

function(read_ctest_file build_dir output_var)
    set(ctest_file "${build_dir}/CTestTestfile.cmake")
    if(NOT EXISTS "${ctest_file}")
        fail("CTestTestfile.cmake not found: ${ctest_file}")
        return()
    endif()
    file(READ "${ctest_file}" content)
    string(REPLACE "\n" " " content "${content}")
    string(REPLACE "\r" " " content "${content}")
    set(${output_var} "${content}" PARENT_SCOPE)
endfunction()

function(detect_msvc build_dir output_var)
    set(is_msvc OFF)
    set(cache_file "${build_dir}/CMakeCache.txt")
    if(EXISTS "${cache_file}")
        file(STRINGS "${cache_file}" compiler_id_line REGEX "^CMAKE_C_COMPILER_ID:.*=")
        if(compiler_id_line MATCHES "MSVC")
            set(is_msvc ON)
        endif()
        file(STRINGS "${cache_file}" compiler_id_line_cxx REGEX "^CMAKE_CXX_COMPILER_ID:.*=")
        if(compiler_id_line_cxx MATCHES "MSVC")
            set(is_msvc ON)
        endif()
        file(STRINGS "${cache_file}" frontend_line REGEX "^CMAKE_C_COMPILER_FRONTEND_VARIANT:.*=")
        if(frontend_line MATCHES "MSVC")
            set(is_msvc ON)
        endif()
        file(
            STRINGS "${cache_file}"
            frontend_line_cxx
            REGEX "^CMAKE_CXX_COMPILER_FRONTEND_VARIANT:.*="
        )
        if(frontend_line_cxx MATCHES "MSVC")
            set(is_msvc ON)
        endif()
        file(STRINGS "${cache_file}" simulate_line REGEX "^CMAKE_C_SIMULATE_ID:.*=")
        if(simulate_line MATCHES "MSVC")
            set(is_msvc ON)
        endif()
        file(STRINGS "${cache_file}" simulate_line_cxx REGEX "^CMAKE_CXX_SIMULATE_ID:.*=")
        if(simulate_line_cxx MATCHES "MSVC")
            set(is_msvc ON)
        endif()
        file(STRINGS "${cache_file}" compiler_path_line REGEX "^CMAKE_C_COMPILER:.*=")
        if(
            compiler_path_line
                MATCHES
                "[cC][lL]\\.exe"
            OR compiler_path_line
                MATCHES
                "[cC][lL][aA][nN][gG]-[cC][lL]"
        )
            set(is_msvc ON)
        endif()
        file(STRINGS "${cache_file}" compiler_path_line_cxx REGEX "^CMAKE_CXX_COMPILER:.*=")
        if(
            compiler_path_line_cxx
                MATCHES
                "[cC][lL]\\.exe"
            OR compiler_path_line_cxx
                MATCHES
                "[cC][lL][aA][nN][gG]-[cC][lL]"
        )
            set(is_msvc ON)
        endif()
        file(STRINGS "${cache_file}" generator_line REGEX "^CMAKE_GENERATOR:.*=")
        if(generator_line MATCHES "Visual Studio")
            set(is_msvc ON)
        endif()
    endif()
    set(${output_var} ${is_msvc} PARENT_SCOPE)
endfunction()

function(test_post_run_default_on)
    message(STATUS "Test 1: gcovr post-run enabled by default")
    set(build_dir "${TEST_ROOT}/post_run_on/build")
    configure_project("${build_dir}" CMT_GCOVR_EXECUTABLE "${GCOVR_MOCK_PATH}")
    detect_msvc("${build_dir}" is_msvc)
    if(is_msvc)
        message(STATUS "  SKIP: MSVC toolchain detected")
        return()
    endif()

    read_ctest_file("${build_dir}" ctest_content)
    if(NOT ctest_content MATCHES "add_test\\([^)]*gcovr_unit")
        fail("Expected gcovr_unit test to be registered")
    endif()
    if(NOT ctest_content MATCHES "gcovr_post_run_test.*FIXTURES_REQUIRED.*gcovr_unit")
        fail("Expected gcovr_post_run_test to require gcovr_unit fixture")
    endif()
endfunction()

function(test_post_run_disabled)
    message(STATUS "Test 2: gcovr post-run disabled")
    set(build_dir "${TEST_ROOT}/post_run_off/build")
    configure_project(
        "${build_dir}"
        CMT_GCOVR_EXECUTABLE
            "${GCOVR_MOCK_PATH}"
        EXTRA_ARGS
            -DCMT_CEEDLING_GCOVR_POST_RUN=OFF
    )

    read_ctest_file("${build_dir}" ctest_content)
    if(ctest_content MATCHES "gcovr_unit")
        fail("gcovr_unit should not be registered when post-run is disabled")
    endif()
    if(ctest_content MATCHES "gcovr_post_run_test.*FIXTURES_REQUIRED")
        fail("Fixtures should not be required when post-run is disabled")
    endif()
endfunction()

function(test_extract_functions_fixture)
    message(STATUS "Test 3: extract functions adds fixtures to discovered tests")
    set(build_dir "${TEST_ROOT}/extract_functions/build")
    configure_project(
        "${build_dir}"
        CMT_GCOVR_EXECUTABLE
            "${GCOVR_MOCK_PATH}"
        EXTRA_ARGS
            -DCMT_CEEDLING_EXTRACT_FUNCTIONS=ON
            -DCMT_CEEDLING_GCOVR_POST_RUN=ON
    )
    detect_msvc("${build_dir}" is_msvc)
    if(is_msvc)
        message(STATUS "  SKIP: MSVC toolchain detected")
        return()
    endif()

    set(build_args "")
    if(_cmt_test_build_config)
        set(build_args
            --config
            "${_cmt_test_build_config}"
        )
    endif()

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}" --target gcovr_post_run_test ${build_args}
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    if(NOT build_result EQUAL 0)
        fail("Build failed: ${build_error}")
        return()
    endif()

    read_ctest_file("${build_dir}" ctest_content)
    if(NOT ctest_content MATCHES "add_test\\([^)]*gcovr_unit")
        fail("Expected gcovr_unit test to be registered")
    endif()

    set(discovered_tests_file "${build_dir}/gcovr_post_run_test_tests.cmake")
    if(NOT EXISTS "${discovered_tests_file}")
        fail("Discovered tests file not generated: ${discovered_tests_file}")
        return()
    endif()

    file(READ "${discovered_tests_file}" discovered_content)
    string(REPLACE "\n" " " discovered_content "${discovered_content}")
    string(REPLACE "\r" " " discovered_content "${discovered_content}")
    if(NOT discovered_content MATCHES "FIXTURES_REQUIRED.*gcovr_unit")
        message(STATUS "  Debug discovered tests file: ${discovered_tests_file}")
        message(STATUS "  Content: ${discovered_content}")
        fail("Expected fixtures to be required for extracted tests")
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== Ceedling gcovr post-run integration tests ===")

    setup_test_environment()
    set(SRC_DIR "${TEST_ROOT}/src")
    write_project("${SRC_DIR}")

    test_post_run_default_on()
    test_post_run_disabled()
    test_extract_functions_fixture()

    message(STATUS "")
    get_property(_cmt_test_error_count GLOBAL PROPERTY CMT_CEEDLING_GCOVR_POST_RUN_ERROR_COUNT)
    if(NOT _cmt_test_error_count)
        set(_cmt_test_error_count 0)
    endif()
    if(_cmt_test_error_count GREATER 0)
        message(FATAL_ERROR "Ceedling gcovr post-run tests failed with ${_cmt_test_error_count} error(s)")
    else()
        message(STATUS "Ceedling gcovr post-run tests PASSED")
    endif()
endfunction()

run_all_tests()
