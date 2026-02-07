# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
FindClangTidy
-------------

Find the clang-tidy static analysis tool.

This module finds the clang-tidy executable and defines standard CMake
find_package variables.

Result Variables
^^^^^^^^^^^^^^^^

``ClangTidy_FOUND``
  True if clang-tidy was found.

``ClangTidy_EXECUTABLE``
  Path to the clang-tidy executable.

``ClangTidy_VERSION``
  Version of clang-tidy found (if available).

Cache Variables
^^^^^^^^^^^^^^^

``CLANG_TIDY_EXECUTABLE``
  Path to the clang-tidy executable (user-settable).

Example
^^^^^^^

.. code-block:: cmake

  find_package(ClangTidy REQUIRED)
  if(ClangTidy_FOUND)
    message(STATUS "Found clang-tidy: ${ClangTidy_EXECUTABLE}")
  endif()

#]=======================================================================]

include_guard(GLOBAL)

# Define supported ClangTidy version range
set(_CLANGTIDY_MAX_VERSION 22)
set(_CLANGTIDY_MIN_VERSION 10)

# Generate names for different versions (max down to min)
set(_CLANGTIDY_NAMES clang-tidy)
foreach(_version RANGE ${_CLANGTIDY_MAX_VERSION} ${_CLANGTIDY_MIN_VERSION} -1)
    list(APPEND _CLANGTIDY_NAMES "clang-tidy-${_version}")
endforeach()

# Find clang-tidy executable
find_program(CLANG_TIDY_EXECUTABLE
    NAMES ${_CLANGTIDY_NAMES}
    DOC "Path to clang-tidy executable"
)

# Get version information
if(CLANG_TIDY_EXECUTABLE)
    execute_process(
        COMMAND ${CLANG_TIDY_EXECUTABLE} --version
        OUTPUT_VARIABLE _clangtidy_version_output
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(_clangtidy_version_output MATCHES "LLVM version ([0-9]+\\.[0-9]+\\.[0-9]+)")
        set(ClangTidy_VERSION "${CMAKE_MATCH_1}")
    elseif(_clangtidy_version_output MATCHES "LLVM version ([0-9]+\\.[0-9]+)")
        set(ClangTidy_VERSION "${CMAKE_MATCH_1}")
    endif()
    unset(_clangtidy_version_output)
endif()

# Set result variables
set(ClangTidy_EXECUTABLE "${CLANG_TIDY_EXECUTABLE}")

# Cleanup internal variables
unset(_CLANGTIDY_NAMES)
unset(_CLANGTIDY_MAX_VERSION)
unset(_CLANGTIDY_MIN_VERSION)

# Handle standard find_package arguments
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(ClangTidy
    REQUIRED_VARS CLANG_TIDY_EXECUTABLE
    VERSION_VAR ClangTidy_VERSION
)

mark_as_advanced(CLANG_TIDY_EXECUTABLE)
