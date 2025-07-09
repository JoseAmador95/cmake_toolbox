include(ceedling)
include(clangformat)
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
    MOCK_HEADERS ${CMAKE_CURRENT_SOURCE_DIR}/include/dependency.h
    ENABLE_SANITIZER
)

add_test(
    NAME policy
    COMMAND ${CMAKE_COMMAND} -P ${CMAKE_CURRENT_LIST_DIR}/unit_test/test_policy.cmake
)