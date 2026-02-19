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
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/compilecommands_basic_test")

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

function(test_trim_executes_and_filters_content)
    message(STATUS "Test 1: CompileCommands_Trim executes and filters expected flags")

    set(src_dir "${TEST_ROOT}/behavior/src")
    set(build_dir "${TEST_ROOT}/behavior/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsBehaviorTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"gcc -Iinclude -DFOO=1 -O2 -g -o lib.o -c src/lib.c\\\",\n    \\\"file\\\": \\\"src/lib.c\\\"\n  }\n]\")

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/db/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_custom_target(run_trim DEPENDS \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")

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
        message(STATUS "  - trimmed output file missing: ${trimmed_file}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${trimmed_file}" trimmed_content)
    if(NOT trimmed_content MATCHES "-DFOO=1")
        message(STATUS "  - expected define flag is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-Iinclude")
        message(STATUS "  - expected include flag is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-O2")
        message(STATUS "  - optimization flag should be removed by trimming")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-g")
        message(STATUS "  - debug flag should be removed by trimming")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "  - trim command executed and output content validated")
    endif()
endfunction()

function(test_trim_preserves_split_flags)
    message(STATUS "Test 2: CompileCommands_Trim preserves split-argument flags")

    set(src_dir "${TEST_ROOT}/split_flags/src")
    set(build_dir "${TEST_ROOT}/split_flags/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsSplitFlagsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"gcc -I include -isystem /sys -DFOO=1 -o lib.o -c src/lib.c\\\",\n    \\\"file\\\": \\\"src/lib.c\\\"\n  }\n]\")

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/db/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_custom_target(run_trim DEPENDS \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")

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
        message(STATUS "  - trimmed output file missing: ${trimmed_file}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${trimmed_file}" trimmed_content)
    if(NOT trimmed_content MATCHES "-DFOO=1")
        message(STATUS "  - expected define flag is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-I include")
        message(STATUS "  - expected split include flag is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-isystem /sys")
        message(STATUS "  - expected system include flag is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-o lib.o")
        message(STATUS "  - expected output flag is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "  - split-argument flags preserved")
    endif()
endfunction()

function(test_trim_handles_paths_with_spaces)
    message(STATUS "Test 3: CompileCommands_Trim handles paths with spaces")

    set(src_dir "${TEST_ROOT}/spaces/src")
    set(build_dir "${TEST_ROOT}/spaces/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsSpacesTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"gcc -I \\\\\\\"/path/with spaces/include\\\\\\\" -DFOO=1 -o lib.o -c src/lib.c\\\",\n    \\\"file\\\": \\\"src/lib.c\\\"\n  }\n]\")

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/db/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_custom_target(run_trim DEPENDS \${CMAKE_BINARY_DIR}/trimmed/compile_commands.json)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")

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
        message(STATUS "  - trimmed output file missing: ${trimmed_file}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    file(READ "${trimmed_file}" trimmed_content)
    if(NOT trimmed_content MATCHES "-DFOO=1")
        message(STATUS "  - expected define flag is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "\\\"/path/with spaces/include\\\\\\\"")
        message(STATUS "  - expected path with spaces is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-o lib.o")
        message(STATUS "  - expected output flag is missing in trimmed output")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "  - paths with spaces preserved correctly")
    endif()
endfunction()

function(test_trim_creates_output_directory)
    message(STATUS "Test 4: CompileCommands_Trim creates nested output directory at build time")

    set(src_dir "${TEST_ROOT}/create_dir/src")
    set(build_dir "${TEST_ROOT}/create_dir/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(CompileCommandsDirCreationTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(WRITE \"\${CMAKE_BINARY_DIR}/compile_commands.json\" \"[]\")

CompileCommands_Trim(
    INPUT \${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT \${CMAKE_BINARY_DIR}/nested/deep/path/trimmed.json
)

add_custom_target(run_trim DEPENDS \${CMAKE_BINARY_DIR}/nested/deep/path/trimmed.json)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")

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

    if(NOT EXISTS "${build_dir}/nested/deep/path/trimmed.json")
        message(STATUS "  - expected nested output file does not exist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  - nested output path is created and populated")
endfunction()

function(run_all_tests)
    message(STATUS "=== CompileCommands_Trim Basic Behavior Tests ===")

    setup_test_environment()

    test_trim_executes_and_filters_content()
    test_trim_preserves_split_flags()
    test_trim_handles_paths_with_spaces()
    test_trim_creates_output_directory()
    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "CompileCommands_Trim basic tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All CompileCommands_Trim basic tests PASSED")
    endif()
endfunction()

run_all_tests()
