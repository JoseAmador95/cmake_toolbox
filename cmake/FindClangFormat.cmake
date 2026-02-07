# SPDX-License-Identifier: MIT
#[=======================================================================[.rst:
FindClangFormat
---------------

Find clang-format executable.

This module locates the clang-format executable and provides standard
CMake find_package result variables. For functions to work with clang-format,
include the ``ClangFormat`` module after finding it.

Result Variables
^^^^^^^^^^^^^^^^

``ClangFormat_FOUND``
  True if clang-format executable was found.

``ClangFormat_EXECUTABLE``
  Path to the clang-format executable.

``ClangFormat_VERSION``
  Version of clang-format found (if available).

Example
^^^^^^^

.. code-block:: cmake

  find_package(ClangFormat REQUIRED)
  include(ClangFormat)  # Load functions for clang-format usage
  
  ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS src include
  )

#]=======================================================================]

include_guard(GLOBAL)
include(FindPackageHandleStandardArgs)

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
