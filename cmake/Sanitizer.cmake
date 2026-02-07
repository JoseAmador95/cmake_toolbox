# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
Sanitizer
---------

CMake module for enabling compiler sanitizers on targets.

This module provides functions to add sanitizer instrumentation (AddressSanitizer,
UndefinedBehaviorSanitizer, LeakSanitizer) to CMake targets.

Cache Variables
^^^^^^^^^^^^^^^

``SANITIZER_FLAGS``
  Compiler/linker flags for sanitizer instrumentation.
  Default: ``-fsanitize=address,undefined,leak``

``SANITIZER_ENV_VARS``
  Environment variables for sanitizer runtime configuration.
  Default: ``ASAN_OPTIONS=detect_leaks=1:abort_on_error=1;UBSAN_OPTIONS=print_stacktrace=1``

Functions
^^^^^^^^^

.. command:: Sanitizer_AddToTarget

  Add sanitizer instrumentation to a target::

    Sanitizer_AddToTarget(
      TARGET <target>
      SCOPE <scope>
    )

  ``TARGET``
    The target to add sanitizer instrumentation to.

  ``SCOPE``
    The scope for compile options and link libraries (PUBLIC, PRIVATE, INTERFACE).

Example
^^^^^^^

.. code-block:: cmake

  include(Sanitizer)
  
  add_executable(my_test test.c)
  Sanitizer_AddToTarget(TARGET my_test SCOPE PRIVATE)

#]=======================================================================]

include_guard(GLOBAL)

# ==============================================================================
# Cache Variables
# ==============================================================================

set(SANITIZER_FLAGS
    -fsanitize=address,undefined,leak
    CACHE STRING
    "Sanitizer flags to use"
)

set(SANITIZER_ENV_VARS
    "ASAN_OPTIONS=detect_leaks=1:abort_on_error=1;UBSAN_OPTIONS=print_stacktrace=1"
    CACHE STRING
    "Sanitizer environment variables to use"
)

# ==============================================================================
# Sanitizer_AddToTarget
# ==============================================================================
#
# Add sanitizer instrumentation to a target.
#
# Parameters:
#   TARGET - The target to add sanitizer instrumentation to
#   SCOPE  - The scope for compile options and link libraries
#
function(Sanitizer_AddToTarget)
    set(options "")
    set(oneValueArgs TARGET SCOPE)
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_TARGET)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET must be specified")
    endif()

    if(NOT ARG_SCOPE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: SCOPE must be specified")
    endif()

    if(NOT TARGET ${ARG_TARGET})
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Target '${ARG_TARGET}' does not exist")
    endif()

    target_compile_options(
        ${ARG_TARGET}
        ${ARG_SCOPE}
        ${SANITIZER_FLAGS}
    )

    target_link_libraries(
        ${ARG_TARGET}
        ${ARG_SCOPE}
        ${SANITIZER_FLAGS}
    )

    set_target_properties(
        ${ARG_TARGET}
        PROPERTIES
            ENVIRONMENT "${SANITIZER_ENV_VARS}"
    )
endfunction()

# ==============================================================================
# Backward Compatibility Alias
# ==============================================================================

function(target_add_sanitizer _target _scope)
    message(DEPRECATION "target_add_sanitizer() is deprecated, use Sanitizer_AddToTarget() instead")
    Sanitizer_AddToTarget(TARGET ${_target} SCOPE ${_scope})
endfunction()
