# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
ClangTidy
---------

CMake module for configuring clang-tidy static analysis.

This module provides functions to configure clang-tidy for CMake targets,
either globally or per-target.

Dependencies
^^^^^^^^^^^^

This module uses ``find_package(ClangTidy)`` to locate the clang-tidy executable.

Cache Variables
^^^^^^^^^^^^^^^

``CLANG_TIDY_COMPILE_COMMANDS``
  Path to compile_commands.json file.
  Default: ``${CMAKE_BINARY_DIR}/compile_commands.json``

Notes
^^^^^

When clang-tidy encounters unknown compiler flags (e.g., GCC-specific flags
when using a GCC-generated compile_commands.json), this module's wrapper
script will detect and report them with suggestions for adding to
COMPILE_COMMANDS_TRIM_BLACKLIST.

Example output::

  ClangTidy: clang-tidy reported 3 unknown compiler flag(s):
    - '-fmodules-ts'
    - '-mcpu=cortex-m7'

  Consider adding to COMPILE_COMMANDS_TRIM_BLACKLIST:
    set(COMPILE_COMMANDS_TRIM_BLACKLIST "^-fmodules-ts$;^-mcpu=.*")

Functions
^^^^^^^^^

.. command:: ClangTidy_Configure

  Configure clang-tidy globally for all targets::

    ClangTidy_Configure(
      STATUS <ON|OFF>
      [TRIM_COMPILE_COMMANDS]
    )

  ``STATUS``
    Enable (ON) or disable (OFF) clang-tidy globally.

  ``TRIM_COMPILE_COMMANDS``
    If specified, trim compile_commands.json to only include relevant entries.
    This removes flags incompatible with clang-tidy and preserves only flags
    needed for static analysis (includes, defines, standard, etc.).

.. command:: ClangTidy_ConfigureTarget

  Configure clang-tidy for a specific target::

    ClangTidy_ConfigureTarget(
      TARGET <target>
      STATUS <ON|OFF>
      [TRIM_COMPILE_COMMANDS]
    )

  ``TARGET``
    The target to configure clang-tidy for.

  ``STATUS``
    Enable (ON) or disable (OFF) clang-tidy for the target.

  ``TRIM_COMPILE_COMMANDS``
    If specified, trim compile_commands.json to only include relevant entries.

Example
^^^^^^^

.. code-block:: cmake

  include(ClangTidy)

  # Enable clang-tidy globally with trimmed compile commands
  ClangTidy_Configure(STATUS ON TRIM_COMPILE_COMMANDS)

  # Or configure per-target
  add_library(mylib src/lib.c)
  ClangTidy_ConfigureTarget(TARGET mylib STATUS ON TRIM_COMPILE_COMMANDS)

#]=======================================================================]

include_guard(GLOBAL)

find_package(ClangTidy QUIET)

if(ClangTidy_FOUND)
    message(VERBOSE "ClangTidy found: ${ClangTidy_EXECUTABLE}")
else()
    message(VERBOSE "ClangTidy not found")
endif()

set(CLANG_TIDY_COMPILE_COMMANDS
    ${CMAKE_BINARY_DIR}/compile_commands.json
    CACHE FILEPATH
    "Path to compile_commands.json"
)

include(${CMAKE_CURRENT_LIST_DIR}/CompileCommands.cmake)

function(_ClangTidy_GetCommand TRIM RETCMD RETCOMPILECOMMANDS)
    set(output_file ${CLANG_TIDY_COMPILE_COMMANDS})
    set(use_trim ${TRIM})

    if(DEFINED COMPILECOMMANDS_AVAILABLE AND NOT COMPILECOMMANDS_AVAILABLE)
        if(use_trim)
            message(STATUS "ClangTidy: compile command trimming is unavailable on this generator")
        endif()
        set(use_trim FALSE)
    endif()

    if(use_trim)
        set(output_file ${CMAKE_CURRENT_BINARY_DIR}/compile_commands_trimmed/compile_commands.json)
        CompileCommands_Trim(INPUT ${CLANG_TIDY_COMPILE_COMMANDS} OUTPUT ${output_file})
    endif()

    message(VERBOSE "ClangTidy using compile commands: ${output_file}")

    if(ClangTidy_FOUND)
        set(wrapper_script "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/internal/ClangTidyWrapper.cmake")
        set(${RETCMD}
            "${CMAKE_COMMAND};-DClangTidy_EXECUTABLE=${ClangTidy_EXECUTABLE};-P;${wrapper_script};--;${ClangTidy_EXECUTABLE};-p;${output_file}"
            PARENT_SCOPE
        )
    else()
        set(${RETCMD} "" PARENT_SCOPE)
    endif()

    if(use_trim)
        set(${RETCOMPILECOMMANDS} "${output_file}" PARENT_SCOPE)
    elseif(EXISTS "${output_file}")
        set(${RETCOMPILECOMMANDS} "${output_file}" PARENT_SCOPE)
    else()
        set(${RETCOMPILECOMMANDS} "" PARENT_SCOPE)
    endif()
endfunction()

function(ClangTidy_Configure)
    set(options TRIM_COMPILE_COMMANDS)
    set(oneValueArgs STATUS)
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(ClangTidy_FOUND AND ARG_STATUS)
        _ClangTidy_GetCommand(${ARG_TRIM_COMPILE_COMMANDS} cmd compilecommands)
        set(CMAKE_CXX_CLANG_TIDY "${cmd}" CACHE INTERNAL "" FORCE)
        set(CMAKE_C_CLANG_TIDY "${cmd}" CACHE INTERNAL "" FORCE)
    else()
        set(CMAKE_CXX_CLANG_TIDY "" CACHE INTERNAL "" FORCE)
        set(CMAKE_C_CLANG_TIDY "" CACHE INTERNAL "" FORCE)
    endif()
endfunction()

function(ClangTidy_ConfigureTarget)
    set(options TRIM_COMPILE_COMMANDS)
    set(oneValueArgs
        TARGET
        STATUS
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_TARGET)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET must be specified")
    endif()

    if(NOT TARGET ${ARG_TARGET})
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Target '${ARG_TARGET}' does not exist")
    endif()

    if(ClangTidy_FOUND AND ARG_STATUS)
        _ClangTidy_GetCommand(${ARG_TRIM_COMPILE_COMMANDS} exe compilecommands)
    else()
        set(exe "")
    endif()

    set_target_properties(
        ${ARG_TARGET}
        PROPERTIES
            C_CLANG_TIDY
                "${exe}"
            CXX_CLANG_TIDY
                "${exe}"
    )

    if(compilecommands)
        target_sources(${ARG_TARGET} PRIVATE ${compilecommands})
    endif()
endfunction()
