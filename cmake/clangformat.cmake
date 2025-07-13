option(CLANG_FORMAT_USE_FILE "Use .clang-format file" ON)
set(CLANG_FORMAT_CONFIG_FILE
    "${CMAKE_SOURCE_DIR}/.clang-format"
    CACHE STRING
    "Clang-Format config file"
)
set(CLANG_FORMAT_ARGS "" CACHE STRING "Additional arguments to pass to clang-format")
set(CLANG_FORMAT_SOURCE_DIRS
    "examples/source;examples/include"
    CACHE STRING
    "Semicolon-separated list of source directories to format"
)
set(CLANG_FORMAT_EXCLUDE_PATTERNS
    ""
    CACHE STRING
    "Semicolon-separated list of regex patterns to exclude from formatting"
)

find_program(CLANG_FORMAT_EXECUTABLE clang-format)

if(NOT CLANG_FORMAT_EXECUTABLE)
    message(STATUS "clang-format not found, skipping format targets")
    return()
endif()

# Validate configuration file exists if using file-based style
if(CLANG_FORMAT_USE_FILE)
    if(NOT EXISTS "${CLANG_FORMAT_CONFIG_FILE}")
        message(FATAL_ERROR "Clang-format config file not found: ${CLANG_FORMAT_CONFIG_FILE}")
    endif()
    set(STYLE --style=file:${CLANG_FORMAT_CONFIG_FILE})
else()
    set(STYLE "")
endif()

# Define file extensions to format
set(CLANG_FORMAT_EXTENSIONS
    "*.c"
    "*.h"
    "*.cpp"
    "*.cxx"
    "*.cc"
    "*.c++"
    "*.hpp"
    "*.hxx"
    "*.hh"
    "*.h++"
)

# Collect source files from specified directories
set(ALL_SOURCE_FILES "")
foreach(SOURCE_DIR IN LISTS CLANG_FORMAT_SOURCE_DIRS)
    set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
    if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
        foreach(EXTENSION IN LISTS CLANG_FORMAT_EXTENSIONS)
            file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
            list(APPEND ALL_SOURCE_FILES ${FOUND_FILES})
        endforeach()
    else()
        message(WARNING "Source directory does not exist: ${FULL_SOURCE_DIR}")
    endif()
endforeach()

# Remove duplicates
list(REMOVE_DUPLICATES ALL_SOURCE_FILES)

# Store original count for exclude reporting
list(LENGTH ALL_SOURCE_FILES ORIGINAL_FILE_COUNT)

# Apply exclude patterns
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    set(FILTERED_SOURCE_FILES "")
    foreach(source_file IN LISTS ALL_SOURCE_FILES)
        set(EXCLUDE_FILE FALSE)
        foreach(regex_pattern IN LISTS CLANG_FORMAT_EXCLUDE_PATTERNS)
            # Check relative path from CMAKE_SOURCE_DIR for path-based patterns
            file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
            if(relative_path MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()

            # Check just the filename without path for filename-based patterns
            get_filename_component(filename "${source_file}" NAME)
            if(filename MATCHES "${regex_pattern}")
                set(EXCLUDE_FILE TRUE)
                break()
            endif()
        endforeach()

        if(NOT EXCLUDE_FILE)
            list(APPEND FILTERED_SOURCE_FILES "${source_file}")
        endif()
    endforeach()

    set(ALL_SOURCE_FILES "${FILTERED_SOURCE_FILES}")

    # Report excluded files count
    list(LENGTH ALL_SOURCE_FILES FILTERED_COUNT)
    math(EXPR EXCLUDED_COUNT "${ORIGINAL_FILE_COUNT} - ${FILTERED_COUNT}")
    if(EXCLUDED_COUNT GREATER 0)
        message(
            STATUS
            "Excluded ${EXCLUDED_COUNT} files matching patterns: ${CLANG_FORMAT_EXCLUDE_PATTERNS}"
        )
    endif()
endif()

if(NOT ALL_SOURCE_FILES)
    message(
        WARNING
        "No source files found for clang-format in directories: ${CLANG_FORMAT_SOURCE_DIRS}"
    )
    return()
endif()

list(LENGTH ALL_SOURCE_FILES SOURCE_FILE_COUNT)
message(STATUS "Found ${SOURCE_FILE_COUNT} source files for clang-format")

add_custom_target(
    clangformat_check
    COMMAND
        ${CLANG_FORMAT_EXECUTABLE} ${STYLE} --dry-run --Werror ${CLANG_FORMAT_ARGS}
        ${ALL_SOURCE_FILES}
    COMMENT "Checking code style with clang-format (${SOURCE_FILE_COUNT} files)"
    VERBATIM
)

add_custom_target(
    clangformat_edit
    COMMAND
        ${CLANG_FORMAT_EXECUTABLE} ${STYLE} -i ${CLANG_FORMAT_ARGS} ${ALL_SOURCE_FILES}
    COMMENT "Formatting code with clang-format (${SOURCE_FILE_COUNT} files)"
    VERBATIM
)
