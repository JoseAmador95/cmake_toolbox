if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
endif()

# Integration Test: ClangFormat configuration
# Verifies target generation and discovered file sets

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_clangformat")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_basic_configuration)
    message(STATUS "Test 1: Basic SOURCE_DIRS creates targets and expected file set")

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

    ClangFormat_CollectFiles(
        collected_files
        SOURCE_DIRS lib
    )
    list(LENGTH collected_files collected_count)
    if(NOT collected_count EQUAL 1)
        message(FATAL_ERROR "
        Expected
        exactly
        1
        discovered
        file
        in
        lib/,
        got
        \${collected_count}")
    endif()
    list(GET collected_files 0 only_file)
    if(NOT only_file MATCHES "lib/lib.c$")
        message(FATAL_ERROR "Unexpected
        discovered
        file:
        \${only_file}")
    endif()

    ClangFormat_AddTargets(
        TARGET_PREFIX myproject
        SOURCE_DIRS lib
    )

    if(NOT TARGET myproject_format)
        message(FATAL_ERROR "myproject_format
        target
        not
        created")
    endif()
    if(NOT TARGET myproject_check)
        message(FATAL_ERROR "myproject_check
        target
        not
        created")
    endif()
else()
    message(STATUS "clang-format
        not
        found,
        skipping
        test")
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
        message(STATUS "  - Basic configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  - Basic ClangFormat configuration assertions passed")
endfunction()

function(test_exclude_patterns)
    message(STATUS "Test 2: EXCLUDE_PATTERNS excludes generated files")

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

    ClangFormat_CollectFiles(
        collected_files
        SOURCE_DIRS
            \${CMAKE_CURRENT_SOURCE_DIR}/lib
            \${CMAKE_CURRENT_SOURCE_DIR}/generated
        EXCLUDE_PATTERNS "
        generated/.*"
    )

    list(LENGTH collected_files collected_count)
    if(NOT collected_count EQUAL 1)
        message(FATAL_ERROR "Expected
        1
        file
        after
        exclusion,
        got
        \${collected_count}")
    endif()
    list(GET collected_files 0 included_file)
    if(NOT included_file MATCHES "lib/lib.c$")
        message(FATAL_ERROR "Unexpected
        included
        file
        after
        exclusion:
        \${included_file}")
    endif()

    ClangFormat_AddTargets(
        TARGET_PREFIX myproject
        SOURCE_DIRS
            \${CMAKE_CURRENT_SOURCE_DIR}/lib
            \${CMAKE_CURRENT_SOURCE_DIR}/generated
        EXCLUDE_PATTERNS "generated/.*"
    )

    if(NOT TARGET myproject_check OR NOT TARGET myproject_format)
        message(FATAL_ERROR "Expected
        format/check
        targets
        were
        not
        created")
    endif()
else()
    message(STATUS "clang-format
        not
        found,
        skipping
        test")
endif()

add_library(mylib STATIC lib/lib.c generated/gen.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib/lib.c" "int lib_func(void) { return 42; }")
    file(WRITE "${src_dir}/generated/gen.c" "int gen_func(void){return 1;}")
    file(WRITE "${src_dir}/.clang-format" "BasedOnStyle: LLVM\n")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  - Exclude patterns test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  - Exclusion and target assertions passed")
endfunction()

function(test_tool_not_found)
    message(STATUS "Test 3: Missing clang-format does not create targets")

    set(src_dir "${TEST_ROOT}/no_tool/src")
    set(build_dir "${TEST_ROOT}/no_tool/build")
    file(MAKE_DIRECTORY "${src_dir}/lib")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangFormatNoToolTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(ClangFormat_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)
set(ClangFormat_FOUND FALSE CACHE BOOL \"\" FORCE)

include(ClangFormat)

ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS \${CMAKE_CURRENT_SOURCE_DIR}/lib
)

if(TARGET myproject_format OR TARGET myproject_check)
    message(FATAL_ERROR "
        Targets
        should
        not
        be
        created
        when
        clang-format
        is
        missing")
endif()

add_library(mylib STATIC lib/lib.c)
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
        message(STATUS "  - Missing tool test should not fail: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  - Missing tool behavior validated")
endfunction()

function(test_default_source_dirs)
    message(STATUS "Test 4: Default SOURCE_DIRS discovers current source files")

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

    ClangFormat_CollectFiles(default_collected)
    list(LENGTH default_collected default_count)
    if(default_count LESS 1)
        message(FATAL_ERROR "
        Default
        SOURCE_DIRS
        should
        discover
        files
        in
        current
        source
        dir")
    endif()

    ClangFormat_AddTargets(
        TARGET_PREFIX default_dirs
    )

    if(NOT TARGET default_dirs_format)
        message(FATAL_ERROR "default_dirs_format
        target
        not
        created")
    endif()
    if(NOT TARGET default_dirs_check)
        message(FATAL_ERROR "default_dirs_check
        target
        not
        created")
    endif()
else()
    message(STATUS "clang-format
        not
        found,
        skipping
        test")
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
        message(STATUS "  - Default SOURCE_DIRS test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  - Default SOURCE_DIRS behavior validated")
endfunction()

function(test_relative_and_absolute_source_dirs)
    message(STATUS "Test 5: Relative and absolute SOURCE_DIRS discover the same files")

    set(src_dir "${TEST_ROOT}/relative_absolute/src")
    set(build_dir "${TEST_ROOT}/relative_absolute/build")
    file(MAKE_DIRECTORY "${src_dir}/lib")
    file(MAKE_DIRECTORY "${src_dir}/inc")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ClangFormatRelativeAbsolute LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

find_package(ClangFormat QUIET)

if(ClangFormat_FOUND)
    include(ClangFormat)

    ClangFormat_CollectFiles(relative_files SOURCE_DIRS lib inc)
    ClangFormat_CollectFiles(
        absolute_files
        SOURCE_DIRS
            \${CMAKE_CURRENT_SOURCE_DIR}/lib
            \${CMAKE_CURRENT_SOURCE_DIR}/inc
    )

    list(SORT relative_files)
    list(SORT absolute_files)
    if(NOT \"\${relative_files}\" STREQUAL \"\${absolute_files}\")
        message(FATAL_ERROR "
        Relative
        and
        absolute
        SOURCE_DIRS
        produced
        different
        file
        sets")
    endif()

    list(LENGTH relative_files files_count)
    if(NOT files_count EQUAL 2)
        message(FATAL_ERROR "Expected
        exactly
        2
        files
        from
        SOURCE_DIRS,
        got
        \${files_count}")
    endif()

    ClangFormat_AddTargets(
        TARGET_PREFIX relabs
        SOURCE_DIRS lib inc
    )

    if(NOT TARGET relabs_check OR NOT TARGET relabs_format)
        message(FATAL_ERROR "Expected
        relabs
        targets
        were
        not
        created")
    endif()
else()
    message(STATUS "clang-format
        not
        found,
        skipping
        test")
endif()

add_library(mylib STATIC lib/lib.c)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib/lib.c" "#include \"lib.h\"\nint lib_func(void) { return 42; }\n")
    file(WRITE "${src_dir}/inc/lib.h" "int lib_func(void);\n")
    file(WRITE "${src_dir}/.clang-format" "BasedOnStyle: LLVM\n")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  - Relative/absolute SOURCE_DIRS test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  - Relative and absolute SOURCE_DIRS behave consistently")
endfunction()

function(run_all_tests)
    message(STATUS "=== ClangFormat Integration Tests ===")

    setup_test_environment()

    test_basic_configuration()
    test_exclude_patterns()
    test_tool_not_found()
    test_default_source_dirs()
    test_relative_and_absolute_source_dirs()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "ClangFormat tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All ClangFormat tests PASSED")
    endif()
endfunction()

run_all_tests()
