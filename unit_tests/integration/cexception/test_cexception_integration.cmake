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
        CMT_CEXCEPTION_INTEGRATION_ERROR_COUNT
            0
)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_cexception")

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
    get_property(_cmt_test_error_count GLOBAL PROPERTY CMT_CEXCEPTION_INTEGRATION_ERROR_COUNT)
    if(NOT _cmt_test_error_count)
        set(_cmt_test_error_count 0)
    endif()
    math(EXPR _cmt_test_error_count "${_cmt_test_error_count} + 1")
    set_property(
        GLOBAL
        PROPERTY
            CMT_CEXCEPTION_INTEGRATION_ERROR_COUNT
                ${_cmt_test_error_count}
    )
    set(ERROR_COUNT "${_cmt_test_error_count}" PARENT_SCOPE)
endmacro()

function(write_project src_dir)
    file(MAKE_DIRECTORY "${src_dir}/src")
    file(MAKE_DIRECTORY "${src_dir}/include")
    file(MAKE_DIRECTORY "${src_dir}/test")

    set(test_cmake_lists
        "cmake_minimum_required(VERSION 3.22)
project(CExceptionIntegration LANGUAGES C)

list(APPEND CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Isolate from any system-installed CException config packages so that
# FindCException.cmake + FetchContent path is always exercised
set(CMAKE_FIND_USE_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_USE_SYSTEM_PACKAGE_REGISTRY FALSE)
set(CMAKE_FIND_PACKAGE_PREFER_CONFIG FALSE)
set(CMAKE_PREFIX_PATH \"\")

enable_testing()

include(Ceedling)

add_library(mylib STATIC src/mylib.c)
target_include_directories(mylib PUBLIC \"\${CMAKE_CURRENT_SOURCE_DIR}/include\")
target_link_libraries(mylib PRIVATE CException::CException)

Ceedling_AddUnitTest(
    NAME mylib_test
    UNIT_TEST \"\${CMAKE_CURRENT_SOURCE_DIR}/test/test_mylib.c\"
    TARGET mylib
)
"
    )

    set(mylib_header
        "#ifndef MYLIB_H\n#define MYLIB_H\n#define ERR_BAD_ARG 1\nvoid mylib_divide(int a, int b, int *result);\nint mylib_value(void);\n#endif\n"
    )

    set(mylib_source
        "#include \"mylib.h\"\n#include \"CException.h\"\nvoid mylib_divide(int a, int b, int *result) {\n    if (b == 0) Throw(ERR_BAD_ARG);\n    *result = a / b;\n}\nint mylib_value(void) { return 42; }\n"
    )

    set(test_source
        "#include \"unity.h\"\n#include \"CException.h\"\n#include \"mylib.h\"\nvoid setUp(void) {}\nvoid tearDown(void) {}\nvoid test_value(void) {\n    TEST_ASSERT_EQUAL_INT(42, mylib_value());\n}\nvoid test_divide_ok(void) {\n    int result = 0;\n    mylib_divide(10, 2, &result);\n    TEST_ASSERT_EQUAL_INT(5, result);\n}\nvoid test_divide_throws(void) {\n    CEXCEPTION_T e = CEXCEPTION_NONE;\n    int result = 0;\n    Try {\n        mylib_divide(10, 0, &result);\n        TEST_FAIL_MESSAGE(\"Expected exception not thrown\");\n    } Catch(e) {\n        TEST_ASSERT_EQUAL_INT(ERR_BAD_ARG, (int)e);\n    }\n}\n"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_cmake_lists}")
    file(WRITE "${src_dir}/include/mylib.h" "${mylib_header}")
    file(WRITE "${src_dir}/src/mylib.c" "${mylib_source}")
    file(WRITE "${src_dir}/test/test_mylib.c" "${test_source}")
endfunction()

function(configure_project src_dir build_dir)
    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
            -DCMT_CEEDLING_USE_CEXCEPTION=ON
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    if(NOT result EQUAL 0)
        fail("Configure failed:\n${output}\n${error}")
    else()
        message(STATUS "  [PASS] Configure succeeded")
    endif()
endfunction()

function(build_project build_dir)
    set(build_args "")
    if(DEFINED CMAKE_TOOLBOX_TEST_BUILD_TYPE AND NOT CMAKE_TOOLBOX_TEST_BUILD_TYPE STREQUAL "")
        list(
            APPEND build_args
            --config
            "${CMAKE_TOOLBOX_TEST_BUILD_TYPE}"
        )
    endif()

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}" ${build_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    if(NOT result EQUAL 0)
        fail("Build failed:\n${output}\n${error}")
    else()
        message(STATUS "  [PASS] Build succeeded")
    endif()
endfunction()

function(run_tests build_dir)
    set(ctest_args "")
    if(DEFINED CMAKE_TOOLBOX_TEST_BUILD_TYPE AND NOT CMAKE_TOOLBOX_TEST_BUILD_TYPE STREQUAL "")
        list(
            APPEND ctest_args
            -C
            "${CMAKE_TOOLBOX_TEST_BUILD_TYPE}"
        )
    endif()

    if(NOT CMAKE_CTEST_COMMAND)
        set(CMAKE_CTEST_COMMAND ctest)
    endif()
    execute_process(
        COMMAND
            ${CMAKE_CTEST_COMMAND} --test-dir "${build_dir}" ${ctest_args} --output-on-failure
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )
    if(NOT result EQUAL 0)
        fail("Tests failed: ${output}\n${error}")
    else()
        message(STATUS "  [PASS] All tests passed")
    endif()
endfunction()

# ── main ────────────────────────────────────────────────────────────────────

message(STATUS "=== CException integration test ===")
file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${TEST_ROOT}")

set(SRC_DIR "${TEST_ROOT}/src")
set(BUILD_DIR "${TEST_ROOT}/build")

write_project("${SRC_DIR}")

get_property(ERROR_COUNT GLOBAL PROPERTY CMT_CEXCEPTION_INTEGRATION_ERROR_COUNT)
if(ERROR_COUNT EQUAL 0)
    configure_project("${SRC_DIR}" "${BUILD_DIR}")
endif()

get_property(ERROR_COUNT GLOBAL PROPERTY CMT_CEXCEPTION_INTEGRATION_ERROR_COUNT)
if(ERROR_COUNT EQUAL 0)
    build_project("${BUILD_DIR}")
endif()

get_property(ERROR_COUNT GLOBAL PROPERTY CMT_CEXCEPTION_INTEGRATION_ERROR_COUNT)
if(ERROR_COUNT EQUAL 0)
    run_tests("${BUILD_DIR}")
endif()

get_property(ERROR_COUNT GLOBAL PROPERTY CMT_CEXCEPTION_INTEGRATION_ERROR_COUNT)
if(ERROR_COUNT GREATER 0)
    message(FATAL_ERROR "CException integration tests FAILED (${ERROR_COUNT} error(s))")
else()
    message(STATUS "CException integration tests PASSED")
endif()
