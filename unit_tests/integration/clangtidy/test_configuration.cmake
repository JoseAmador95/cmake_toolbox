if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
endif()

# Integration Test: ClangTidy configuration
# Verifies ClangTidy global and per-target configuration

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_clangtidy")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_global_configuration_on)
    message(STATUS "Test 1: ClangTidy_Configure STATUS ON")

    set(src_dir "${TEST_ROOT}/global_on/src")
    set(build_dir "${TEST_ROOT}/global_on/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    # Create compile_commands.json
    file(WRITE "${build_dir}/compile_commands.json" "[]")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyGlobalTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(ClangTidy)

# Configure globally
ClangTidy_Configure(STATUS ON)

# Check if CMAKE_C_CLANG_TIDY was set (if clang-tidy found)
if(ClangTidy_FOUND)
    if(NOT CMAKE_C_CLANG_TIDY)
        message(FATAL_ERROR \"CMAKE_C_CLANG_TIDY should be set when STATUS ON\")
    endif()
    message(STATUS \"ClangTidy_Configure: CMAKE_C_CLANG_TIDY = \${CMAKE_C_CLANG_TIDY}\")
else()
    message(STATUS \"clang-tidy not found, configuration skipped correctly\")
endif()

add_library(mylib STATIC lib.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
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

    message(STATUS "  ✓ ClangTidy_Configure STATUS ON works")
endfunction()

function(test_global_configuration_off)
    message(STATUS "Test 2: ClangTidy_Configure STATUS OFF")

    set(src_dir "${TEST_ROOT}/global_off/src")
    set(build_dir "${TEST_ROOT}/global_off/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    file(WRITE "${build_dir}/compile_commands.json" "[]")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyGlobalTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(ClangTidy)

# First enable, then disable
ClangTidy_Configure(STATUS ON)
ClangTidy_Configure(STATUS OFF)

# Check CMAKE_C_CLANG_TIDY is empty/unset
if(CMAKE_C_CLANG_TIDY)
    message(FATAL_ERROR \"CMAKE_C_CLANG_TIDY should be empty after STATUS OFF\")
endif()

message(STATUS \"ClangTidy_Configure STATUS OFF correctly cleared settings\")
add_library(mylib STATIC lib.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
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

    message(STATUS "  ✓ ClangTidy_Configure STATUS OFF works")
endfunction()

function(test_per_target_configuration)
    message(STATUS "Test 3: ClangTidy_ConfigureTarget per-target")

    set(src_dir "${TEST_ROOT}/per_target/src")
    set(build_dir "${TEST_ROOT}/per_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    file(WRITE "${build_dir}/compile_commands.json" "[]")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyTargetTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(ClangTidy)

add_library(lib1 STATIC lib1.c)
add_library(lib2 STATIC lib2.c)

# Configure only lib1
ClangTidy_ConfigureTarget(TARGET lib1 STATUS ON)
# Leave lib2 without clang-tidy

if(ClangTidy_FOUND)
    get_target_property(tidy1 lib1 C_CLANG_TIDY)
    get_target_property(tidy2 lib2 C_CLANG_TIDY)
    
    message(STATUS \"lib1 C_CLANG_TIDY: \${tidy1}\")
    message(STATUS \"lib2 C_CLANG_TIDY: \${tidy2}\")
    
    # lib1 should have clang-tidy, lib2 should not
    if(NOT tidy1)
        message(FATAL_ERROR \"lib1 should have C_CLANG_TIDY set\")
    endif()
else()
    message(STATUS \"clang-tidy not found, skipping verification\")
endif()
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib1.c" "int lib1_func(void) { return 1; }")
    file(WRITE "${src_dir}/lib2.c" "int lib2_func(void) { return 2; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
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

    message(STATUS "  ✓ ClangTidy_ConfigureTarget per-target works")
endfunction()

function(test_tool_not_found)
    message(STATUS "Test 4: ClangTidy gracefully handles missing tool")

    set(src_dir "${TEST_ROOT}/no_tool/src")
    set(build_dir "${TEST_ROOT}/no_tool/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangTidyNoToolTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Force tool to not be found
set(ClangTidy_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)
set(ClangTidy_FOUND FALSE CACHE BOOL \"\" FORCE)

include(ClangTidy)

# Configure should not fail even without tool
ClangTidy_Configure(STATUS ON)

add_library(mylib STATIC lib.c)

message(STATUS \"ClangTidy gracefully handled missing tool\")
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Should not fail when clang-tidy missing: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangTidy gracefully handles missing tool")
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangTidy Integration Tests ===")

    setup_test_environment()

    test_global_configuration_on()
    test_global_configuration_off()
    test_per_target_configuration()
    test_tool_not_found()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "ClangTidy tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All ClangTidy tests PASSED")
    endif()
endfunction()

run_all_tests()
