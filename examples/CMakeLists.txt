include(ceedling)
find_package(ClangFormat QUIET)
include(clangtidy)
include(Policy)

add_library(example STATIC ${CMAKE_CURRENT_SOURCE_DIR}/source/example.c)
add_library(dependency INTERFACE)
target_include_directories(dependency INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(example PUBLIC dependency)

add_unit_test(
    NAME example_test
    UNIT_TEST ${CMAKE_CURRENT_SOURCE_DIR}/unit_test/test_example.c
    TARGET example
    MOCK_HEADERS
        ${CMAKE_CURRENT_SOURCE_DIR}/include/dependency.h
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
