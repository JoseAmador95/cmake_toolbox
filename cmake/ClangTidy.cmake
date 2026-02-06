# Distributed under the OSI-approved BSD 3-Clause License.
# See accompanying file LICENSE.txt for details.

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
  
  # Enable clang-tidy globally
  ClangTidy_Configure(STATUS ON)
  
  # Or configure per-target
  add_library(mylib src/lib.c)
  ClangTidy_ConfigureTarget(TARGET mylib STATUS ON)

#]=======================================================================]

include_guard(GLOBAL)

# ==============================================================================
# Find clang-tidy
# ==============================================================================

find_package(ClangTidy QUIET)

if(ClangTidy_FOUND)
    message(VERBOSE "ClangTidy found: ${ClangTidy_EXECUTABLE}")
else()
    message(VERBOSE "ClangTidy not found")
endif()

# ==============================================================================
# Cache Variables
# ==============================================================================

set(CLANG_TIDY_COMPILE_COMMANDS
    ${CMAKE_BINARY_DIR}/compile_commands.json
    CACHE FILEPATH
    "Path to compile_commands.json"
)

# ==============================================================================
# Include dependencies
# ==============================================================================

include(${CMAKE_CURRENT_LIST_DIR}/CompileCommands.cmake)

# ==============================================================================
# Internal Functions
# ==============================================================================

function(_ClangTidy_GetCommand TRIM RETCMD RETCOMPILECOMMANDS)
    set(output_file ${CLANG_TIDY_COMPILE_COMMANDS})

    if(TRIM AND JQ_EXECUTABLE)
        set(output_file ${CMAKE_CURRENT_BINARY_DIR}/compile_commands_trimmed/compile_commands.json)
        CompileCommands_Trim(INPUT ${CLANG_TIDY_COMPILE_COMMANDS} OUTPUT ${output_file})
    endif()

    message(VERBOSE "ClangTidy using compile commands: ${output_file}")
    set(${RETCMD} "${ClangTidy_EXECUTABLE};-p;${output_file}" PARENT_SCOPE)
    set(${RETCOMPILECOMMANDS} "${output_file}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# ClangTidy_Configure
# ==============================================================================
#
# Configure clang-tidy globally for all targets.
#
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

# ==============================================================================
# ClangTidy_ConfigureTarget
# ==============================================================================
#
# Configure clang-tidy for a specific target.
#
function(ClangTidy_ConfigureTarget)
    set(options TRIM_COMPILE_COMMANDS)
    set(oneValueArgs TARGET STATUS)
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
            C_CLANG_TIDY "${exe}"
            CXX_CLANG_TIDY "${exe}"
    )

    if(compilecommands)
        target_sources(${ARG_TARGET} PRIVATE ${compilecommands})
    endif()
endfunction()

# ==============================================================================
# Backward Compatibility Aliases
# ==============================================================================

function(set_clang_tidy)
    message(DEPRECATION "set_clang_tidy() is deprecated, use ClangTidy_Configure() instead")
    ClangTidy_Configure(${ARGN})
endfunction()

function(target_set_clang_tidy)
    message(DEPRECATION "target_set_clang_tidy() is deprecated, use ClangTidy_ConfigureTarget() instead")
    ClangTidy_ConfigureTarget(${ARGN})
endfunction()
