# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
IWYU
----

CMake module for configuring Include What You Use (IWYU) static analysis.

This module provides functions to configure IWYU for CMake targets, either
globally or per-target. IWYU is a C++-only static analysis tool that identifies
and suggests removal of unnecessary include directives.

Dependencies
^^^^^^^^^^^^

This module uses ``find_package(IWYU)`` to locate the include-what-you-use
executable. IWYU is C++-only: this module only sets CMAKE_CXX_INCLUDE_WHAT_YOU_USE
(never C_INCLUDE_WHAT_YOU_USE).

Cache Variables
^^^^^^^^^^^^^^^

None. IWYU-specific configuration is done via function parameters.

Functions
^^^^^^^^^

.. command:: IWYU_Configure

  Configure IWYU globally for all C++ targets::

    IWYU_Configure(
      STATUS <ON|OFF>
      [STRICT]
      [MAPPING_FILE <path>]
      [ADDITIONAL_ARGS <arg1;arg2;...>]
      [EXCLUDE_PATTERNS <pattern1;pattern2;...>]
    )

  ``STATUS``
    Enable (ON) or disable (OFF) IWYU globally. Mandatory.

  ``STRICT``
    If specified, failure to find IWYU will be a fatal error. Without this flag,
    a missing IWYU tool produces an advisory message only.

  ``MAPPING_FILE``
    Optional path to an IWYU mapping file (.imp format). The path is passed to
    IWYU as ``-Xiwyu --mapping_file=<path>``. If STRICT mode and file does not
    exist, an error is raised.

  ``ADDITIONAL_ARGS``
    Optional semicolon-separated list of IWYU arguments to pass directly. Each
    argument is prefixed with ``-Xiwyu`` automatically. Example:
    ``--no_fwd_decls;--keep_going;--check_also=<file>``.

  ``EXCLUDE_PATTERNS``
    Optional semicolon-separated list of path patterns to exclude (reserved for
    future use or target-level filtering).

.. command:: IWYU_ConfigureTarget

  Configure IWYU for a specific C++ target::

    IWYU_ConfigureTarget(
      TARGET <target>
      STATUS <ON|OFF>
      [STRICT]
      [MAPPING_FILE <path>]
      [ADDITIONAL_ARGS <arg1;arg2;...>]
      [EXCLUDE_PATTERNS <pattern1;pattern2;...>]
    )

  ``TARGET``
    The CMake target to configure IWYU for (must be a valid target).

  ``STATUS``
    Enable (ON) or disable (OFF) IWYU for the target.

  ``STRICT``
    If specified, failure to find IWYU or a missing mapping file will be a fatal
    error. Without this flag, missing tool produces advisory message only.

  ``MAPPING_FILE``
    Optional path to an IWYU mapping file. Passed as ``-Xiwyu --mapping_file=<path>``.

  ``ADDITIONAL_ARGS``
    Optional semicolon-separated list of IWYU arguments.

  ``EXCLUDE_PATTERNS``
    Optional semicolon-separated list of path patterns to exclude.

Example
^^^^^^^

.. code-block:: cmake

  include(IWYU)

  # Enable IWYU globally in strict mode with mapping file
  IWYU_Configure(
    STATUS ON
    STRICT
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--no_fwd_decls;--keep_going"
  )

  # Or configure per-target
  add_library(mylib src/lib.cpp)
  IWYU_ConfigureTarget(
    TARGET mylib
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
  )

  # Disable for a specific target
  IWYU_ConfigureTarget(TARGET mylib STATUS OFF)

Notes
^^^^^

**Advisory vs Strict Mode**

By default, if IWYU is not found, an advisory message is printed (VERBOSE level)
and processing continues. Specify the STRICT flag to raise a FATAL_ERROR if IWYU
is not found.

**IWYU Arguments**

IWYU options are passed using the ``-Xiwyu`` prefix to work correctly with
CMake's CXX_INCLUDE_WHAT_YOU_USE property. The final command is automatically
formatted as::

  include-what-you-use;-Xiwyu;--no_fwd_decls;-Xiwyu;--keep_going;...

**Mapping Files**

IWYU mapping files (.imp format) customize symbol-to-header mappings. Specify
the path via MAPPING_FILE parameter. The module will check that the file exists
if STRICT mode is enabled.

**C++ Only**

IWYU only analyzes C++ files. This module sets CMAKE_CXX_INCLUDE_WHAT_YOU_USE
and never sets CMAKE_C_INCLUDE_WHAT_YOU_USE.

**Integration with compile_commands.json**

IWYU works with compile_commands.json. Ensure compile commands are generated
by enabling CMAKE_EXPORT_COMPILE_COMMANDS::

  cmake -DCMAKE_EXPORT_COMPILE_COMMANDS=ON ...

#]=======================================================================]

include_guard(GLOBAL)

find_package(IWYU QUIET)

if(IWYU_FOUND)
    message(VERBOSE "IWYU found: ${IWYU_EXECUTABLE}")
else()
    message(VERBOSE "IWYU not found")
