# Test: .clang-tidy config validity
# Ensures check names and list separators are valid.

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CONFIG_FILE "${REPO_ROOT}/.clang-tidy")

set(CLANG_TIDY_NAMES clang-tidy)
foreach(version RANGE 22 10 -1)
    list(APPEND CLANG_TIDY_NAMES "clang-tidy-${version}")
endforeach()

find_program(CLANG_TIDY_EXECUTABLE NAMES ${CLANG_TIDY_NAMES})
if(NOT CLANG_TIDY_EXECUTABLE)
    message(STATUS "Skipping .clang-tidy validation: clang-tidy executable not found")
    return()
endif()

message(STATUS "Validating ${CONFIG_FILE} with ${CLANG_TIDY_EXECUTABLE}")
execute_process(
    COMMAND
        ${CLANG_TIDY_EXECUTABLE} --verify-config --config-file=${CONFIG_FILE}
    RESULT_VARIABLE result
    OUTPUT_VARIABLE output
    ERROR_VARIABLE error
)

if(NOT result EQUAL 0)
    message(STATUS "clang-tidy stdout:\n${output}")
    message(FATAL_ERROR ".clang-tidy validation failed:\n${error}")
endif()

message(STATUS ".clang-tidy validation passed")
