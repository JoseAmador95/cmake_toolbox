# Distributed under the OSI-approved BSD 3-Clause License.
# See accompanying file LICENSE.txt for details.

#[=======================================================================[.rst:
FindJq
------

Find the jq JSON processor.

This module finds the jq executable and defines standard CMake
find_package variables.

Result Variables
^^^^^^^^^^^^^^^^

``Jq_FOUND``
  True if jq was found.

``Jq_EXECUTABLE``
  Path to the jq executable.

``Jq_VERSION``
  Version of jq found (if available).

Cache Variables
^^^^^^^^^^^^^^^

``JQ_EXECUTABLE``
  Path to the jq executable (user-settable).

Example
^^^^^^^

.. code-block:: cmake

  find_package(Jq REQUIRED)
  if(Jq_FOUND)
    message(STATUS "Found jq: ${Jq_EXECUTABLE}")
  endif()

#]=======================================================================]

include_guard(GLOBAL)

# Look for jq executable
find_program(JQ_EXECUTABLE
    NAMES jq
    DOC "Path to jq executable"
)

# Try to get version
if(JQ_EXECUTABLE)
    execute_process(
        COMMAND ${JQ_EXECUTABLE} --version
        OUTPUT_VARIABLE _jq_version_output
        ERROR_QUIET
        OUTPUT_STRIP_TRAILING_WHITESPACE
    )
    if(_jq_version_output MATCHES "jq-([0-9]+\\.[0-9]+)")
        set(Jq_VERSION "${CMAKE_MATCH_1}")
    endif()
    unset(_jq_version_output)
endif()

# Set result variables
set(Jq_EXECUTABLE "${JQ_EXECUTABLE}")

# Handle standard find_package arguments
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(Jq
    REQUIRED_VARS JQ_EXECUTABLE
    VERSION_VAR Jq_VERSION
)

mark_as_advanced(JQ_EXECUTABLE)
