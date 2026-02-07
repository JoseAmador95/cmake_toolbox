#[=======================================================================[.rst:
FindClangFormat
---------------

Find clang-format executable and provide functions for code formatting.

This module locates the clang-format executable and provides a target-based
API for adding code formatting checks and formatting targets to your CMake
build system.

Result Variables
^^^^^^^^^^^^^^^^

``ClangFormat_FOUND``
  True if clang-format executable was found.

``ClangFormat_EXECUTABLE``
  Path to the clang-format executable.

``ClangFormat_VERSION``
  Version of clang-format found (if available).

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

Dependencies
^^^^^^^^^^^^

This module includes ``ClangFormat.cmake`` which provides utility functions
for clang-format operations:

- ``ClangFormat_ValidateConfig()`` - Validates configuration file
- ``ClangFormat_CollectFiles()`` - Collects files matching patterns
- ``ClangFormat_CreateCommand()`` - Creates formatting commands

Examples
^^^^^^^^

Basic usage with default configuration::

  find_package(ClangFormat REQUIRED)
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

include(FindPackageHandleStandardArgs)
include(ClangFormat) # Include basic clang-format utilities

# ==============================================================================
# Find clang-format Executable
# ==============================================================================

# Define supported clang-format version range
# This helps find the best available version on the system
set(CLANGFORMAT_MAX_VERSION 22)
set(CLANGFORMAT_MIN_VERSION 10)

# Generate program names to search for (generic name + versioned names)
# This allows finding clang-format-16, clang-format-15, etc.
set(CLANGFORMAT_NAMES clang-format)
foreach(VERSION RANGE ${CLANGFORMAT_MAX_VERSION} ${CLANGFORMAT_MIN_VERSION} -1)
    list(APPEND CLANGFORMAT_NAMES "clang-format-${VERSION}")
endforeach()

# Find clang-format executable in PATH
find_program(
    ClangFormat_EXECUTABLE
    NAMES
        ${CLANGFORMAT_NAMES}
    DOC "Path to clang-format executable"
)

# ==============================================================================
# Detect Version Information
# ==============================================================================

if(ClangFormat_EXECUTABLE)
    # Try to extract version from executable
    execute_process(
        COMMAND
            ${ClangFormat_EXECUTABLE} --version
        OUTPUT_VARIABLE ClangFormat_VERSION_OUTPUT
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    # Parse version in different formats (e.g. "clang-format version 14.0.6" or "clang-format version 14.0")
    if(ClangFormat_VERSION_OUTPUT MATCHES "clang-format version ([0-9]+)\\.([0-9]+)\\.([0-9]+)")
        set(ClangFormat_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}.${CMAKE_MATCH_3}")
    elseif(ClangFormat_VERSION_OUTPUT MATCHES "clang-format version ([0-9]+)\\.([0-9]+)")
        set(ClangFormat_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}")
    endif()
endif()

# ==============================================================================
# Handle find_package() Arguments
# ==============================================================================

# Use standard CMake find_package() result variables
find_package_handle_standard_args(
    ClangFormat
    REQUIRED_VARS
        ClangFormat_EXECUTABLE
    VERSION_VAR ClangFormat_VERSION
)

# Mark internal variables as advanced (hide from CMake GUI)
mark_as_advanced(ClangFormat_EXECUTABLE)

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
