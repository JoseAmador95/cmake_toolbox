# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
Cppcheck
--------

CMake module for configuring cppcheck static analysis.

This module provides functions to configure cppcheck for CMake targets,
either globally or per-target. Cppcheck is a static analysis tool that
detects various code defects and suspicious constructs.

Dependencies
^^^^^^^^^^^^

This module uses ``find_package(Cppcheck)`` to locate the cppcheck executable.

Functions
^^^^^^^^^

.. command:: Cppcheck_Configure

  Configure cppcheck globally for all targets::

    Cppcheck_Configure(
      STATUS <ON|OFF>
      [STRICT]
      [ENABLE <checks...>]
      [SUPPRESS <checks...>]
      [EXCLUDE_PATTERNS <patterns...>]
    )

  ``STATUS``
    Enable (ON) or disable (OFF) cppcheck globally. Mandatory parameter.

  ``STRICT``
    If specified, causes a fatal error if cppcheck is not found.
    If not specified, a verbose message is issued if cppcheck is not found.

  ``ENABLE``
    List of cppcheck check severities to enable. Common values include:
    ``warning``, ``style``, ``performance``, ``portability``, ``information``.
    Example: ``ENABLE warning style performance``

  ``SUPPRESS``
    List of individual cppcheck checks to suppress.
    Example: ``SUPPRESS missingIncludeSystem unusedVariable``

  ``EXCLUDE_PATTERNS``
    List of path patterns to exclude from analysis.
    Example: ``EXCLUDE_PATTERNS "*/third_party/*" "*/generated/*"``

.. command:: Cppcheck_ConfigureTarget

  Configure cppcheck for a specific target::

    Cppcheck_ConfigureTarget(
      TARGET <target>
      STATUS <ON|OFF>
      [STRICT]
      [ENABLE <checks...>]
      [SUPPRESS <checks...>]
      [EXCLUDE_PATTERNS <patterns...>]
    )

  ``TARGET``
    The target to configure cppcheck for. Target must exist.

  ``STATUS``
    Enable (ON) or disable (OFF) cppcheck for the target. Mandatory parameter.

  ``STRICT``
    If specified, causes a fatal error if cppcheck is not found or target
    does not exist. If not specified, a verbose message is issued.

  ``ENABLE``
    List of cppcheck check severities to enable.

  ``SUPPRESS``
    List of individual cppcheck checks to suppress.

  ``EXCLUDE_PATTERNS``
    List of path patterns to exclude from analysis.

Example
^^^^^^^

.. code-block:: cmake

  include(Cppcheck)

  # Enable cppcheck globally with checks
  Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance
    SUPPRESS missingIncludeSystem
  )

  # Or configure per-target
  add_library(mylib src/lib.c)
  Cppcheck_ConfigureTarget(
    TARGET mylib
    STATUS ON
    ENABLE warning style
  )

Notes
^^^^^

Advisory Mode (Default):
  If ``STRICT`` flag is not specified and cppcheck is not found, the module
  issues a verbose message and continues. This is useful for optional analysis
  in CI/CD pipelines or development environments where cppcheck may not be
  installed.

Strict Mode:
  If ``STRICT`` flag is specified and cppcheck is not found, the module
  issues a fatal error and stops CMake configuration. Use this for strict
  CI/CD environments where cppcheck must be available.

Idempotency:
  Multiple calls to ``Cppcheck_Configure()`` or ``Cppcheck_ConfigureTarget()``
  with the same parameters are safe and will not duplicate configuration.

#]=======================================================================]

include_guard(GLOBAL)

find_package(Cppcheck QUIET)

if(Cppcheck_FOUND)
    message(VERBOSE "Cppcheck found: ${Cppcheck_EXECUTABLE}")
else()
    message(VERBOSE "Cppcheck not found")
endif()

#[=======================================================================[.rst:
Internal helper function to build Cppcheck command with all flags.

Parameters
^^^^^^^^^^

``ENABLE``
  List of check severities to enable (e.g., "warning" "style" "performance")

``SUPPRESS``
  List of checks to suppress (e.g., "missingIncludeSystem" "unusedVariable")

