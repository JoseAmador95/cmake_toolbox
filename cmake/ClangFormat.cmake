#[=======================================================================[.rst:
ClangFormat
-----------

Utilities and functions for working with clang-format code formatter.

This module provides utility functions for clang-format operations including
file collection, command creation, and a target-based API for adding code
formatting checks and formatting targets to your CMake build system.

Requires:
  ``find_package(ClangFormat)`` must be called before using this module.

Functions
^^^^^^^^^

.. command:: ClangFormat_AddTargets

  Add clang-format check and format targets for a project::

    ClangFormat_AddTargets(
      TARGET_PREFIX <prefix>
      [SOURCE_DIRS <dir1> [<dir2> ...]]
      [EXTENSIONS <ext1> [<ext2> ...]]
      [EXCLUDE_PATTERNS <pattern1> [<pattern2> ...]]
      [CONFIG_FILE <path>]
      [ADDITIONAL_ARGS <arg1> [<arg2> ...]]
    )

  ``TARGET_PREFIX`` (required)
    Prefix for the generated targets. Creates ``<prefix>_check`` and ``<prefix>_format`` targets.

  ``SOURCE_DIRS``
    Directories to scan for source files. If not specified, defaults to current directory.

  ``EXTENSIONS``
    File patterns to match (e.g., ``*.c``, ``*.cpp``, ``*.h``).
    Default: ``*.c``, ``*.h``, ``*.cpp``, ``*.cxx``, ``*.cc``, ``*.c++``, ``*.hpp``, ``*.hxx``, ``*.hh``, ``*.h++``

  ``EXCLUDE_PATTERNS``
    Regex patterns to exclude files from formatting (e.g., ``.*generated.*``, ``.*third_party.*``).

  ``CONFIG_FILE``
    Path to .clang-format configuration file.
    Default: ``${CMAKE_SOURCE_DIR}/.clang-format``

  ``ADDITIONAL_ARGS``
    Additional arguments to pass to clang-format executable.

Generated Targets
^^^^^^^^^^^^^^^^^

For each call to ``ClangFormat_AddTargets(TARGET_PREFIX my_project ...)``,
two targets are created:

``my_project_check``
  Runs clang-format in check mode. Fails if code is not properly formatted.
  Use with ``make my_project_check`` or ``ctest``.

``my_project_format``
  Runs clang-format in-place formatting. Modifies files to match style.
  Use with ``make my_project_format``.

Examples
^^^^^^^^

Basic usage with default configuration::

  find_package(ClangFormat REQUIRED)
  include(ClangFormat)
  
  ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS src include
  )
  
  # Now you can run:
  # - make myproject_check    (verify formatting)
  # - make myproject_format   (apply formatting)

With custom configuration and exclusions::

  ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS src include tests
    CONFIG_FILE ${CMAKE_SOURCE_DIR}/tools/.clang-format
    EXCLUDE_PATTERNS ".*generated.*" ".*third_party.*"
    EXTENSIONS "*.c" "*.h"
  )

With additional clang-format arguments::

  ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS src
    ADDITIONAL_ARGS "--verbose"
  )

#]=======================================================================]

include_guard(GLOBAL)

# ClangFormat.cmake - Basic clang-format utilities
# This module provides basic clang-format functionality and utilities