endif()

#[=======================================================================[.rst:
Internal helper function to build IWYU command with flags.

Constructs the complete include-what-you-use command with mapping file
and additional arguments, with proper -Xiwyu prefixes for all flags.

Parameters
^^^^^^^^^^

``MAPPING_FILE``
  Optional path to IWYU mapping file (.imp format)

``ADDITIONAL_ARGS``
  Optional semicolon-separated list of IWYU flags (e.g., ``--no_fwd_decls;--keep_going``)

``RETCMD``
  Output variable to store the built command

Example
^^^^^^^

.. code-block:: cmake

  _IWYU_BuildCommand(
    "${MAPPING_FILE_PATH}"
    "no_fwd_decls;keep_going"
    result_cmd
  )

#]=======================================================================]
function(_IWYU_BuildCommand MAPPING_FILE ADDITIONAL_ARGS RETCMD)
    set(iwyu_command "${IWYU_EXECUTABLE}")

    if(MAPPING_FILE)
        list(
            APPEND iwyu_command
            "-Xiwyu"
            "--mapping_file=${MAPPING_FILE}"
        )
    endif()

    if(ADDITIONAL_ARGS)
        foreach(arg IN LISTS ADDITIONAL_ARGS)
            list(
                APPEND iwyu_command
                "-Xiwyu"
                "${arg}"
            )
        endforeach()
    endif()

    set(${RETCMD} "${iwyu_command}" PARENT_SCOPE)
endfunction()

#[=======================================================================[.rst:
Configure Include-What-You-Use (IWYU) globally for all C++ targets.

This function sets CMAKE_CXX_INCLUDE_WHAT_YOU_USE variable to enable IWYU
analysis during build. IWYU is C++-only; this function never sets C configuration.
By default, operates in advisory mode (missing IWYU tool produces only a warning).
Use STRICT flag to fail configuration if IWYU is not available.

Parameters
^^^^^^^^^^

``STATUS``
  Mandatory. ON to enable IWYU, OFF to disable it.

``STRICT``
  Optional. If specified, fails with fatal error if IWYU not found or mapping
  file missing. Without this flag (advisory mode), missing tool/file produces warning.

``MAPPING_FILE``
  Optional. Path to IWYU mapping file (.imp format). Passed to IWYU as
  ``-Xiwyu --mapping_file=<path>``. File existence is checked in strict mode.

``ADDITIONAL_ARGS``
  Optional. Semicolon-separated list of IWYU arguments.
  Each is automatically prefixed with -Xiwyu.
  Example: ``ADDITIONAL_ARGS "--no_fwd_decls;--keep_going;--check_also=<file>"``

``EXCLUDE_PATTERNS``
  Optional. Semicolon-separated list of path patterns to exclude
  (reserved for future use or target-level filtering).

Example
^^^^^^^

.. code-block:: cmake

  include(IWYU)

  # Advisory mode (default): doesn't break without IWYU
  IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
  )

  # With additional IWYU arguments
  IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--no_fwd_decls;--keep_going"
  )

  # Strict mode: fails without IWYU (ideal for CI)
  IWYU_Configure(
    STATUS ON
    STRICT
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
  )

  # Disable IWYU
  IWYU_Configure(STATUS OFF)

#]=======================================================================]
function(IWYU_Configure)
    set(options STRICT)
    set(oneValueArgs
        STATUS
        MAPPING_FILE
    )
    set(multiValueArgs
        ADDITIONAL_ARGS
        EXCLUDE_PATTERNS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT DEFINED ARG_STATUS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: STATUS must be specified")
    endif()

    # Validate STATUS parameter
    if(NOT ARG_STATUS MATCHES "^(ON|OFF|TRUE|FALSE|1|0)$")
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: STATUS must be one of: ON, OFF, TRUE, FALSE, 1, 0"
        )
    endif()

    if(ARG_STATUS STREQUAL "ON")
        if(IWYU_FOUND)
            # Validate mapping file if provided
            if(ARG_MAPPING_FILE)
                if(NOT EXISTS "${ARG_MAPPING_FILE}")
                    if(ARG_STRICT)
                        message(
                            FATAL_ERROR
                            "${CMAKE_CURRENT_FUNCTION}: MAPPING_FILE '${ARG_MAPPING_FILE}' does not exist"
                        )
                    else()
                        message(
                            VERBOSE
                            "${CMAKE_CURRENT_FUNCTION}: MAPPING_FILE '${ARG_MAPPING_FILE}' does not exist"
                        )
                        unset(ARG_MAPPING_FILE)
                    endif()
                endif()
            endif()

            # Build the IWYU command
            _IWYU_BuildCommand("${ARG_MAPPING_FILE}" "${ARG_ADDITIONAL_ARGS}" cmd)

            message(VERBOSE "IWYU_Configure: ${cmd}")
            set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE "${cmd}" CACHE INTERNAL "" FORCE)
        else()
            if(ARG_STRICT)
                message(
                    FATAL_ERROR
                    "${CMAKE_CURRENT_FUNCTION}: IWYU not found and STRICT mode enabled"
                )
            else()
                message(VERBOSE "${CMAKE_CURRENT_FUNCTION}: IWYU not found")
                set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE "" CACHE INTERNAL "" FORCE)
            endif()
        endif()
    else()
        set(CMAKE_CXX_INCLUDE_WHAT_YOU_USE "" CACHE INTERNAL "" FORCE)
    endif()
