include(Ceedling)
find_package(ClangFormat QUIET)
include(ClangTidy)
include(Policy)

add_library(example STATIC ${CMAKE_CURRENT_SOURCE_DIR}/source/example.c)
add_library(dependency INTERFACE)
target_include_directories(dependency INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(example PUBLIC dependency)

Ceedling_AddUnitTest(
    NAME example_test
    UNIT_TEST ${CMAKE_CURRENT_SOURCE_DIR}/unit_test/test_example.c
    TARGET example
    # MOCK_HEADERS are auto-detected from #include "mock_dependency.h" in test file
    ENABLE_SANITIZER
)

# Automatically add all policy unit tests to CTest
file(GLOB POLICY_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/policy/test_*.cmake")
foreach(test_file ${POLICY_TEST_FILES})
    # Extract the test name from the filename (test_<name>.cmake -> <name>)
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})

    # Add the test to CTest with name policy_<name>
    add_test(
        NAME policy_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()

# Automatically add all clang-format unit tests to CTest
file(GLOB CLANGFORMAT_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/clangformat/test_*.cmake")
foreach(test_file ${CLANGFORMAT_TEST_FILES})
    # Extract the test name from the filename (test_<n>.cmake -> <n>)
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})

    # Add the test to CTest with name clangformat_<n>
    add_test(
        NAME clangformat_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()

# Automatically add all FindUnity unit tests to CTest
file(GLOB FINDUNITY_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/findunity/test_*.cmake")
foreach(test_file ${FINDUNITY_TEST_FILES})
    # Extract the test name from the filename (test_<name>.cmake -> <name>)
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})

    # Add the test to CTest with name findunity_<name>
    add_test(
        NAME findunity_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()

# Automatically add all DiscoverTests unit tests to CTest
file(
    GLOB DISCOVER_TESTS_FILES
    "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/discover_tests/test_*.cmake"
)
foreach(test_file ${DISCOVER_TESTS_FILES})
    # Extract the test name from the filename (test_<name>.cmake -> <name>)
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})

    # Add the test to CTest with name discover_tests_<name>
    add_test(
        NAME discover_tests_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()

# Note: Unity module testing is not included in unit tests because:
# - Unity_Initialize() requires FetchContent (external dependencies)
# - Unity_GenerateMock(), Unity_GenerateRunner(), Unity_CreateTestTarget() all use
#   add_custom_command/add_executable which don't work in script mode (cmake -P)
# - These functions should be tested in integration tests within actual CMake projects
#
# The Unity module is designed for use in real CMake projects where:
# - FetchContent can download dependencies
# - add_custom_command can generate mocks and runners
# - add_executable can create test targets
#
# Unit testing these functions would require either:
# 1. External dependencies (defeating the purpose of unit tests)
# 2. Complex mocking that doesn't test real behavior
# 3. Running in project mode (not true unit testing)

# ==============================================================================
# GcovrSchema Module Unit Tests
# ==============================================================================

file(GLOB GCOVRSCHEMA_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/gcovrschema/test_*.cmake")
foreach(test_file ${GCOVRSCHEMA_TEST_FILES})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME gcovrschema_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()

# ==============================================================================
# CMockSchema Module Unit Tests
# ==============================================================================

file(GLOB CMOCKSCHEMA_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/cmockschema/test_*.cmake")
foreach(test_file ${CMOCKSCHEMA_TEST_FILES})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME cmockschema_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()

# ==============================================================================
# ClangTidy Module Unit Tests
# ==============================================================================

file(GLOB CLANGTIDY_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/clangtidy/test_*.cmake")
foreach(test_file ${CLANGTIDY_TEST_FILES})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME clangtidy_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()

# ==============================================================================
# CompileCommands Module Unit Tests
# ==============================================================================

set(_TOOLBOX_TEST_HELPER_ARGS
    -DCMAKE_TOOLBOX_TEST_GENERATOR=${CMAKE_GENERATOR}
    -DCMAKE_TOOLBOX_TEST_C_COMPILER=${CMAKE_C_COMPILER}
    -DCMAKE_TOOLBOX_TEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    -DCMAKE_TOOLBOX_TEST_BUILD_TYPE=${CMAKE_BUILD_TYPE}
)

get_property(_TOOLBOX_MULTI_CONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(NOT _TOOLBOX_MULTI_CONFIG)
    file(
        GLOB COMPILECOMMANDS_TEST_FILES
        "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/compilecommands/test_*.cmake"
    )
    foreach(test_file ${COMPILECOMMANDS_TEST_FILES})
        get_filename_component(test_filename ${test_file} NAME_WE)
        string(REGEX REPLACE "^test_" "" test_name ${test_filename})
        add_test(
            NAME compilecommands_${test_name}
            COMMAND
                ${CMAKE_COMMAND} ${_TOOLBOX_TEST_HELPER_ARGS} -P ${test_file}
        )
    endforeach()
else()
    message(STATUS "Skipping CompileCommands unit tests on multi-config generators")
endif()

# ==============================================================================
# Sanitizer Module Integration Tests
# ==============================================================================

# Test that Sanitizer module correctly applies compile and link options
add_test(
    NAME sanitizer_integration
    COMMAND
        ${CMAKE_COMMAND} -S ${CMAKE_CURRENT_LIST_DIR}/../unit_tests/sanitizer -B
        ${CMAKE_CURRENT_BINARY_DIR}/sanitizer_test -G "${CMAKE_GENERATOR}"
        -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
)

# Sanitizer Module Unit Tests (script mode)
file(GLOB SANITIZER_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/sanitizer/test_*.cmake")
foreach(test_file ${SANITIZER_TEST_FILES})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME sanitizer_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()

# ==============================================================================
# Gcov Module Integration Tests
# ==============================================================================

set(_TOOLBOX_GCOV_SUPPORTED TRUE)
if(
    CMAKE_C_COMPILER_ID
        STREQUAL
        "MSVC"
    OR CMAKE_CXX_COMPILER_ID
        STREQUAL
        "MSVC"
    OR CMAKE_C_COMPILER_FRONTEND_VARIANT
        STREQUAL
        "MSVC"
    OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT
        STREQUAL
        "MSVC"
)
    set(_TOOLBOX_GCOV_SUPPORTED FALSE)
endif()

if(_TOOLBOX_GCOV_SUPPORTED)
    # Test that Gcov module correctly applies compile and link options
    add_test(
        NAME gcov_integration
        COMMAND
            ${CMAKE_COMMAND} -S ${CMAKE_CURRENT_LIST_DIR}/../unit_tests/gcov -B
            ${CMAKE_CURRENT_BINARY_DIR}/gcov_test -G "${CMAKE_GENERATOR}"
            -DCMAKE_C_COMPILER=${CMAKE_C_COMPILER} -DCMAKE_CXX_COMPILER=${CMAKE_CXX_COMPILER}
    )

    # Validate threshold enforcement toggle behavior
    add_test(
        NAME gcov_thresholds
        COMMAND
            ${CMAKE_COMMAND} ${_TOOLBOX_TEST_HELPER_ARGS}
            -DCMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT=${CMAKE_CURRENT_BINARY_DIR}/test_artifacts -P
            ${CMAKE_CURRENT_LIST_DIR}/../unit_tests/gcov/test_thresholds.cmake
    )

    # Gcov Module Unit Tests (script mode)
    file(GLOB GCOV_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/gcov/test_*.cmake")
    foreach(test_file ${GCOV_TEST_FILES})
        get_filename_component(test_filename ${test_file} NAME_WE)
        string(REGEX REPLACE "^test_" "" test_name ${test_filename})
        # Skip test_thresholds as it's already added above
        if(NOT test_name STREQUAL "thresholds")
            add_test(
                NAME gcov_${test_name}
                COMMAND
                    ${CMAKE_COMMAND} ${_TOOLBOX_TEST_HELPER_ARGS} -P ${test_file}
            )
        endif()
    endforeach()
else()
    message(STATUS "Skipping gcov tests on MSVC toolchains")
endif()

# ==============================================================================
# Integration Tests
# ==============================================================================
# These tests verify module behavior with real projects, compilers, and tools.

if(_TOOLBOX_GCOV_SUPPORTED)
    # Gcov Integration Tests
    file(
        GLOB GCOV_INTEGRATION_TESTS
        "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/integration/gcov/test_*.cmake"
    )
    foreach(test_file ${GCOV_INTEGRATION_TESTS})
        get_filename_component(test_filename ${test_file} NAME_WE)
        string(REGEX REPLACE "^test_" "" test_name ${test_filename})
        add_test(
            NAME integration_gcov_${test_name}
            COMMAND
                ${CMAKE_COMMAND} -DCMAKE_TOOLBOX_TEST_GENERATOR=${CMAKE_GENERATOR}
                -DCMAKE_TOOLBOX_TEST_C_COMPILER=${CMAKE_C_COMPILER}
                -DCMAKE_TOOLBOX_TEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}
                -DCMAKE_TOOLBOX_TEST_BUILD_TYPE=${CMAKE_BUILD_TYPE} -P ${test_file}
        )
    endforeach()
endif()

# Sanitizer Integration Tests
file(
    GLOB SANITIZER_INTEGRATION_TESTS
    "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/integration/sanitizer/test_*.cmake"
)
foreach(test_file ${SANITIZER_INTEGRATION_TESTS})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME integration_sanitizer_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -DCMAKE_TOOLBOX_TEST_GENERATOR=${CMAKE_GENERATOR}
            -DCMAKE_TOOLBOX_TEST_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_TOOLBOX_TEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_TOOLBOX_TEST_BUILD_TYPE=${CMAKE_BUILD_TYPE} -P ${test_file}
    )
endforeach()

# ClangTidy Integration Tests
file(
    GLOB CLANGTIDY_INTEGRATION_TESTS
    "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/integration/clangtidy/test_*.cmake"
)
foreach(test_file ${CLANGTIDY_INTEGRATION_TESTS})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME integration_clangtidy_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -DCMAKE_TOOLBOX_TEST_GENERATOR=${CMAKE_GENERATOR}
            -DCMAKE_TOOLBOX_TEST_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_TOOLBOX_TEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_TOOLBOX_TEST_BUILD_TYPE=${CMAKE_BUILD_TYPE} -P ${test_file}
    )
endforeach()

# ClangFormat Integration Tests
file(
    GLOB CLANGFORMAT_INTEGRATION_TESTS
    "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/integration/clangformat/test_*.cmake"
)
foreach(test_file ${CLANGFORMAT_INTEGRATION_TESTS})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME integration_clangformat_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -DCMAKE_TOOLBOX_TEST_GENERATOR=${CMAKE_GENERATOR}
            -DCMAKE_TOOLBOX_TEST_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_TOOLBOX_TEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_TOOLBOX_TEST_BUILD_TYPE=${CMAKE_BUILD_TYPE} -P ${test_file}
    )
endforeach()

# CompileCommands Integration Tests
file(
    GLOB COMPILECOMMANDS_INTEGRATION_TESTS
    "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/integration/compilecommands/test_*.cmake"
)
foreach(test_file ${COMPILECOMMANDS_INTEGRATION_TESTS})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME integration_compilecommands_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -DCMAKE_TOOLBOX_TEST_GENERATOR=${CMAKE_GENERATOR}
            -DCMAKE_TOOLBOX_TEST_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_TOOLBOX_TEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_TOOLBOX_TEST_BUILD_TYPE=${CMAKE_BUILD_TYPE} -P ${test_file}
    )
endforeach()

# Consumption Integration Tests
file(
    GLOB CONSUMPTION_INTEGRATION_TESTS
    "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/integration/consumption/test_*.cmake"
)
foreach(test_file ${CONSUMPTION_INTEGRATION_TESTS})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME integration_consumption_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -DCMAKE_TOOLBOX_TEST_GENERATOR=${CMAKE_GENERATOR}
            -DCMAKE_TOOLBOX_TEST_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_TOOLBOX_TEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_TOOLBOX_TEST_BUILD_TYPE=${CMAKE_BUILD_TYPE} -P ${test_file}
    )
endforeach()

# FindUnity Integration Tests
file(
    GLOB FINDUNITY_INTEGRATION_TESTS
    "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/integration/findunity/test_*.cmake"
)
foreach(test_file ${FINDUNITY_INTEGRATION_TESTS})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(
        NAME integration_findunity_${test_name}
        COMMAND
            ${CMAKE_COMMAND} -DCMAKE_TOOLBOX_TEST_GENERATOR=${CMAKE_GENERATOR}
            -DCMAKE_TOOLBOX_TEST_C_COMPILER=${CMAKE_C_COMPILER}
            -DCMAKE_TOOLBOX_TEST_CXX_COMPILER=${CMAKE_CXX_COMPILER}
            -DCMAKE_TOOLBOX_TEST_BUILD_TYPE=${CMAKE_BUILD_TYPE} -P ${test_file}
    )
endforeach()
