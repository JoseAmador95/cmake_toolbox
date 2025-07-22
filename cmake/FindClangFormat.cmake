#[=======================================================================[.rst:
FindClangFormat
---------------

Find clang-format executable and provide functions for code formatting.

Variables:
  ClangFormat_FOUND        - True if clang-format executable was found
  ClangFormat_EXECUTABLE   - Path to clang-format executable
  ClangFormat_VERSION      - Version string of clang-format

Functions:
  ClangFormat_AddTargets(TARGET_PREFIX [options]) - Add clang-format targets

Example usage:
  find_package(ClangFormat REQUIRED)
  ClangFormat_AddTargets(
    my_project
    SOURCE_DIRS src include
    CONFIG_FILE ${CMAKE_SOURCE_DIR}/.clang-format
    EXCLUDE_PATTERNS ".*generated.*"
  )

#]=======================================================================]

include(FindPackageHandleStandardArgs)
include(ClangFormat) # Include basic clang-format utilities

# Define supported ClangFormat version range
set(CLANGFORMAT_MAX_VERSION 22)
set(CLANGFORMAT_MIN_VERSION 10)

# Find clang-format executable
# Generate names for different versions (max down to min)
set(CLANGFORMAT_NAMES clang-format)
foreach(VERSION RANGE ${CLANGFORMAT_MAX_VERSION} ${CLANGFORMAT_MIN_VERSION} -1)
    list(APPEND CLANGFORMAT_NAMES "clang-format-${VERSION}")
endforeach()

find_program(
    ClangFormat_EXECUTABLE
    NAMES ${CLANGFORMAT_NAMES}
    DOC "Path to clang-format executable"
)

# Get version information
if(ClangFormat_EXECUTABLE)
    execute_process(
        COMMAND
            ${ClangFormat_EXECUTABLE} --version
        OUTPUT_VARIABLE ClangFormat_VERSION_OUTPUT
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(ClangFormat_VERSION_OUTPUT MATCHES "clang-format version ([0-9]+)\\.([0-9]+)\\.([0-9]+)")
        set(ClangFormat_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
    elseif(ClangFormat_VERSION_OUTPUT MATCHES "clang-format version ([0-9]+)\\.([0-9]+)")
        set(ClangFormat_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}")
    endif()
endif()

# Handle standard find_package arguments
find_package_handle_standard_args(
    ClangFormat
    REQUIRED_VARS
        ClangFormat_EXECUTABLE
    VERSION_VAR ClangFormat_VERSION
)

# Mark cache variables as advanced
mark_as_advanced(ClangFormat_EXECUTABLE)

# Function to add clang-format targets
function(ClangFormat_AddTargets TARGET_PREFIX)
    if(NOT ClangFormat_FOUND)
        message(WARNING "ClangFormat not found, skipping targets for ${TARGET_PREFIX}")
        return()
    endif()

    # Parse arguments
    set(options "")
    set(oneValueArgs CONFIG_FILE)
    set(multiValueArgs
        SOURCE_DIRS
        EXTENSIONS
        EXCLUDE_PATTERNS
        ADDITIONAL_ARGS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Set default config file
    if(NOT ARG_CONFIG_FILE)
        set(ARG_CONFIG_FILE "${CMAKE_SOURCE_DIR}/.clang-format")
    endif()

    # Validate configuration file and get style argument
    ClangFormat_ValidateConfig("${ARG_CONFIG_FILE}" STYLE_ARG)

    # Collect source files using the utility function
    ClangFormat_CollectFiles(
        ALL_SOURCE_FILES
        SOURCE_DIRS
            ${ARG_SOURCE_DIRS}
        PATTERNS
            ${ARG_EXTENSIONS}
        EXCLUDE_PATTERNS
            ${ARG_EXCLUDE_PATTERNS}
    )

    if(NOT ALL_SOURCE_FILES)
        message(
            WARNING
            "No source files found for ${TARGET_PREFIX} clang-format in directories: ${ARG_SOURCE_DIRS}"
        )
        return()
    endif()

    list(LENGTH ALL_SOURCE_FILES SOURCE_FILE_COUNT)
    message(STATUS "Found ${SOURCE_FILE_COUNT} source files for ${TARGET_PREFIX} clang-format")

    # Create check command
    ClangFormat_CreateCommand(
        CHECK_COMMAND
        EXECUTABLE ${ClangFormat_EXECUTABLE}
        STYLE_ARG "${STYLE_ARG}"
        FILES
            "${ALL_SOURCE_FILES}"
        MODE CHECK
        ADDITIONAL_ARGS
            ${ARG_ADDITIONAL_ARGS}
    )

    # Create format command
    ClangFormat_CreateCommand(
        FORMAT_COMMAND
        EXECUTABLE ${ClangFormat_EXECUTABLE}
        STYLE_ARG "${STYLE_ARG}"
        FILES
            "${ALL_SOURCE_FILES}"
        MODE FORMAT
        ADDITIONAL_ARGS
            ${ARG_ADDITIONAL_ARGS}
    )

    # Create check target
    add_custom_target(
        ${TARGET_PREFIX}_check
        COMMAND
            ${CHECK_COMMAND}
        COMMENT
            "Checking code style with clang-format for ${TARGET_PREFIX} (${SOURCE_FILE_COUNT} files)"
        VERBATIM
    )

    # Create format target
    add_custom_target(
        ${TARGET_PREFIX}_format
        COMMAND
            ${FORMAT_COMMAND}
        COMMENT
            "Formatting code with clang-format for ${TARGET_PREFIX} (${SOURCE_FILE_COUNT} files)"
        VERBATIM
    )

    # Set target properties to indicate they use ClangFormat
    set_target_properties(
        ${TARGET_PREFIX}_check
        ${TARGET_PREFIX}_format
        PROPERTIES
            CLANGFORMAT_TARGET
                TRUE
            CLANGFORMAT_SOURCE_COUNT
                ${SOURCE_FILE_COUNT}
    )
endfunction()
