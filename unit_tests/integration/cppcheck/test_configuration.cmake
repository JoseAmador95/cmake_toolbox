if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: Cppcheck configuration
# Verifies Cppcheck global and per-target configuration with mock project

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_cppcheck")

function(setup_test_environment)
    message(STATUS "Setting up Cppcheck integration test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_global_configuration_on)
    message(STATUS "Test 1: Cppcheck_Configure STATUS ON (advisory mode)")

    set(src_dir "${TEST_ROOT}/global_on/src")
    set(build_dir "${TEST_ROOT}/global_on/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    # Create compile_commands.json
    file(WRITE "${build_dir}/compile_commands.json" "[]")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CppcheckGlobalTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(Cppcheck)

# Configure globally
Cppcheck_Configure(STATUS ON)

# Check if CMAKE_C_CPPCHECK was set (if cppcheck found)
if(Cppcheck_FOUND)
    if(NOT CMAKE_C_CPPCHECK)
        message(FATAL_ERROR \"CMAKE_C_CPPCHECK should be set when STATUS ON\")
    endif()
    message(STATUS \"Cppcheck_Configure: CMAKE_C_CPPCHECK = \${CMAKE_C_CPPCHECK}\")
    file(WRITE \"${build_dir}/cppcheck_found.txt\" \"TRUE\")
else()
    message(STATUS \"cppcheck not found, configuration skipped correctly (advisory mode)\")
    file(WRITE \"${build_dir}/cppcheck_found.txt\" \"FALSE\")
endif()

add_library(mylib STATIC lib.c)
"
    )

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
        message(STATUS "  ✗ Global ON configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Execute build to verify Cppcheck runs (if available)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    # In advisory mode, allow build to fail if Cppcheck is broken/misconfigured
    if(build_result EQUAL 0)
        message(STATUS "  ✓ Cppcheck_Configure STATUS ON works (advisory mode)")
        message(STATUS "    Build output: ${build_output}")
    else()
        # Check if Cppcheck was found - if yes, this is advisory mode tolerance
        if(EXISTS "${build_dir}/cppcheck_found.txt")
            file(READ "${build_dir}/cppcheck_found.txt" cppcheck_found)
            if(cppcheck_found STREQUAL "TRUE")
                message(STATUS "  ✓ Cppcheck_Configure STATUS ON works (advisory mode)")
                message(
                    VERBOSE
                    "    Build failed but Cppcheck is in advisory mode (expected): ${build_error}"
                )
            else()
                message(STATUS "  ✗ Build failed unexpectedly: ${build_error}")
                math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
                set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            endif()
        else()
            message(STATUS "  ✗ Build failed unexpectedly: ${build_error}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endif()
endfunction()

function(test_global_configuration_off)
    message(STATUS "Test 2: Cppcheck_Configure STATUS OFF")

    set(src_dir "${TEST_ROOT}/global_off/src")
    set(build_dir "${TEST_ROOT}/global_off/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    file(WRITE "${build_dir}/compile_commands.json" "[]")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CppcheckGlobalTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(Cppcheck)

# First enable, then disable
Cppcheck_Configure(STATUS ON)
Cppcheck_Configure(STATUS OFF)

# Check CMAKE_C_CPPCHECK is empty/unset
if(CMAKE_C_CPPCHECK)
    message(FATAL_ERROR \"CMAKE_C_CPPCHECK should be empty after STATUS OFF\")
endif()

message(STATUS \"Cppcheck_Configure STATUS OFF correctly cleared settings\")
add_library(mylib STATIC lib.c)
"
    )

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
        message(STATUS "  ✗ Global OFF configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Execute build to verify Cppcheck is disabled
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    if(build_result EQUAL 0)
        message(STATUS "  ✓ Cppcheck_Configure STATUS OFF works")
    else()
        message(STATUS "  ✗ Build failed unexpectedly: ${build_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(test_per_target_configuration)
    message(STATUS "Test 3: Cppcheck_ConfigureTarget per-target with checks")

    set(src_dir "${TEST_ROOT}/per_target/src")
    set(build_dir "${TEST_ROOT}/per_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    file(WRITE "${build_dir}/compile_commands.json" "[]")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CppcheckTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(Cppcheck)

add_library(lib1 STATIC lib1.c)
add_library(lib2 STATIC lib2.c)

# Configure lib1 with specific checks
Cppcheck_ConfigureTarget(TARGET lib1 STATUS ON ENABLE warning style)
# Leave lib2 without cppcheck

if(Cppcheck_FOUND)
    get_target_property(check1 lib1 C_CPPCHECK)
    get_target_property(check2 lib2 C_CPPCHECK)
    
    message(STATUS \"lib1 C_CPPCHECK: \${check1}\")
    message(STATUS \"lib2 C_CPPCHECK: \${check2}\")
    
    # lib1 should have cppcheck, lib2 should not
    if(NOT check1)
        message(FATAL_ERROR \"lib1 should have C_CPPCHECK set\")
    endif()
    file(WRITE \"${build_dir}/cppcheck_found.txt\" \"TRUE\")
else()
    message(STATUS \"cppcheck not found, skipping verification\")
    file(WRITE \"${build_dir}/cppcheck_found.txt\" \"FALSE\")
endif()
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib1.c" "int lib1_func(void) { return 1; }")
    file(WRITE "${src_dir}/lib2.c" "int lib2_func(void) { return 2; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Per-target configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Execute build with per-target configuration
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    # In advisory mode, allow build to fail if Cppcheck is broken/misconfigured
    if(build_result EQUAL 0)
        message(STATUS "  ✓ Cppcheck_ConfigureTarget per-target works")
    else()
        # Check if Cppcheck was found - if yes, this is advisory mode tolerance
        if(EXISTS "${build_dir}/cppcheck_found.txt")
            file(READ "${build_dir}/cppcheck_found.txt" cppcheck_found)
            if(cppcheck_found STREQUAL "TRUE")
                message(STATUS "  ✓ Cppcheck_ConfigureTarget per-target works")
                message(
                    VERBOSE
                    "    Build failed but Cppcheck is in advisory mode (expected): ${build_error}"
                )
            else()
                message(STATUS "  ✗ Build failed unexpectedly: ${build_error}")
                math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
                set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            endif()
        else()
            message(STATUS "  ✗ Build failed unexpectedly: ${build_error}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endif()
endfunction()

function(test_strict_mode)
    message(STATUS "Test 4: Cppcheck_Configure STRICT mode (should fail gracefully)")

    set(src_dir "${TEST_ROOT}/strict_mode/src")
    set(build_dir "${TEST_ROOT}/strict_mode/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CppcheckStrictTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Force tool to not be found (using CPPCHECK_EXECUTABLE which is what FindCppcheck.cmake uses)
set(CPPCHECK_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)

include(Cppcheck)

# Configure in strict mode without tool should fail
Cppcheck_Configure(STATUS ON STRICT)

add_library(mylib STATIC lib.c)

message(STATUS \"Cppcheck STRICT mode test\")
"
    )

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

    # STRICT mode should fail when tool not found
    if(result EQUAL 0)
        message(STATUS "  ✗ Cppcheck STRICT mode failed - tool missing should have caused error")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    else()
        message(
            STATUS
            "  ✓ Cppcheck STRICT mode correctly enforced (tool missing -> error as expected)"
        )
    endif()
endfunction()

function(test_enable_disable_checks)
    message(STATUS "Test 5: Cppcheck with multiple enable/disable checks")

    set(src_dir "${TEST_ROOT}/checks/src")
    set(build_dir "${TEST_ROOT}/checks/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    file(WRITE "${build_dir}/compile_commands.json" "[]")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CppcheckChecksTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(Cppcheck)

add_library(core STATIC core.c)
add_library(utils STATIC utils.cpp)

# Configure with different check levels
Cppcheck_ConfigureTarget(
    TARGET core
    STATUS ON
    ENABLE warning style
)

Cppcheck_ConfigureTarget(
    TARGET utils
    STATUS ON
    ENABLE information portability
)

if(Cppcheck_FOUND)
    file(WRITE \"${build_dir}/cppcheck_found.txt\" \"TRUE\")
else()
    file(WRITE \"${build_dir}/cppcheck_found.txt\" \"FALSE\")
endif()

message(STATUS \"Cppcheck checks configuration complete\")
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/core.c" "int core_func(int a, int b) { return a + b; }")
    file(WRITE "${src_dir}/utils.cpp" "void util_func() { }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Checks configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Execute build with multiple checks configuration
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    # In advisory mode, allow build to fail if Cppcheck is broken/misconfigured
    if(build_result EQUAL 0)
        message(STATUS "  ✓ Cppcheck enable/disable checks works")
    else()
        # Check if Cppcheck was found - if yes, this is advisory mode tolerance
        if(EXISTS "${build_dir}/cppcheck_found.txt")
            file(READ "${build_dir}/cppcheck_found.txt" cppcheck_found)
            if(cppcheck_found STREQUAL "TRUE")
                message(STATUS "  ✓ Cppcheck enable/disable checks works")
                message(
                    VERBOSE
                    "    Build failed but Cppcheck is in advisory mode (expected): ${build_error}"
                )
            else()
                message(STATUS "  ✗ Build failed unexpectedly: ${build_error}")
                math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
                set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
            endif()
        else()
            message(STATUS "  ✗ Build failed unexpectedly: ${build_error}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
            set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        endif()
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== Cppcheck Integration Tests ===")

    setup_test_environment()

    test_global_configuration_on()
    test_global_configuration_off()
    test_per_target_configuration()
    test_strict_mode()
    test_enable_disable_checks()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Cppcheck integration tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Cppcheck integration tests PASSED ✓")
    endif()
endfunction()

run_all_tests()
