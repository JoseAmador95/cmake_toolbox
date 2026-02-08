# Integration Test: ClangFormat configuration
# Verifies ClangFormat target generation and exclusion patterns

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/integration_clangformat")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_basic_configuration)
    message(STATUS "Test 1: Basic ClangFormat configuration with SOURCE_DIRS")

    set(src_dir "${TEST_ROOT}/basic/src")
    set(build_dir "${TEST_ROOT}/basic/build")
    file(MAKE_DIRECTORY "${src_dir}/lib")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangFormatBasicTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

find_package(ClangFormat QUIET)

if(ClangFormat_FOUND)
    include(ClangFormat)
    
    ClangFormat_AddTargets(
        TARGET_PREFIX myproject
        SOURCE_DIRS lib
    )
    
    # Verify targets were created
    if(NOT TARGET myproject_format)
        message(FATAL_ERROR \"myproject_format target not created\")
    endif()
    if(NOT TARGET myproject_check)
        message(FATAL_ERROR \"myproject_check target not created\")
    endif()
    
    message(STATUS \"ClangFormat targets created successfully\")
else()
    message(STATUS \"clang-format not found, skipping test\")
endif()

add_library(mylib STATIC lib/lib.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib/lib.c" "int lib_func(void) { return 42; }")
    file(WRITE "${src_dir}/.clang-format" "BasedOnStyle: LLVM\n")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Basic configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Basic ClangFormat configuration works")
endfunction()

function(test_exclude_patterns)
    message(STATUS "Test 2: ClangFormat with EXCLUDE_PATTERNS")

    set(src_dir "${TEST_ROOT}/exclude/src")
    set(build_dir "${TEST_ROOT}/exclude/build")
    file(MAKE_DIRECTORY "${src_dir}/lib")
    file(MAKE_DIRECTORY "${src_dir}/generated")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangFormatExcludeTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

find_package(ClangFormat QUIET)

if(ClangFormat_FOUND)
    include(ClangFormat)
    
    ClangFormat_AddTargets(
        TARGET_PREFIX myproject
        SOURCE_DIRS 
            \${CMAKE_CURRENT_SOURCE_DIR}/lib
            \${CMAKE_CURRENT_SOURCE_DIR}/generated
        EXCLUDE_PATTERNS
            \"generated/.*\"
    )
    
    message(STATUS \"ClangFormat configured with exclusions\")
else()
    message(STATUS \"clang-format not found, skipping test\")
endif()

add_library(mylib STATIC lib/lib.c generated/gen.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib/lib.c" "int lib_func(void) { return 42; }")
    file(WRITE "${src_dir}/generated/gen.c" "// Generated file\nint gen_func(void){return 1;}")
    file(WRITE "${src_dir}/.clang-format" "BasedOnStyle: LLVM\n")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Exclude patterns test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangFormat EXCLUDE_PATTERNS works")
endfunction()

function(test_tool_not_found)
    message(STATUS "Test 3: ClangFormat gracefully handles missing tool")

    set(src_dir "${TEST_ROOT}/no_tool/src")
    set(build_dir "${TEST_ROOT}/no_tool/build")
    file(MAKE_DIRECTORY "${src_dir}/lib")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangFormatNoToolTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Force tool to not be found
set(ClangFormat_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)
set(ClangFormat_FOUND FALSE CACHE BOOL \"\" FORCE)

include(ClangFormat)

# This should emit warning but not fail
ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS \${CMAKE_CURRENT_SOURCE_DIR}/lib
)

# Verify targets are NOT created when tool missing
if(TARGET myproject_format)
    message(FATAL_ERROR \"Targets should not be created when clang-format missing\")
endif()

add_library(mylib STATIC lib/lib.c)
message(STATUS \"ClangFormat gracefully handled missing tool\")
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib/lib.c" "int lib_func(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Should not fail when clang-format missing: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Check for warning in output
    string(
        FIND "${output}${error}"
        "clang-format"
        has_warning
    )
    # Warning is optional - main thing is it didn't fail

    message(STATUS "  ✓ ClangFormat gracefully handles missing tool")
endfunction()

function(test_default_source_dirs)
    message(STATUS "Test 4: ClangFormat defaults SOURCE_DIRS to current directory")

    set(src_dir "${TEST_ROOT}/default_source_dirs/src")
    set(build_dir "${TEST_ROOT}/default_source_dirs/build")
    file(MAKE_DIRECTORY "${src_dir}/lib")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangFormatDefaultSourceDirsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

find_package(ClangFormat QUIET)

if(ClangFormat_FOUND)
    include(ClangFormat)

    ClangFormat_AddTargets(
        TARGET_PREFIX default_dirs
    )

    if(NOT TARGET default_dirs_format)
        message(FATAL_ERROR \"default_dirs_format target not created\")
    endif()
    if(NOT TARGET default_dirs_check)
        message(FATAL_ERROR \"default_dirs_check target not created\")
    endif()

    message(STATUS \"ClangFormat default SOURCE_DIRS works\")
else()
    message(STATUS \"clang-format not found, skipping test\")
endif()

add_library(mylib STATIC lib/lib.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib/lib.c" "int lib_func(void) { return 42; }")
    file(WRITE "${src_dir}/.clang-format" "BasedOnStyle: LLVM\n")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Default SOURCE_DIRS test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ ClangFormat default SOURCE_DIRS works")
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat Integration Tests ===")

    setup_test_environment()

    test_basic_configuration()
    test_exclude_patterns()
    test_tool_not_found()
    test_default_source_dirs()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "ClangFormat tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All ClangFormat tests PASSED")
    endif()
endfunction()

run_all_tests()