endfunction()

#[=======================================================================[.rst:
Configure IWYU for a specific C++ CMake target.

This function sets CXX_INCLUDE_WHAT_YOU_USE target property to enable IWYU
analysis for a particular C++ target. By default, operates in advisory mode
(missing IWYU tool produces only a warning). Use STRICT flag to enforce strict mode.

Parameters
^^^^^^^^^^

``TARGET``
  Mandatory. The CMake target to configure (must be a valid target).

``STATUS``
  Mandatory. ON to enable IWYU for target, OFF to disable it.

``STRICT``
  Optional. If specified, fails if IWYU not found or mapping file missing.
  Without this flag (advisory mode), produces only warnings for missing tool/file.
  Note: Target existence is always checked and fails immediately regardless of STRICT mode.

``MAPPING_FILE``
  Optional. Path to IWYU mapping file (.imp format) for this target.
  If STRICT mode and file doesn't exist, raises fatal error.

``ADDITIONAL_ARGS``
  Optional. Semicolon-separated list of IWYU arguments for this target.
  Each automatically prefixed with -Xiwyu.
  Example: ``ADDITIONAL_ARGS "--no_fwd_decls;--keep_going"``

``EXCLUDE_PATTERNS``
  Optional. Semicolon-separated list of path patterns to exclude
  (reserved for future use).

Example
^^^^^^^

.. code-block:: cmake

  add_library(core src/core.cpp)
  add_library(utils src/utils.cpp)

  # Enable IWYU for core library with mapping file
  IWYU_ConfigureTarget(
    TARGET core
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--no_fwd_decls"
  )

  # Disable IWYU for utils
  IWYU_ConfigureTarget(TARGET utils STATUS OFF)

  # Strict mode: fail if IWYU not found or mapping file missing
  IWYU_ConfigureTarget(
    TARGET nonexistent
    STATUS ON
    STRICT
  )

#]=======================================================================]
function(IWYU_ConfigureTarget)
    set(options STRICT)
    set(oneValueArgs
        TARGET
        STATUS
        MAPPING_FILE
    )
    set(multiValueArgs
        ADDITIONAL_ARGS
        EXCLUDE_PATTERNS
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_TARGET)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET must be specified")
    endif()

    if(NOT DEFINED ARG_STATUS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: STATUS must be specified")
    endif()

    # Validate STATUS parameter
    if(NOT ARG_STATUS MATCHES "^(ON|OFF|TRUE|FALSE|1|0)$")
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: STATUS must be one of: ON, OFF, TRUE, FALSE, 1, 0"
        )
    endif()

    if(NOT TARGET ${ARG_TARGET})
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Target '${ARG_TARGET}' does not exist")
    endif()

    if(ARG_STATUS STREQUAL "ON")
        if(IWYU_FOUND)
            # Validate mapping file if provided
            if(ARG_MAPPING_FILE)
                if(NOT EXISTS "${ARG_MAPPING_FILE}")
                    if(ARG_STRICT)
                        message(
                            FATAL_ERROR
                            "${CMAKE_CURRENT_FUNCTION}: MAPPING_FILE '${ARG_MAPPING_FILE}' does not exist"
                        )
                    else()
                        message(
                            VERBOSE
                            "${CMAKE_CURRENT_FUNCTION}: MAPPING_FILE '${ARG_MAPPING_FILE}' does not exist"
                        )
                        unset(ARG_MAPPING_FILE)
                    endif()
                endif()
            endif()

            # Build the IWYU command
            _IWYU_BuildCommand("${ARG_MAPPING_FILE}" "${ARG_ADDITIONAL_ARGS}" cmd)

            message(VERBOSE "IWYU_ConfigureTarget(${ARG_TARGET}): ${cmd}")
            set_target_properties(
                ${ARG_TARGET}
                PROPERTIES
                    CXX_INCLUDE_WHAT_YOU_USE
                        "${cmd}"
            )
        else()
            if(ARG_STRICT)
                message(
                    FATAL_ERROR
                    "${CMAKE_CURRENT_FUNCTION}: IWYU not found and STRICT mode enabled"
                )
            else()
                message(VERBOSE "${CMAKE_CURRENT_FUNCTION}: IWYU not found")
                set_target_properties(
                    ${ARG_TARGET}
                    PROPERTIES
                        CXX_INCLUDE_WHAT_YOU_USE
                            ""
                )
            endif()
        endif()
    else()
        set_target_properties(
            ${ARG_TARGET}
            PROPERTIES
                CXX_INCLUDE_WHAT_YOU_USE
                    ""
        )
    endif()
endfunction()
