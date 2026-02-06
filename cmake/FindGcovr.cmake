# Distributed under the OSI-approved BSD 3-Clause License.
# See accompanying file LICENSE.txt for details.

#[=======================================================================[.rst:
FindGcovr
---------

Find the gcovr code coverage tool.

This module finds the gcovr executable and defines standard CMake
find_package variables.

Result Variables
^^^^^^^^^^^^^^^^

``Gcovr_FOUND``
  True if gcovr was found.

``Gcovr_EXECUTABLE``
  Path to the gcovr executable.

``Gcovr_VERSION``
  Version of gcovr found (if available).

Cache Variables
^^^^^^^^^^^^^^^

``GCOVR_EXECUTABLE``
  Path to the gcovr executable (user-settable).

Example
^^^^^^^

.. code-block:: cmake

  find_package(Gcovr REQUIRED)
  if(Gcovr_FOUND)
    message(STATUS "Found gcovr: ${Gcovr_EXECUTABLE}")
  endif()

#]=======================================================================]

include_guard(GLOBAL)

# Look for gcovr executable
find_program(GCOVR_EXECUTABLE
    NAMES gcovr
    DOC "Path to gcovr executable"
)

# Try to get version
if(GCOVR_EXECUTABLE)
    execute_process(
        COMMAND ${GCOVR_EXECUTABLE} --version
        OUTPUT_VARIABLE _gcovr_version_output
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(_gcovr_version_output MATCHES "gcovr ([0-9]+\\.[0-9]+)")
        set(Gcovr_VERSION "${CMAKE_MATCH_1}")
    endif()
    unset(_gcovr_version_output)
endif()

# Set result variables
set(Gcovr_EXECUTABLE "${GCOVR_EXECUTABLE}")

# Handle standard find_package arguments
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Gcovr
    REQUIRED_VARS GCOVR_EXECUTABLE
    VERSION_VAR Gcovr_VERSION
)

mark_as_advanced(GCOVR_EXECUTABLE)
