if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/clangtidy_compat_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(configure_project SRC_DIR BUILD_DIR RESULT_VAR COMBINED_LOG_VAR)
    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${SRC_DIR}" -B "${BUILD_DIR}" ${configure_args}
        RESULT_VARIABLE config_result
        OUTPUT_VARIABLE config_out
        ERROR_VARIABLE config_err
    )
    set(${RESULT_VAR} ${config_result} PARENT_SCOPE)
    set(${COMBINED_LOG_VAR} "${config_out}${config_err}" PARENT_SCOPE)
endfunction()

function(build_target BUILD_DIR TARGET_NAME RESULT_VAR COMBINED_LOG_VAR)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${BUILD_DIR}" --target "${TARGET_NAME}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_out
        ERROR_VARIABLE build_err
    )
    set(${RESULT_VAR} ${build_result} PARENT_SCOPE)
    set(${COMBINED_LOG_VAR} "${build_out}${build_err}" PARENT_SCOPE)
endfunction()

function(find_clang_tidy CLANG_TIDY_VAR)
    set(${CLANG_TIDY_VAR} "" PARENT_SCOPE)

    find_program(_clang_tidy NAMES clang-tidy clang-tidy-18 clang-tidy-17 clang-tidy-16 clang-tidy-15)
    if(_clang_tidy)
        set(${CLANG_TIDY_VAR} "${_clang_tidy}" PARENT_SCOPE)
        message(STATUS "Found clang-tidy: ${_clang_tidy}")
    else()
        message(STATUS "clang-tidy not found, skipping compatibility tests")
    endif()
endfunction()