``EXCLUDE_PATTERNS``
  List of path patterns to exclude (e.g., "build/*" "third_party/*")

``RETCMD``
  Output variable name to store the built command list

Example
^^^^^^^

.. code-block:: cmake

  _Cppcheck_BuildCommand(
    "${ENABLE_CHECKS}"
    "${SUPPRESS_CHECKS}"
    "${EXCLUDE_DIRS}"
    result_cmd
  )
  set(CMAKE_CXX_CPPCHECK "${result_cmd}")

#]=======================================================================]
function(_Cppcheck_BuildCommand ENABLE SUPPRESS EXCLUDE_PATTERNS RETCMD)
    set(cmd_list "${Cppcheck_EXECUTABLE}")

    # Build --enable flag if provided
    if(ENABLE)
        list(
            JOIN ENABLE
            ","
            enable_str
        )
        list(APPEND cmd_list "--enable=${enable_str}")
    endif()

    # Build --suppress flag if provided
    if(SUPPRESS)
        list(
            JOIN SUPPRESS
            ","
            suppress_str
        )
        list(APPEND cmd_list "--suppress=${suppress_str}")
    endif()

    # Build --exclude flags if provided
    if(EXCLUDE_PATTERNS)
        foreach(pattern IN LISTS EXCLUDE_PATTERNS)
            list(APPEND cmd_list "--exclude=${pattern}")
        endforeach()
    endif()

    set(${RETCMD} "${cmd_list}" PARENT_SCOPE)
endfunction()

#[=======================================================================[.rst:
Configure cppcheck globally for all C and C++ targets.

This function sets CMAKE_C_CPPCHECK and CMAKE_CXX_CPPCHECK variables
to enable cppcheck analysis during build. By default, this operates in
"advisory mode" - if cppcheck is not found, a verbose message is issued
but configuration continues. Use the STRICT flag to fail configuration
if cppcheck is missing.

Parameters
^^^^^^^^^^

``STATUS``
  Mandatory. ON to enable cppcheck, OFF to disable it.

``STRICT``
  Optional. If specified, fails with fatal error if cppcheck not found.
  Without this flag (advisory mode), missing tool only produces a warning.

``ENABLE``
  Optional. List of check severities to enable.
  Example: ``ENABLE warning style performance portability``

``SUPPRESS``
  Optional. List of individual checks to suppress.
  Example: ``SUPPRESS missingIncludeSystem unusedVariable``

``EXCLUDE_PATTERNS``
  Optional. List of path patterns to exclude from analysis.
  Example: ``EXCLUDE_PATTERNS "*/third_party/*" "*/build/*"``

Example
^^^^^^^

.. code-block:: cmake

  include(Cppcheck)

  # Advisory mode (default): doesn't break without cppcheck
  Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance
    SUPPRESS missingIncludeSystem
    EXCLUDE_PATTERNS "*/generated/*"
  )

  # Strict mode: fails without cppcheck (ideal for CI)
  Cppcheck_Configure(
    STATUS ON STRICT
    ENABLE warning style
  )

  # Disable cppcheck
  Cppcheck_Configure(STATUS OFF)

#]=======================================================================]
function(Cppcheck_Configure)
    set(options STRICT)
    set(oneValueArgs STATUS)
    set(multiValueArgs
        ENABLE
        SUPPRESS
        EXCLUDE_PATTERNS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT DEFINED ARG_STATUS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: STATUS must be specified")
    endif()

    if(NOT ARG_STATUS MATCHES "^(ON|OFF|TRUE|FALSE|1|0)$")
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: STATUS must be a valid CMake boolean, got '${ARG_STATUS}'"
        )
    endif()

    if(Cppcheck_FOUND AND ARG_STATUS)
        _Cppcheck_BuildCommand("${ARG_ENABLE}" "${ARG_SUPPRESS}" "${ARG_EXCLUDE_PATTERNS}" cmd)
        set(CMAKE_C_CPPCHECK "${cmd}" CACHE INTERNAL "" FORCE)
        set(CMAKE_CXX_CPPCHECK "${cmd}" CACHE INTERNAL "" FORCE)
    else()
        if(NOT Cppcheck_FOUND)
            if(ARG_STRICT AND ARG_STATUS)
                message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Cppcheck not found")
            else()
                message(VERBOSE "${CMAKE_CURRENT_FUNCTION}: Cppcheck not found")
            endif()
        endif()
        set(CMAKE_C_CPPCHECK "" CACHE INTERNAL "" FORCE)
        set(CMAKE_CXX_CPPCHECK "" CACHE INTERNAL "" FORCE)
    endif()
