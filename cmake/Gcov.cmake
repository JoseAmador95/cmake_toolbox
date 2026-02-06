# Distributed under the OSI-approved BSD 3-Clause License.
# See accompanying file LICENSE.txt for details.

#[=======================================================================[.rst:
Gcov
----

CMake module for enabling code coverage instrumentation using gcov/gcovr.

This module provides functions to add coverage instrumentation to CMake targets
and custom targets to generate coverage reports.

Dependencies
^^^^^^^^^^^^

This module requires gcovr to be installed. Use ``find_package(Gcovr)`` before
including this module, or let the module find it automatically.

Cache Variables
^^^^^^^^^^^^^^^

``GCOV_CONFIG_FILE``
  Path to gcovr configuration file.
  Default: ``${CMAKE_SOURCE_DIR}/gcovr.cfg``

``GCOV_OUTPUT_FILE``
  Path to coverage output HTML file.
  Default: ``${CMAKE_CURRENT_BINARY_DIR}/coverage/results.html``

``GCOV_ROOT_DIR``
  Root directory for coverage analysis.
  Default: ``${CMAKE_SOURCE_DIR}``

``GCOV_COMPILE_FLAGS``
  Compiler flags for coverage instrumentation.
  Default: ``--coverage``

``GCOV_LINKER_FLAGS``
  Linker flags for coverage instrumentation.
  Default: ``--coverage``

Functions
^^^^^^^^^

.. command:: Gcov_AddToTarget

  Add coverage instrumentation to a target::

    Gcov_AddToTarget(<target> <scope>)

  ``<target>``
    The target to add coverage instrumentation to.

  ``<scope>``
    The scope for compile options and link libraries (PUBLIC, PRIVATE, INTERFACE).

Targets
^^^^^^^

``gcovr_html``
  Custom target to generate HTML coverage report.

Example
^^^^^^^

.. code-block:: cmake

  include(Gcov)
  
  add_executable(my_test test.c)
  Gcov_AddToTarget(my_test PRIVATE)
  
  # Run tests and generate report:
  # cmake --build . --target my_test
  # ctest
  # cmake --build . --target gcovr_html

#]=======================================================================]

include_guard(GLOBAL)

# ==============================================================================
# Find gcovr
# ==============================================================================

find_package(Gcovr REQUIRED)

# ==============================================================================
# Cache Variables
# ==============================================================================

set(GCOV_CONFIG_FILE
    ${CMAKE_SOURCE_DIR}/gcovr.cfg
    CACHE FILEPATH
    "Path to gcovr configuration file"
)

set(GCOV_OUTPUT_FILE
    ${CMAKE_CURRENT_BINARY_DIR}/coverage/results.html
    CACHE FILEPATH
    "Path to coverage output file"
)

set(GCOV_ROOT_DIR
    ${CMAKE_SOURCE_DIR}
    CACHE PATH
    "Root directory for coverage analysis"
)

set(GCOV_COMPILE_FLAGS
    --coverage
    CACHE STRING
    "Compiler flags for coverage instrumentation"
)

set(GCOV_LINKER_FLAGS
    --coverage
    CACHE STRING
    "Linker flags for coverage instrumentation"
)

# ==============================================================================
# Setup
# ==============================================================================

cmake_path(GET GCOV_OUTPUT_FILE PARENT_PATH _gcov_output_dir)
file(MAKE_DIRECTORY ${_gcov_output_dir})

# ==============================================================================
# Gcov_AddToTarget
# ==============================================================================
#
# Add coverage instrumentation to a target.
#
# Parameters:
#   TARGET - The target to add coverage instrumentation to
#   SCOPE  - The scope for compile options and link libraries
#
function(Gcov_AddToTarget TARGET SCOPE)
    if(NOT TARGET ${TARGET})
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Target '${TARGET}' does not exist")
    endif()

    target_compile_options(
        ${TARGET}
        ${SCOPE}
        ${GCOV_COMPILE_FLAGS}
    )

    target_link_libraries(
        ${TARGET}
        ${SCOPE}
        ${GCOV_LINKER_FLAGS}
    )
endfunction()

# ==============================================================================
# Coverage Report Target
# ==============================================================================

if(NOT TARGET gcovr_html)
    add_custom_target(gcovr_html
        COMMAND
            ${Gcovr_EXECUTABLE}
            --config ${GCOV_CONFIG_FILE}
            --root ${GCOV_ROOT_DIR}
            --print-summary
            --html-details ${GCOV_OUTPUT_FILE}
        WORKING_DIRECTORY ${GCOV_ROOT_DIR}
        COMMENT "Generate coverage HTML report"
    )
endif()

# ==============================================================================
# Backward Compatibility Alias
# ==============================================================================

function(target_add_gcov _target _scope)
    message(DEPRECATION "target_add_gcov() is deprecated, use Gcov_AddToTarget() instead")
    Gcov_AddToTarget(${_target} ${_scope})
endfunction()