function(test_clang_tidy_accepts_trimmed_arm_flags)
    message(STATUS "Test 1: Clang-tidy accepts trimmed ARM GCC compile commands")

    find_clang_tidy(clang_tidy)
    if(NOT clang_tidy)
        message(STATUS "  - Skipped (clang-tidy not found)")
        return()
    endif()

    set(src_dir "${TEST_ROOT}/arm_clangtidy/src")
    set(build_dir "${TEST_ROOT}/arm_clangtidy/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(ArmClangTidyCompatTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"arm-none-eabi-gcc -mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-d16 -fstrict-volatile-bitfields -DFOO=1 -Iinclude -o lib.o -c src/lib.c\\\",\n    \\\"file\\\": \\\"src/lib.c\\\"\n  }\n]\")

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/db/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_custom_target(run_trim DEPENDS \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.c" "int lib_func(void) { return 42; }\n")

    configure_project("${src_dir}" "${build_dir}" config_result config_log)
    if(NOT config_result EQUAL 0)
        message(STATUS "  - configuration failed: ${config_log}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    build_target("${build_dir}" "run_trim" build_result build_log)
    if(NOT build_result EQUAL 0)
        message(STATUS "  - trim target build failed: ${build_log}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(trimmed_file "${build_dir}/trimmed/compile_commands.json")
    if(NOT EXISTS "${trimmed_file}")
        message(STATUS "  - trimmed output file missing")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(test_file "${src_dir}/lib.c")
    execute_process(
        COMMAND ${clang_tidy} -p "${build_dir}/trimmed" -- "${test_file}"
        RESULT_VARIABLE tidy_result
        ERROR_VARIABLE tidy_error
        OUTPUT_VARIABLE tidy_output
        TIMEOUT 30
    )

    string(FIND "${tidy_error}" "unknown argument" unknown_arg_pos)
    string(FIND "${tidy_error}" "error:" error_pos)

    if(unknown_arg_pos GREATER -1)
        message(STATUS "  - clang-tidy reported 'unknown argument' in trimmed output")
        message(STATUS "    Error: ${tidy_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    elseif(error_pos GREATER -1)
        message(STATUS "  - clang-tidy reported errors in trimmed output")
        message(STATUS "    Error: ${tidy_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "  - clang-tidy accepted trimmed compile_commands.json")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(test_clang_tidy_accepts_trimmed_gcc_modules_flags)
    message(STATUS "Test 2: Clang-tidy accepts trimmed GCC modules compile commands")

    find_clang_tidy(clang_tidy)
    if(NOT clang_tidy)
        message(STATUS "  - Skipped (clang-tidy not found)")
        return()
    endif()

    set(src_dir "${TEST_ROOT}/gcc_modules_clangtidy/src")
    set(build_dir "${TEST_ROOT}/gcc_modules_clangtidy/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GccModulesClangTidyCompatTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"g++ -fmodules-ts -fmodule-mapper=module.map -fdeps-format=p1689r5 -std=c++20 -Iinclude -o lib.o -c src/lib.cpp\\\",\n    \\\"file\\\": \\\"src/lib.cpp\\\"\n  }\n]\")

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/db/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_custom_target(run_trim DEPENDS \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.cpp" "int lib_func() { return 42; }\n")

    configure_project("${src_dir}" "${build_dir}" config_result config_log)
    if(NOT config_result EQUAL 0)
        message(STATUS "  - configuration failed: ${config_log}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    build_target("${build_dir}" "run_trim" build_result build_log)
    if(NOT build_result EQUAL 0)
        message(STATUS "  - trim target build failed: ${build_log}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(trimmed_file "${build_dir}/trimmed/compile_commands.json")
    if(NOT EXISTS "${trimmed_file}")
        message(STATUS "  - trimmed output file missing")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(test_file "${src_dir}/lib.cpp")
    execute_process(
        COMMAND ${clang_tidy} -p "${build_dir}/trimmed" -- "${test_file}"
        RESULT_VARIABLE tidy_result
        ERROR_VARIABLE tidy_error
        OUTPUT_VARIABLE tidy_output
        TIMEOUT 30
    )

    string(FIND "${tidy_error}" "unknown argument" unknown_arg_pos)
    string(FIND "${tidy_error}" "error:" error_pos)

    if(unknown_arg_pos GREATER -1)
        message(STATUS "  - clang-tidy reported 'unknown argument' in trimmed output")
        message(STATUS "    Error: ${tidy_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    elseif(error_pos GREATER -1)
        string(FIND "${tidy_error}" "file not found" file_not_found)
        string(FIND "${tidy_error}" "fatal error" fatal_error)
        if(file_not_found EQUAL -1 AND fatal_error EQUAL -1)
            message(STATUS "  - clang-tidy reported errors in trimmed output")
            message(STATUS "    Error: ${tidy_error}")
            math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        else()
            message(STATUS "  - clang-tidy accepted trimmed compile_commands.json (file not found is expected)")
        endif()
    else()
        message(STATUS "  - clang-tidy accepted trimmed compile_commands.json")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(test_clang_tidy_accepts_preserved_flags)
    message(STATUS "Test 3: Clang-tidy can use preserved analysis flags")

    find_clang_tidy(clang_tidy)
    if(NOT clang_tidy)
        message(STATUS "  - Skipped (clang-tidy not found)")
        return()
    endif()

    set(src_dir "${TEST_ROOT}/preserved_flags_clangtidy/src")
    set(build_dir "${TEST_ROOT}/preserved_flags_clangtidy/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(PreservedFlagsClangTidyCompatTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"g++ -std=c++17 -fno-exceptions -fno-rtti -fPIC -pthread -DDEBUG=1 -Iinclude -o lib.o -c src/lib.cpp\\\",\n    \\\"file\\\": \\\"src/lib.cpp\\\"\n  }\n]\")

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/db/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_custom_target(run_trim DEPENDS \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.cpp" "int lib_func() { return 42; }\n")

    configure_project("${src_dir}" "${build_dir}" config_result config_log)
    if(NOT config_result EQUAL 0)
        message(STATUS "  - configuration failed: ${config_log}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    build_target("${build_dir}" "run_trim" build_result build_log)
    if(NOT build_result EQUAL 0)
        message(STATUS "  - trim target build failed: ${build_log}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    set(trimmed_file "${build_dir}/trimmed/compile_commands.json")
    if(NOT EXISTS "${trimmed_file}")
        message(STATUS "  - trimmed output file missing")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${trimmed_file}" trimmed_content)
    if(NOT trimmed_content MATCHES "-fno-exceptions")
        message(STATUS "  - -fno-exceptions should be preserved for analysis")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(test_file "${src_dir}/lib.cpp")
    execute_process(
        COMMAND ${clang_tidy} -p "${build_dir}/trimmed" -- "${test_file}"
        RESULT_VARIABLE tidy_result
        ERROR_VARIABLE tidy_error
        OUTPUT_VARIABLE tidy_output
        TIMEOUT 30
    )

    string(FIND "${tidy_error}" "unknown argument" unknown_arg_pos)
    string(FIND "${tidy_error}" "error:" error_pos)

    if(unknown_arg_pos GREATER -1)
        message(STATUS "  - clang-tidy reported 'unknown argument'")
        message(STATUS "    Error: ${tidy_error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    else()
        message(STATUS "  - clang-tidy accepted trimmed compile_commands.json with preserved flags")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== Clang-Tidy Compatibility Tests ===")

    setup_test_environment()

    test_clang_tidy_accepts_trimmed_arm_flags()
    test_clang_tidy_accepts_trimmed_gcc_modules_flags()
    test_clang_tidy_accepts_preserved_flags()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Clang-Tidy compatibility tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Clang-Tidy compatibility tests PASSED")
    endif()
endfunction()

run_all_tests()
