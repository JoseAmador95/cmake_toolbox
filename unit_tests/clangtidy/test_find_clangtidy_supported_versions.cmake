# Test: FindClangTidy supported versions
# Verifies discovery and priority for clang-tidy 10..22.

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(TEST_ROOT "${CMAKE_BINARY_DIR}/findclangtidy_supported_versions")

function(setup_test_environment)
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(write_fake_clang_tidy DIR NAME VERSION)
    set(path "${DIR}/${NAME}")
    file(
        WRITE "${path}"
        "#!/bin/sh\nif [ \"$1\" = \"--version\" ]; then\n  echo \"Ubuntu LLVM version ${VERSION}\"\nelse\n  echo \"fake ${NAME}\"\nfi\n"
    )
    file(
        CHMOD
        "${path}"
        PERMISSIONS
            OWNER_READ
            OWNER_WRITE
            OWNER_EXECUTE
            GROUP_READ
            GROUP_EXECUTE
            WORLD_READ
            WORLD_EXECUTE
    )
endfunction()

function(
    run_case
    CASE_NAME
    BIN_DIR
    EXPECT_FOUND
    EXPECT_EXEC
    EXPECT_VERSION_PREFIX
)
    set(check_script "${TEST_ROOT}/${CASE_NAME}_check.cmake")

    set(script
        "
cmake_minimum_required(VERSION 3.22)
set(ENV{PATH} \"${BIN_DIR}\")
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
find_package(ClangTidy QUIET)

if(${EXPECT_FOUND})
    if(NOT ClangTidy_FOUND)
        message(FATAL_ERROR \"${CASE_NAME}: expected ClangTidy_FOUND=TRUE\")
    endif()

    get_filename_component(found_name \"\${ClangTidy_EXECUTABLE}\" NAME)
    if(NOT found_name STREQUAL \"${EXPECT_EXEC}\")
        message(FATAL_ERROR \"${CASE_NAME}: expected executable '${EXPECT_EXEC}', got '\${found_name}'\")
    endif()

    if(NOT ClangTidy_VERSION MATCHES \"^${EXPECT_VERSION_PREFIX}\\.\")
        message(FATAL_ERROR \"${CASE_NAME}: expected version '${EXPECT_VERSION_PREFIX}.x', got '\${ClangTidy_VERSION}'\")
    endif()
else()
    if(ClangTidy_FOUND)
        message(FATAL_ERROR \"${CASE_NAME}: expected ClangTidy_FOUND=FALSE, got '\${ClangTidy_EXECUTABLE}'\")
    endif()
endif()

message(STATUS \"${CASE_NAME}: passed\")
"
    )

    file(WRITE "${check_script}" "${script}")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -P "${check_script}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "${CASE_NAME} stdout:\n${output}")
        message(FATAL_ERROR "${CASE_NAME} failed:\n${error}")
    endif()
endfunction()

function(run_all_tests)
    setup_test_environment()

    set(case1_dir "${TEST_ROOT}/case_10_and_22")
    file(MAKE_DIRECTORY "${case1_dir}")
    write_fake_clang_tidy("${case1_dir}" "clang-tidy-10" "10.0.1")
    write_fake_clang_tidy("${case1_dir}" "clang-tidy-22" "22.1.0")
    run_case("case_10_and_22" "${case1_dir}" TRUE "clang-tidy-22" "22")

    set(case2_dir "${TEST_ROOT}/case_only_10")
    file(MAKE_DIRECTORY "${case2_dir}")
    write_fake_clang_tidy("${case2_dir}" "clang-tidy-10" "10.0.1")
    run_case("case_only_10" "${case2_dir}" TRUE "clang-tidy-10" "10")

    set(case3_dir "${TEST_ROOT}/case_only_9")
    file(MAKE_DIRECTORY "${case3_dir}")
    write_fake_clang_tidy("${case3_dir}" "clang-tidy-9" "9.0.1")
    run_case("case_only_9" "${case3_dir}" FALSE "" "")
endfunction()

run_all_tests()