endfunction()

#[=======================================================================[.rst:
Configure cppcheck for a specific CMake target.

This function sets C_CPPCHECK and CXX_CPPCHECK target properties to enable
cppcheck analysis for a particular target. The function operates in advisory
mode by default (missing cppcheck tool produces a warning but continues).
Use STRICT flag to enforce strict mode.

Parameters
^^^^^^^^^^

``TARGET``
  Mandatory. The CMake target to configure (must be a valid target).

``STATUS``
  Mandatory. ON to enable cppcheck for target, OFF to disable it.

``STRICT``
  Optional. If specified, fails if cppcheck not found or target doesn't exist.
  Without this flag (advisory mode), only produces warnings.

``ENABLE``
  Optional. List of check severities to enable for this target.
  Example: ``ENABLE warning style``

``SUPPRESS``
  Optional. List of individual checks to suppress for this target.
  Example: ``SUPPRESS missingIncludeSystem``

``EXCLUDE_PATTERNS``
  Optional. List of path patterns to exclude from analysis.
  Example: ``EXCLUDE_PATTERNS "*/third_party/*"``

Example
^^^^^^^

.. code-block:: cmake

  add_library(mylib src/lib.c)
  add_library(utils src/utils.c)

  # Enable cppcheck for mylib with specific checks
  Cppcheck_ConfigureTarget(
    TARGET mylib
    STATUS ON
    ENABLE warning style performance
    SUPPRESS missingIncludeSystem
  )

  # Disable for utils
  Cppcheck_ConfigureTarget(TARGET utils STATUS OFF)

  # Strict mode: fail if target doesn't exist
  Cppcheck_ConfigureTarget(
    TARGET nonexistent
    STATUS ON
    STRICT
  )

#]=======================================================================]
function(Cppcheck_ConfigureTarget)
    set(options STRICT)
    set(oneValueArgs
        TARGET
        STATUS
    )
    set(multiValueArgs
        ENABLE
        SUPPRESS
        EXCLUDE_PATTERNS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_TARGET)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET must be specified")
    endif()

    if(NOT TARGET ${ARG_TARGET})
        if(ARG_STRICT)
            message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Target '${ARG_TARGET}' does not exist")
        else()
            message(VERBOSE "${CMAKE_CURRENT_FUNCTION}: Target '${ARG_TARGET}' does not exist")
            return()
        endif()
    endif()

    if(NOT DEFINED ARG_STATUS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: STATUS must be specified")
    endif()

    if(NOT ARG_STATUS MATCHES "^(ON|OFF|TRUE|FALSE|1|0)$")
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: STATUS must be a valid CMake boolean, got '${ARG_STATUS}'"
        )
    endif()

    if(Cppcheck_FOUND AND ARG_STATUS)
        _Cppcheck_BuildCommand("${ARG_ENABLE}" "${ARG_SUPPRESS}" "${ARG_EXCLUDE_PATTERNS}" cmd)
        set_target_properties(
            ${ARG_TARGET}
            PROPERTIES
                C_CPPCHECK
                    "${cmd}"
                CXX_CPPCHECK
                    "${cmd}"
        )
    else()
        if(NOT Cppcheck_FOUND)
            if(ARG_STRICT AND ARG_STATUS)
                message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Cppcheck not found")
            else()
                message(VERBOSE "${CMAKE_CURRENT_FUNCTION}: Cppcheck not found")
            endif()
        endif()
        set_target_properties(
            ${ARG_TARGET}
            PROPERTIES
                C_CPPCHECK
                    ""
                CXX_CPPCHECK
                    ""
        )
    endif()
endfunction()
