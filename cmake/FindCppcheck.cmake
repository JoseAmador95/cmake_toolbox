# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
FindCppcheck
------------

Find the cppcheck static analysis tool.

This module finds the cppcheck executable and defines standard CMake
find_package variables.

Result Variables
^^^^^^^^^^^^^^^^

``Cppcheck_FOUND``
  True if cppcheck was found.

``Cppcheck_EXECUTABLE``
  Path to the cppcheck executable.

``Cppcheck_VERSION``
  Version of cppcheck found (if available).

Cache Variables
^^^^^^^^^^^^^^^

``CPPCHECK_EXECUTABLE``
  Path to the cppcheck executable (user-settable).

Supported Versions
^^^^^^^^^^^^^^^^^^

This finder supports executable names ``cppcheck`` (unversioned) and
versioned variants ``cppcheck-1.0`` through ``cppcheck-3.0``.

Example
^^^^^^^

.. code-block:: cmake

  find_package(Cppcheck REQUIRED)
  if(Cppcheck_FOUND)
    message(STATUS "Found cppcheck: ${Cppcheck_EXECUTABLE}")
  endif()

#]=======================================================================]

include_guard(GLOBAL)

# Define supported cppcheck version range
set(_CPPCHECK_MAX_VERSION 3)
set(_CPPCHECK_MIN_VERSION 1)

# Generate names for different versions (unversioned first, then major.minor variants)
set(_CPPCHECK_NAMES cppcheck)

# Add major.minor version variants (1.0 to 3.0)
foreach(_major RANGE ${_CPPCHECK_MAX_VERSION} ${_CPPCHECK_MIN_VERSION} -1)
    foreach(_minor RANGE 99 0 -1)
        list(APPEND _CPPCHECK_NAMES "cppcheck-${_major}.${_minor}")
    endforeach()
endforeach()

if(WIN32)
    set(_CPPCHECK_WINDOWS_NAMES "")
    foreach(_name IN LISTS _CPPCHECK_NAMES)
        list(APPEND _CPPCHECK_WINDOWS_NAMES "${_name}.exe")
        list(APPEND _CPPCHECK_WINDOWS_NAMES "${_name}.bat")
    endforeach()
    list(APPEND _CPPCHECK_NAMES ${_CPPCHECK_WINDOWS_NAMES})
    unset(_CPPCHECK_WINDOWS_NAMES)
endif()

# Find cppcheck executable
find_program(CPPCHECK_EXECUTABLE NAMES ${_CPPCHECK_NAMES} DOC "Path to cppcheck executable")

# Get version information
if(CPPCHECK_EXECUTABLE)
    execute_process(
        COMMAND
            ${CPPCHECK_EXECUTABLE} --version
        OUTPUT_VARIABLE _cppcheck_version_output
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )

    if(_cppcheck_version_output MATCHES "Cppcheck ([0-9]+\\.[0-9]+\\.[0-9]+)")
        set(Cppcheck_VERSION "${CMAKE_MATCH_1}")
    elseif(_cppcheck_version_output MATCHES "Cppcheck ([0-9]+\\.[0-9]+)")
        set(Cppcheck_VERSION "${CMAKE_MATCH_1}")
    endif()
    unset(_cppcheck_version_output)
endif()

# Set result variables
set(Cppcheck_EXECUTABLE "${CPPCHECK_EXECUTABLE}")

# Cleanup internal variables
unset(_CPPCHECK_NAMES)
unset(_CPPCHECK_MAX_VERSION)
unset(_CPPCHECK_MIN_VERSION)

# Handle standard find_package arguments
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
    Cppcheck
    REQUIRED_VARS
        CPPCHECK_EXECUTABLE
    VERSION_VAR Cppcheck_VERSION
)

mark_as_advanced(CPPCHECK_EXECUTABLE)
