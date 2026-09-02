if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: generated gcovr configuration
# Verifies that, without CMT_GCOVR_CONFIG_FILE, the module writes a gcovr.cfg
# from the CMT_GCOVR_* cache variables and instruments targets with --coverage.

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_gcov_generated_config")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_gcovr")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)
    set(GCOVR_MOCK_PATH "${mock_gcovr_path}" PARENT_SCOPE)
endfunction()

function(test_generated_config_defaults)
    message(STATUS "Test 1: defaults produce an instrumented target and a gcovr.cfg")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovGeneratedConfigTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)

get_target_property(compile_opts mylib COMPILE_OPTIONS)
if(NOT \"\${compile_opts}\" MATCHES \"--coverage\")
    message(FATAL_ERROR \"Expected --coverage in compile options, got: \${compile_opts}\")
endif()

if(NOT TARGET gcovr)
    message(FATAL_ERROR \"Expected the gcovr target to exist\")
endif()
"
    )

    set(src_dir "${TEST_ROOT}/defaults/src")
    set(build_dir "${TEST_ROOT}/defaults/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  x Configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(config_file "${build_dir}/coverage/gcovr_generated.cfg")
    if(NOT EXISTS "${config_file}")
        message(STATUS "  x gcovr_generated.cfg not created")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # The defaults must land in the config file in gcovr's own key = value syntax
    file(READ "${config_file}" config_content)
    foreach(
        expected
        "exclude-unreachable-branches = yes"
        "exclude-throw-branches = yes"
        "html-high-threshold = 95"
        "html-medium-threshold = 85"
    )
        if(NOT config_content MATCHES "${expected}")
            message(STATUS "  x Missing '${expected}' in generated config:\n${config_content}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        endif()
    endforeach()

    # Thresholds are command line arguments, never config file entries
    if(config_content MATCHES "fail-under")
        message(STATUS "  x Generated config must not contain fail-under entries")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    message(STATUS "  ok defaults generate a usable gcovr.cfg")
endfunction()

function(test_generated_config_reflects_cache_variables)
    message(STATUS "Test 2: CMT_GCOVR_* cache variables reach the generated config")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovGeneratedConfigTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)
set(CMT_GCOVR_EXCLUDE \"tests/;third_party/\" CACHE STRING \"\" FORCE)
set(CMT_GCOVR_FILTER \"src/\" CACHE STRING \"\" FORCE)
set(CMT_GCOVR_HTML_TITLE \"My Report\" CACHE STRING \"\" FORCE)
set(CMT_GCOVR_HTML_SELF_CONTAINED OFF CACHE BOOL \"\" FORCE)
set(CMT_GCOVR_EXCLUDE_THROW_BRANCHES OFF CACHE BOOL \"\" FORCE)
set(CMT_GCOVR_DECISIONS ON CACHE BOOL \"\" FORCE)

include(Gcov)

add_library(mylib STATIC lib.c)
Gcov_AddToTarget(mylib PUBLIC)
"
    )

    set(src_dir "${TEST_ROOT}/cache_vars/src")
    set(build_dir "${TEST_ROOT}/cache_vars/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  x Configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${build_dir}/coverage/gcovr_generated.cfg" config_content)

    # Each list entry gets its own line, as gcovr's config parser requires
    foreach(
        expected
        "exclude = tests/"
        "exclude = third_party/"
        "filter = src/"
        "html-title = My Report"
        "html-self-contained = no"
        "decisions = yes"
    )
        if(NOT config_content MATCHES "${expected}")
            message(STATUS "  x Missing '${expected}' in generated config:\n${config_content}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        endif()
    endforeach()

    # Disabled switches must be omitted, not written as "no"
    if(config_content MATCHES "exclude-throw-branches")
        message(STATUS "  x Disabled exclude-throw-branches must be omitted")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    message(STATUS "  ok cache variables are reflected in the generated config")
endfunction()

function(run_all_tests)
    message(STATUS "=== Gcov Generated Configuration Integration Tests ===")

    setup_test_environment()

    test_generated_config_defaults()
    test_generated_config_reflects_cache_variables()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Gcov generated config tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Gcov generated config tests PASSED")
    endif()
endfunction()

run_all_tests()