# Define standard file patterns for C/C++ source code formatting
set(CLANGFORMAT_DEFAULT_PATTERNS
    "*.c"
    "*.h"
    "*.C"
    "*.H"
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
    # Handle empty string
    if(NOT ARG_CONFIG_FILE)
        set(${ARG_OUTPUT_VAR} "" PARENT_SCOPE)
        return()
    endif()
    
    # Convert relative paths to absolute paths
    if(NOT IS_ABSOLUTE "${ARG_CONFIG_FILE}")
        set(ABSOLUTE_CONFIG_FILE "${CMAKE_SOURCE_DIR}/${ARG_CONFIG_FILE}")
    else()
        set(ABSOLUTE_CONFIG_FILE "${ARG_CONFIG_FILE}")
    endif()
    
    # Check if path exists and is a file (not a directory)
    if(EXISTS "${ABSOLUTE_CONFIG_FILE}")
        if(NOT IS_DIRECTORY "${ABSOLUTE_CONFIG_FILE}")
            set(${ARG_OUTPUT_VAR} "--style=file:${ABSOLUTE_CONFIG_FILE}" PARENT_SCOPE)
        else()
            message(WARNING "ClangFormat config file is a directory, not a file: ${ABSOLUTE_CONFIG_FILE}")
            set(${ARG_OUTPUT_VAR} "" PARENT_SCOPE)
        endif()
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
        PATTERNS
        EXCLUDE_PATTERNS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Check that SOURCE_DIRS was provided
    if(NOT ARG_SOURCE_DIRS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: SOURCE_DIRS must be provided")
    endif()

    # Set default patterns if not provided
    if(NOT ARG_PATTERNS)
        set(ARG_PATTERNS ${CLANGFORMAT_DEFAULT_PATTERNS})
    endif()

    # Collect source files from specified directories
    set(ALL_FILES "")
    foreach(SOURCE_DIR IN LISTS ARG_SOURCE_DIRS)
        set(FULL_SOURCE_DIR "${CMAKE_SOURCE_DIR}/${SOURCE_DIR}")
        if(IS_DIRECTORY "${FULL_SOURCE_DIR}")
            foreach(PATTERN IN LISTS ARG_PATTERNS)
                file(GLOB_RECURSE FOUND_FILES "${FULL_SOURCE_DIR}/${PATTERN}")
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
        # For check mode, use CMake script for cross-platform compatibility
        # Pass parameters to the script via -D arguments
        set(COMMAND_ARGS "${CMAKE_COMMAND}")
        list(APPEND COMMAND_ARGS "-DCLANG_FORMAT_EXECUTABLE=${ARG_EXECUTABLE}")
        if(ARG_STYLE_ARG)
            list(APPEND COMMAND_ARGS "-DCLANG_FORMAT_STYLE_ARG=${ARG_STYLE_ARG}")
        endif()
        if(ARG_ADDITIONAL_ARGS)
            string(REPLACE ";" "\\;" ESCAPED_ARGS "${ARG_ADDITIONAL_ARGS}")
            list(APPEND COMMAND_ARGS "-DCLANG_FORMAT_ADDITIONAL_ARGS=${ESCAPED_ARGS}")
        endif()

        # Convert file list to string for passing to script
        string(REPLACE ";" "\\;" ESCAPED_FILES "${ARG_FILES}")
        list(APPEND COMMAND_ARGS "-DCLANG_FORMAT_FILES=${ESCAPED_FILES}")

        # Add the script to execute
        list(APPEND COMMAND_ARGS "-P")
        list(APPEND COMMAND_ARGS "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ClangFormatCheck.cmake")

        set(COMMAND_ARGS "${COMMAND_ARGS}")
    elseif(ARG_MODE STREQUAL "FORMAT")
        list(APPEND COMMAND_ARGS -i)
        if(ARG_ADDITIONAL_ARGS)
            list(APPEND COMMAND_ARGS ${ARG_ADDITIONAL_ARGS})
        endif()
        list(APPEND COMMAND_ARGS ${ARG_FILES})
    endif()

    set(${ARG_OUTPUT_VAR} "${COMMAND_ARGS}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# ClangFormat_AddTargets
# ==============================================================================
#
# Add clang-format check and format targets for a project.
#
# Parameters:
#   TARGET_PREFIX (required) - Prefix for generated targets (creates <prefix>_check and <prefix>_format)
#   SOURCE_DIRS              - Directories to scan for source files
#   EXTENSIONS               - File patterns to match (default: *.c, *.h, *.cpp, etc.)
#   EXCLUDE_PATTERNS         - Regex patterns to exclude files
#   CONFIG_FILE              - Path to .clang-format config (default: ${CMAKE_SOURCE_DIR}/.clang-format)
#   ADDITIONAL_ARGS          - Additional clang-format arguments
#
# Generated Targets:
#   <prefix>_check  - Check formatting without modifying files
#   <prefix>_format - Apply formatting to files in-place
#
function(ClangFormat_AddTargets)
    # Parse arguments
    set(options "")
    set(oneValueArgs TARGET_PREFIX CONFIG_FILE)
    set(multiValueArgs
        SOURCE_DIRS
        EXTENSIONS
        EXCLUDE_PATTERNS
        ADDITIONAL_ARGS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_TARGET_PREFIX)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET_PREFIX must be specified")
    endif()

    if(NOT ClangFormat_FOUND)
        message(WARNING "${CMAKE_CURRENT_FUNCTION}: ClangFormat not found, skipping targets for ${ARG_TARGET_PREFIX}")
        return()
    endif()

    # ===========================================================================
    # Setup Configuration
    # ===========================================================================

    # Set default config file if not provided
    if(NOT ARG_CONFIG_FILE)
        set(ARG_CONFIG_FILE "${CMAKE_SOURCE_DIR}/.clang-format")
    endif()

    # Validate configuration file and get style argument for clang-format
    ClangFormat_ValidateConfig("${ARG_CONFIG_FILE}" STYLE_ARG)

    # ===========================================================================
    # Collect Source Files
    # ===========================================================================

    # Collect source files using the utility function with specified patterns and exclusions
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
            "${CMAKE_CURRENT_FUNCTION}: No source files found for ${ARG_TARGET_PREFIX} clang-format in directories: ${ARG_SOURCE_DIRS}"
        )
        return()
    endif()

    list(LENGTH ALL_SOURCE_FILES SOURCE_FILE_COUNT)
    message(STATUS "${CMAKE_CURRENT_FUNCTION}: Found ${SOURCE_FILE_COUNT} source files for ${ARG_TARGET_PREFIX} clang-format")

    # ===========================================================================
    # Create Formatting Commands
    # ===========================================================================

    # Create check command (verify formatting without modifying files)
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

    # Create format command (apply formatting in-place)
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

    # ===========================================================================
    # Create CMake Targets
    # ===========================================================================

    # Create check target - fails if code is not properly formatted
    add_custom_target(
        ${ARG_TARGET_PREFIX}_check
        COMMAND
            ${CHECK_COMMAND}
        COMMENT
            "Checking code style with clang-format for ${ARG_TARGET_PREFIX} (${SOURCE_FILE_COUNT} files)"
        VERBATIM
    )

    # Create format target - applies formatting to files in-place
    add_custom_target(
        ${ARG_TARGET_PREFIX}_format
        COMMAND
            ${FORMAT_COMMAND}
        COMMENT
            "Formatting code with clang-format for ${ARG_TARGET_PREFIX} (${SOURCE_FILE_COUNT} files)"
        VERBATIM
    )

    # ===========================================================================
    # Set Target Properties
    # ===========================================================================

    # Mark these as clang-format targets with metadata for build systems
    set_target_properties(
        ${ARG_TARGET_PREFIX}_check
        ${ARG_TARGET_PREFIX}_format
        PROPERTIES
            CLANGFORMAT_TARGET
                TRUE
            CLANGFORMAT_SOURCE_COUNT
                ${SOURCE_FILE_COUNT}
    )
endfunction()
