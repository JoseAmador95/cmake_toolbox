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
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/compilecommands_blacklist_test")

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

function(test_blacklist_removes_arm_flags)
    message(STATUS "Test 1: Blacklist removes ARM-specific flags")

    set(src_dir "${TEST_ROOT}/arm_flags/src")
    set(build_dir "${TEST_ROOT}/arm_flags/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(BlacklistArmFlagsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"arm-none-eabi-gcc -mcpu=cortex-m7 -mthumb -mfloat-abi=hard -mfpu=fpv5-d16 -DFOO=1 -Iinclude -o lib.o -c src/lib.c\\\",\n    \\\"file\\\": \\\"src/lib.c\\\"\n  }\n]\")

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

    if(trimmed_content MATCHES "-mcpu=cortex-m7")
        message(STATUS "  - ARM -mcpu flag should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-mthumb")
        message(STATUS "  - ARM -mthumb flag should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-mfloat-abi=hard")
        message(STATUS "  - ARM -mfloat-abi flag should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-mfpu=fpv5-d16")
        message(STATUS "  - ARM -mfpu flag should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-DFOO=1")
        message(STATUS "  - Define flag -DFOO=1 should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-Iinclude")
        message(STATUS "  - Include flag -Iinclude should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "  - ARM-specific flags correctly filtered by blacklist")
    endif()
endfunction()

function(test_blacklist_removes_gcc_modules_flags)
    message(STATUS "Test 2: Blacklist removes GCC modules flags")

    set(src_dir "${TEST_ROOT}/gcc_modules/src")
    set(build_dir "${TEST_ROOT}/gcc_module/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(BlacklistGccModulesTest LANGUAGES CXX)
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

    if(trimmed_content MATCHES "-fmodules-ts")
        message(STATUS "  - GCC -fmodules-ts flag should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-fmodule-mapper")
        message(STATUS "  - GCC -fmodule-mapper flag should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-fdeps-format")
        message(STATUS "  - GCC -fdeps-format flag should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-std=c\\+\\+20")
        message(STATUS "  - Standard flag -std=c++20 should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "  - GCC modules flags correctly filtered by blacklist")
    endif()
endfunction()

function(test_blacklist_removes_gcc_warnings)
    message(STATUS "Test 3: Blacklist removes GCC-specific warning flags")

    set(src_dir "${TEST_ROOT}/gcc_warnings/src")
    set(build_dir "${TEST_ROOT}/gcc_warnings/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(BlacklistGccWarningsTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"gcc -Wformat-signedness -Wsuggest-override -Wduplicated-cond -Wduplicated-branches -Wlogical-op -Wuseless-cast -DFOO=1 -o lib.o -c src/lib.c\\\",\n    \\\"file\\\": \\\"src/lib.c\\\"\n  }\n]\")

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

    if(trimmed_content MATCHES "-Wformat-signedness")
        message(STATUS "  - GCC -Wformat-signedness should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-Wsuggest-override")
        message(STATUS "  - GCC -Wsuggest-override should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-Wduplicated-cond")
        message(STATUS "  - GCC -Wduplicated-cond should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-Wlogical-op")
        message(STATUS "  - GCC -Wlogical-op should be removed by blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-DFOO=1")
        message(STATUS "  - Define flag -DFOO=1 should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "  - GCC warning flags correctly filtered by blacklist")
    endif()
endfunction()

function(test_user_blacklist_adds_patterns)
    message(STATUS "Test 4: User can add custom blacklist patterns")

    set(src_dir "${TEST_ROOT}/user_blacklist/src")
    set(build_dir "${TEST_ROOT}/user_blacklist/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(UserBlacklistTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

set(COMPILE_COMMANDS_TRIM_BLACKLIST \"^-Wmy-custom-warning$;^-fmy-custom-flag\")

include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"gcc -Wmy-custom-warning -fmy-custom-flag -DFOO=1 -Iinclude -o lib.o -c src/lib.c\\\",\n    \\\"file\\\": \\\"src/lib.c\\\"\n  }\n]\")

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

    if(trimmed_content MATCHES "-Wmy-custom-warning")
        message(STATUS "  - Custom -Wmy-custom-warning should be removed by user blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(trimmed_content MATCHES "-fmy-custom-flag")
        message(STATUS "  - Custom -fmy-custom-flag should be removed by user blacklist")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-DFOO=1")
        message(STATUS "  - Define flag -DFOO=1 should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "  - User blacklist patterns correctly applied")
    endif()
endfunction()

function(test_preserves_safe_flags)
    message(STATUS "Test 5: Safe flags are preserved")

    set(src_dir "${TEST_ROOT}/safe_flags/src")
    set(build_dir "${TEST_ROOT}/safe_flags/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(SafeFlagsTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
include(CompileCommands)

file(MAKE_DIRECTORY \"\${CMAKE_BINARY_DIR}/db\")
file(WRITE \"\${CMAKE_BINARY_DIR}/db/compile_commands.json\"
\"[\n  {\n    \\\"directory\\\": \\\"/tmp/build\\\",\n    \\\"command\\\": \\\"g++ -std=c++17 -fno-exceptions -fno-rtti -fPIC -pthread -DDEBUG=1 -Iinclude -isystem/sys -x c++ -o lib.o -c src/lib.cpp\\\",\n    \\\"file\\\": \\\"src/lib.cpp\\\"\n  }\n]\")

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

    if(NOT trimmed_content MATCHES "-std=c\\+\\+17")
        message(STATUS "  - Standard flag -std=c++17 should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-fno-exceptions")
        message(STATUS "  - Feature flag -fno-exceptions should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-fno-rtti")
        message(STATUS "  - Feature flag -fno-rtti should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-fPIC")
        message(STATUS "  - Position-independent flag -fPIC should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-pthread")
        message(STATUS "  - Threading flag -pthread should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()
    if(NOT trimmed_content MATCHES "-DDEBUG=1")
        message(STATUS "  - Define flag -DDEBUG=1 should be preserved")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
    endif()

    set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "  - Safe flags correctly preserved")
    endif()
endfunction()

function(run_all_tests)
    message(STATUS "=== CompileCommands_Trim Blacklist Tests ===")

    setup_test_environment()

    test_blacklist_removes_arm_flags()
    test_blacklist_removes_gcc_modules_flags()
    test_blacklist_removes_gcc_warnings()
    test_user_blacklist_adds_patterns()
    test_preserves_safe_flags()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Blacklist tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All CompileCommands_Trim blacklist tests PASSED")
    endif()
endfunction()

run_all_tests()
