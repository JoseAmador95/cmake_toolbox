# ClangFormat.cmake - Basic clang-format utilities
# This module provides basic clang-format functionality and utilities

# Define standard file extensions for C/C++ source code formatting
set(CLANGFORMAT_DEFAULT_EXTENSIONS
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

# Function to validate clang-format configuration file
function(ClangFormat_ValidateConfig ARG_CONFIG_FILE ARG_OUTPUT_VAR)
    if(EXISTS "${ARG_CONFIG_FILE}")
        set(${ARG_OUTPUT_VAR} "--style=file:${ARG_CONFIG_FILE}" PARENT_SCOPE)
    else()
        message(WARNING "ClangFormat config file not found: ${ARG_CONFIG_FILE}")
        set(${ARG_OUTPUT_VAR} "" PARENT_SCOPE)
    endif()
endfunction()

# Function to collect source files from directories
function(ClangFormat_CollectFiles ARG_OUTPUT_VAR)
    set(options "")
    set(oneValueArgs "")
    set(multiValueArgs
        SOURCE_DIRS
        EXTENSIONS
        EXCLUDE_PATTERNS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Check that SOURCE_DIRS was provided
    if(NOT ARG_SOURCE_DIRS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: SOURCE_DIRS must be provided")
    endif()

    # Set default extensions if not provided
    if(NOT ARG_EXTENSIONS)
        set(ARG_EXTENSIONS ${CLANGFORMAT_DEFAULT_EXTENSIONS})
    endif()

    # Collect source files from specified directories
    set(ALL_FILES "")
    foreach(SOURCE_DIR IN LISTS ARG_SOURCE_DIRS)
        set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
        if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
            foreach(EXTENSION IN LISTS ARG_EXTENSIONS)
                file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${EXTENSION}")
                list(APPEND ALL_FILES ${FOUND_FILES})
            endforeach()
        else()
            message(WARNING "Source directory does not exist: ${FULL_SOURCE_DIR}")
        endif()
    endforeach()

    # Remove duplicates
    if(ALL_FILES)
        list(REMOVE_DUPLICATES ALL_FILES)
    endif()

    # Apply exclude patterns if provided
    if(ARG_EXCLUDE_PATTERNS AND ALL_FILES)
        set(FILTERED_FILES "")
        foreach(source_file IN LISTS ALL_FILES)
            set(EXCLUDE_FILE FALSE)
            foreach(pattern IN LISTS ARG_EXCLUDE_PATTERNS)
                file(RELATIVE_PATH relative_path "${CMAKE_SOURCE_DIR}" "${source_file}")
                if(relative_path MATCHES "${pattern}")
                    set(EXCLUDE_FILE TRUE)
                    break()
                endif()
            endforeach()
            if(NOT EXCLUDE_FILE)
                list(APPEND FILTERED_FILES "${source_file}")
            endif()
        endforeach()
        set(ALL_FILES "${FILTERED_FILES}")
    endif()

    set(${ARG_OUTPUT_VAR} "${ALL_FILES}" PARENT_SCOPE)
endfunction()

# Function to create clang-format command
function(ClangFormat_CreateCommand ARG_OUTPUT_VAR)
    set(options "")
    set(oneValueArgs
        EXECUTABLE
        STYLE_ARG
        MODE
    )
    set(multiValueArgs
        FILES
        ADDITIONAL_ARGS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    set(COMMAND_ARGS "${ARG_EXECUTABLE}")

    if(ARG_STYLE_ARG)
        list(APPEND COMMAND_ARGS "${ARG_STYLE_ARG}")
    endif()

    if(ARG_MODE STREQUAL "CHECK")
        list(
            APPEND
            COMMAND_ARGS
            --dry-run
            --Werror
        )
    elseif(ARG_MODE STREQUAL "FORMAT")
        list(APPEND COMMAND_ARGS -i)
    endif()

    if(ARG_ADDITIONAL_ARGS)
        list(APPEND COMMAND_ARGS ${ARG_ADDITIONAL_ARGS})
    endif()

    list(APPEND COMMAND_ARGS ${ARG_FILES})

    set(${ARG_OUTPUT_VAR} "${COMMAND_ARGS}" PARENT_SCOPE)
endfunction()
