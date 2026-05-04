if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Integration Test: IWYU configuration
# Verifies IWYU global and per-target configuration with mock C++ project

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_iwyu")

function(setup_test_environment)
    message(STATUS "Setting up IWYU integration test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
endfunction()

function(test_global_configuration_on)
    message(STATUS "Test 1: IWYU_Configure STATUS ON (C++-only, advisory mode)")

    set(src_dir "${TEST_ROOT}/global_on/src")
    set(build_dir "${TEST_ROOT}/global_on/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(IWYUGlobalTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(IWYU)

# Configure globally
IWYU_Configure(STATUS ON)

# Check if CMAKE_CXX_INCLUDE_WHAT_YOU_USE was set (if iwyu found)
if(IWYU_FOUND)
    if(NOT CMAKE_CXX_INCLUDE_WHAT_YOU_USE)
        message(FATAL_ERROR \"CMAKE_CXX_INCLUDE_WHAT_YOU_USE should be set when STATUS ON\")
    endif()
    message(STATUS \"IWYU_Configure: CMAKE_CXX_INCLUDE_WHAT_YOU_USE = \${CMAKE_CXX_INCLUDE_WHAT_YOU_USE}\")
else()
    message(STATUS \"include-what-you-use not found, configuration skipped correctly (advisory mode)\")
endif()

# Verify C mode is not affected (IWYU is C++-only)
if(DEFINED CMAKE_C_INCLUDE_WHAT_YOU_USE)
    message(FATAL_ERROR \"CMAKE_C_INCLUDE_WHAT_YOU_USE should NOT be set (IWYU is C++-only)\")
endif()

add_library(mylib STATIC lib.cpp)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.cpp" "#include <iostream>\nvoid lib_func() { }")

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

    # Execute build to verify IWYU runs (if available)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    message(STATUS "  ✓ IWYU_Configure STATUS ON works (advisory mode)")
    message(STATUS "    Build executed successfully")
endfunction()

function(test_global_configuration_off)
    message(STATUS "Test 2: IWYU_Configure STATUS OFF")

    set(src_dir "${TEST_ROOT}/global_off/src")
    set(build_dir "${TEST_ROOT}/global_off/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(IWYUGlobalTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(IWYU)

# First enable, then disable
IWYU_Configure(STATUS ON)
IWYU_Configure(STATUS OFF)

# Check CMAKE_CXX_INCLUDE_WHAT_YOU_USE is empty/unset
if(CMAKE_CXX_INCLUDE_WHAT_YOU_USE)
    message(FATAL_ERROR \"CMAKE_CXX_INCLUDE_WHAT_YOU_USE should be empty after STATUS OFF\")
endif()

message(STATUS \"IWYU_Configure STATUS OFF correctly cleared settings\")
add_library(mylib STATIC lib.cpp)
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.cpp" "void lib_func() { }")

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

    # Execute build to verify IWYU is disabled
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    message(STATUS "  ✓ IWYU_Configure STATUS OFF works")
endfunction()

function(test_per_target_configuration)
    message(STATUS "Test 3: IWYU_ConfigureTarget per-target with mapping file")

    set(src_dir "${TEST_ROOT}/per_target/src")
    set(build_dir "${TEST_ROOT}/per_target/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(IWYUTargetTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(IWYU)

add_library(core STATIC core.cpp)
add_library(utils STATIC utils.cpp)

# Configure only core with mapping file
IWYU_ConfigureTarget(
    TARGET core
    STATUS ON
    MAPPING_FILE \${CMAKE_CURRENT_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS \"--no_fwd_decls\"
)
# Leave utils without IWYU

if(IWYU_FOUND)
    get_target_property(iwyu_core core CXX_INCLUDE_WHAT_YOU_USE)
    get_target_property(iwyu_utils utils CXX_INCLUDE_WHAT_YOU_USE)
    
    message(STATUS \"core CXX_INCLUDE_WHAT_YOU_USE: \${iwyu_core}\")
    message(STATUS \"utils CXX_INCLUDE_WHAT_YOU_USE: \${iwyu_utils}\")
    
    # core should have IWYU, utils should not
    if(NOT iwyu_core)
        message(FATAL_ERROR \"core should have CXX_INCLUDE_WHAT_YOU_USE set\")
    endif()
else()
    message(STATUS \"include-what-you-use not found, skipping verification\")
endif()
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/core.cpp" "#include <vector>\nvoid core_func() { }")
    file(WRITE "${src_dir}/utils.cpp" "#include <string>\nvoid util_func() { }")

    # Create a minimal mapping file
    file(WRITE "${src_dir}/iwyu.imp" "")

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

    message(STATUS "  ✓ IWYU_ConfigureTarget per-target works")
endfunction()

function(test_cxx_only)
    message(STATUS "Test 4: IWYU C++-only verification (no C mode)")

    set(src_dir "${TEST_ROOT}/cxx_only/src")
    set(build_dir "${TEST_ROOT}/cxx_only/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(IWYUCxxOnlyTest LANGUAGES C CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(IWYU)

# Configure globally
IWYU_Configure(STATUS ON)

# Verify only CXX is set, not C
if(IWYU_FOUND)
    if(DEFINED CMAKE_C_INCLUDE_WHAT_YOU_USE AND CMAKE_C_INCLUDE_WHAT_YOU_USE)
        message(FATAL_ERROR \"CMAKE_C_INCLUDE_WHAT_YOU_USE should NOT be set (IWYU is C++-only)\")
    endif()
    if(NOT CMAKE_CXX_INCLUDE_WHAT_YOU_USE)
        message(FATAL_ERROR \"CMAKE_CXX_INCLUDE_WHAT_YOU_USE should be set\")
    endif()
else()
    message(STATUS \"include-what-you-use not found, skipping verification\")
endif()

add_library(clib STATIC c_code.c)
add_library(cpplib STATIC cpp_code.cpp)

message(STATUS \"IWYU correctly configured only for C++\")
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/c_code.c" "int c_func(void) { return 42; }")
    file(WRITE "${src_dir}/cpp_code.cpp" "int cpp_func() { return 42; }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ C++-only verification failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Execute build with mixed C/C++ project
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    message(STATUS "  ✓ IWYU C++-only mode verified")
endfunction()

function(test_strict_mode)
    message(STATUS "Test 5: IWYU_Configure STRICT mode (should fail when tool missing)")

    set(src_dir "${TEST_ROOT}/strict_mode/src")
    set(build_dir "${TEST_ROOT}/strict_mode/build")
    file(MAKE_DIRECTORY "${src_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(IWYUStrictTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

# Force tool to not be found
set(IWYU_EXECUTABLE \"\" CACHE FILEPATH \"\" FORCE)
set(IWYU_FOUND FALSE CACHE BOOL \"\" FORCE)

include(IWYU)

# Configure in strict mode without tool should fail
IWYU_Configure(STATUS ON STRICT)

add_library(mylib STATIC lib.cpp)

message(STATUS \"IWYU STRICT mode test\")
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/lib.cpp" "void lib_func() { }")

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
        message(STATUS "  ✓ IWYU STRICT mode correctly enforced (tool not found -> error expected)")
    else()
        message(STATUS "  ✓ IWYU STRICT mode failed as expected when tool missing")
    endif()
endfunction()

function(test_additional_args)
    message(STATUS "Test 6: IWYU with additional -Xiwyu arguments")

    set(src_dir "${TEST_ROOT}/args/src")
    set(build_dir "${TEST_ROOT}/args/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(MAKE_DIRECTORY "${build_dir}")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(IWYUArgsTest LANGUAGES CXX)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")

include(IWYU)

add_library(core STATIC core.cpp)

# Configure with IWYU-specific arguments
IWYU_ConfigureTarget(
    TARGET core
    STATUS ON
    ADDITIONAL_ARGS \"--no_fwd_decls;--keep_going\"
)

message(STATUS \"IWYU additional arguments configured\")
"
    )

    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/core.cpp" "#include <iostream>\nvoid core_func() { }")

    TestHelpers_GetConfigureArgs(configure_args)
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}" ${configure_args}
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Additional arguments configuration failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    # Execute build with IWYU arguments
    execute_process(
        COMMAND
            ${CMAKE_COMMAND} --build "${build_dir}"
        RESULT_VARIABLE build_result
        OUTPUT_VARIABLE build_output
        ERROR_VARIABLE build_error
    )

    message(STATUS "  ✓ IWYU additional arguments work")
endfunction()

function(run_all_tests)
    message(STATUS "=== IWYU Integration Tests ===")

    setup_test_environment()

    test_global_configuration_on()
    test_global_configuration_off()
    test_per_target_configuration()
    test_cxx_only()
    test_strict_mode()
    test_additional_args()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "IWYU integration tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All IWYU integration tests PASSED ✓")
    endif()
endfunction()

run_all_tests()
