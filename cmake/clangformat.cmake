option(CLANG_FORMAT_USE_FILE "Use .clang-format file" ON)
set(CLANG_FORMAT_CONFIG_FILE "${CMAKE_SOURCE_DIR}/.clang-format" CACHE STRING "Clang-Format config file")
set(CLANG_FORMAT_ARGS "" CACHE STRING "Additional arguments to pass to clang-format")

find_program(CLANG_FORMAT_EXECUTABLE clang-format REQUIRED)
if(NOT CLANG_FORMAT_EXECUTABLE)
    message(FATAL_ERROR "Clang Format not found")
endif()

unset(STYLE)
if(CLANG_FORMAT_USE_FILE)
    set(STYLE --style=file:${CLANG_FORMAT_CONFIG_FILE})
endif()

file(GLOB_RECURSE ALL_SOURCE_FILES ${CMAKE_SOURCE_DIR}/source/*.c ${CMAKE_SOURCE_DIR}/source/*.h)

add_custom_target(
    clangformat_check
    COMMAND ${CLANG_FORMAT_EXECUTABLE}
            ${STYLE}
            --dry-run
            --Werror
            ${CLANG_FORMAT_ARGS}
            ${ALL_SOURCE_FILES}
    COMMENT "Checking code style with ${CLANG_FORMAT_EXECUTABLE}"
)

add_custom_target(
    clangformat_edit
    COMMAND ${CLANG_FORMAT_EXECUTABLE}
            ${STYLE}
            -i
            ${CLANG_FORMAT_ARGS}
            ${ALL_SOURCE_FILES}
    COMMENT "Formatting code with ${CLANG_FORMAT_EXECUTABLE}"
)