# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
FindIWYU
--------

Find the Include What You Use (IWYU) tool for C++ static analysis.

This module finds the include-what-you-use executable and defines standard CMake
find_package variables. IWYU is a C++-only static analysis tool that analyzes
includes in C++ files.

Result Variables
^^^^^^^^^^^^^^^^

``IWYU_FOUND``
  True if include-what-you-use was found.

``IWYU_EXECUTABLE``
  Path to the include-what-you-use executable.

``IWYU_VERSION``
  Version of include-what-you-use found (if available).

Cache Variables
^^^^^^^^^^^^^^^

``IWYU_EXECUTABLE``
  Path to the include-what-you-use executable (user-settable).

Supported Versions
^^^^^^^^^^^^^^^^^^

This finder supports executable names ``include-what-you-use-0.20``,
``include-what-you-use-0.21``, and other versions, plus unversioned
``include-what-you-use`` and ``iwyu``.

Example
^^^^^^^

.. code-block:: cmake

  find_package(IWYU REQUIRED)
  if(IWYU_FOUND)
    message(STATUS "Found IWYU: ${IWYU_EXECUTABLE}")
  endif()

#]=======================================================================]

include_guard(GLOBAL)

# Generate names for different versions of IWYU
# Start with common version suffixes, then generic names
set(_IWYU_NAMES
    include-what-you-use-0.21
    include-what-you-use-0.20
    include-what-you-use-0.19
    include-what-you-use-0.18
    include-what-you-use
    iwyu
)

if(WIN32)
    set(_IWYU_WINDOWS_NAMES "")
    foreach(_name IN LISTS _IWYU_NAMES)
        list(APPEND _IWYU_WINDOWS_NAMES "${_name}.exe")
        list(APPEND _IWYU_WINDOWS_NAMES "${_name}.bat")
    endforeach()
    list(APPEND _IWYU_NAMES ${_IWYU_WINDOWS_NAMES})
    unset(_IWYU_WINDOWS_NAMES)
endif()

# Find include-what-you-use executable
find_program(IWYU_EXECUTABLE NAMES ${_IWYU_NAMES} DOC "Path to include-what-you-use executable")

# Get version information
if(IWYU_EXECUTABLE)
    execute_process(
        COMMAND
            ${IWYU_EXECUTABLE} --version
        OUTPUT_VARIABLE _iwyu_version_output
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(_iwyu_version_output MATCHES "include-what-you-use ([0-9]+\\.[0-9]+)")
        set(IWYU_VERSION "${CMAKE_MATCH_1}")
    endif()
    unset(_iwyu_version_output)
endif()

# Set result variables
set(IWYU_EXECUTABLE "${IWYU_EXECUTABLE}")

# Cleanup internal variables
unset(_IWYU_NAMES)

# Handle standard find_package arguments
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(IWYU REQUIRED_VARS IWYU_EXECUTABLE VERSION_VAR IWYU_VERSION)

mark_as_advanced(IWYU_EXECUTABLE)
