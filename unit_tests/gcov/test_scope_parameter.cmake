if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

# Test: Gcov_AddToTarget SCOPE Parameter Validation
# Validates different SCOPE values (PUBLIC, PRIVATE, INTERFACE)

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)
include(TestHelpers)

set(ERROR_COUNT 0)
set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcov_scope_test")

function(setup_test_environment)
    message(STATUS "Setting up test environment in: ${TEST_ROOT}")
    file(REMOVE_RECURSE "${TEST_ROOT}")
    file(MAKE_DIRECTORY "${TEST_ROOT}")
    TestHelpers_CreateMockGcovr(mock_gcovr OUTPUT_DIR "${TEST_ROOT}/mock_gcovr")
    file(TO_CMAKE_PATH "${mock_gcovr}" mock_gcovr_path)
    set(GCOVR_MOCK_PATH "${mock_gcovr_path}" PARENT_SCOPE)
endfunction()

function(test_scope_variation SCOPE_VALUE)
    message(STATUS "  Testing SCOPE=${SCOPE_VALUE}")

    # Which target properties must (and must not) carry the coverage flags.
    if(SCOPE_VALUE STREQUAL "PUBLIC")
        set(OWN_PROPS "compile_opts iface_compile_opts link_opts iface_link_opts")
        set(EMPTY_PROPS "")
    elseif(SCOPE_VALUE STREQUAL "PRIVATE")
        set(OWN_PROPS "compile_opts link_opts")
        set(EMPTY_PROPS "iface_compile_opts iface_link_opts")
    else()
        set(OWN_PROPS "iface_compile_opts iface_link_opts")
        set(EMPTY_PROPS "compile_opts link_opts")
    endif()

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovScopeTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)
include(Gcov)

add_library(mylib STATIC dummy.c)
Gcov_AddToTarget(mylib ${SCOPE_VALUE})

get_target_property(compile_opts mylib COMPILE_OPTIONS)
get_target_property(iface_compile_opts mylib INTERFACE_COMPILE_OPTIONS)
get_target_property(link_opts mylib LINK_OPTIONS)
get_target_property(iface_link_opts mylib INTERFACE_LINK_OPTIONS)
message(STATUS \"SCOPE ${SCOPE_VALUE}: compile_opts=\${compile_opts} iface=\${iface_compile_opts}\")

# PUBLIC/PRIVATE instrument the target itself; PUBLIC/INTERFACE also export the
# flags to consumers. Assert --coverage lands exactly where the scope says.
foreach(prop ${OWN_PROPS})
    if(NOT \"\${\${prop}}\" MATCHES \"--coverage\")
        message(FATAL_ERROR \"SCOPE ${SCOPE_VALUE}: \${prop} must contain --coverage (got \${\${prop}})\")
    endif()
endforeach()
foreach(prop ${EMPTY_PROPS})
    if(\"\${\${prop}}\" MATCHES \"--coverage\")
        message(FATAL_ERROR \"SCOPE ${SCOPE_VALUE}: \${prop} must not contain --coverage\")
    endif()
endforeach()
"
    )

    set(src_dir "${TEST_ROOT}/scope_${SCOPE_VALUE}/src")
    set(build_dir "${TEST_ROOT}/scope_${SCOPE_VALUE}/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/dummy.c" "int dummy(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "    ✗ SCOPE=${SCOPE_VALUE} failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "    ✓ SCOPE=${SCOPE_VALUE} succeeded")
endfunction()

function(test_all_scope_values)
    message(STATUS "Test 1: Valid SCOPE values are accepted")

    test_scope_variation(PUBLIC)
    test_scope_variation(PRIVATE)
    test_scope_variation(INTERFACE)
endfunction()

function(test_scope_propagation)
    message(STATUS "Test 2: SCOPE propagation to dependent targets")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovScopeTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)
include(Gcov)

# Base library with PUBLIC scope - flags should propagate to consumers
add_library(base_lib STATIC base.c)
Gcov_AddToTarget(base_lib PUBLIC)

# Consumer library links to base
add_library(consumer_lib STATIC consumer.c)
target_link_libraries(consumer_lib PUBLIC base_lib)

# Check that flags are exported to consumers through PUBLIC scope
get_target_property(exported base_lib INTERFACE_COMPILE_OPTIONS)
if(NOT \"\${exported}\" MATCHES \"--coverage\")
    message(FATAL_ERROR \"PUBLIC scope must export --coverage to consumers (got \${exported})\")
endif()
message(STATUS \"Exported compile options: \${exported}\")
"
    )

    set(src_dir "${TEST_ROOT}/scope_propagation/src")
    set(build_dir "${TEST_ROOT}/scope_propagation/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/base.c" "int base_func(void) { return 1; }")
    file(
        WRITE "${src_dir}/consumer.c"
        "extern int base_func(void); int consumer_func(void) { return base_func(); }"
    )

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ SCOPE propagation test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ SCOPE propagation works correctly")
endfunction()

function(test_interface_library)
    message(STATUS "Test 3: INTERFACE library with INTERFACE scope")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovInterfaceTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)
include(Gcov)

# Interface library with INTERFACE scope
add_library(iface_lib INTERFACE)
Gcov_AddToTarget(iface_lib INTERFACE)

# Regular library consumes interface
add_library(consumer STATIC consumer.c)
target_link_libraries(consumer PRIVATE iface_lib)

message(STATUS \"Interface library with INTERFACE scope configured successfully\")
"
    )

    set(src_dir "${TEST_ROOT}/interface_lib/src")
    set(build_dir "${TEST_ROOT}/interface_lib/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/consumer.c" "int consumer_func(void) { return 42; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ INTERFACE library test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ INTERFACE library with INTERFACE scope works")
endfunction()

function(test_executable_target)
    message(STATUS "Test 4: Executable target with PRIVATE scope")

    set(test_script
        "
cmake_minimum_required(VERSION 3.22)
project(GcovExeTest LANGUAGES C)
set(CMAKE_MODULE_PATH \"${REPO_ROOT}/cmake\")
set(CMT_GCOVR_EXECUTABLE \"${GCOVR_MOCK_PATH}\" CACHE FILEPATH \"\" FORCE)
include(Gcov)

add_executable(myexe main.c)
Gcov_AddToTarget(myexe PRIVATE)

message(STATUS \"Executable with coverage flags configured\")
"
    )

    set(src_dir "${TEST_ROOT}/executable/src")
    set(build_dir "${TEST_ROOT}/executable/build")
    file(MAKE_DIRECTORY "${src_dir}")
    file(WRITE "${src_dir}/CMakeLists.txt" "${test_script}")
    file(WRITE "${src_dir}/main.c" "int main(void) { return 0; }")

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${src_dir}" -B "${build_dir}"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    if(NOT result EQUAL 0)
        message(STATUS "  ✗ Executable target test failed: ${error}")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
        return()
    endif()

    message(STATUS "  ✓ Executable target with PRIVATE scope works")
endfunction()

function(run_all_tests)
    message(STATUS "=== Gcov_AddToTarget SCOPE Parameter Tests ===")

    setup_test_environment()

    test_all_scope_values()
    test_scope_propagation()
    test_interface_library()
    test_executable_target()

    message(STATUS "")
    if(ERROR_COUNT GREATER 0)
        message(FATAL_ERROR "Gcov SCOPE parameter tests failed with ${ERROR_COUNT} error(s)")
    else()
        message(STATUS "All Gcov SCOPE parameter tests PASSED")
    endif()
endfunction()

run_all_tests()
