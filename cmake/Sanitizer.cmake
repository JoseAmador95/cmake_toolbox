# Distributed under the OSI-approved BSD 3-Clause License.
# See accompanying file LICENSE.txt for details.

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

    Sanitizer_AddToTarget(<target> <scope>)

  ``<target>``
    The target to add sanitizer instrumentation to.

  ``<scope>``
    The scope for compile options and link libraries (PUBLIC, PRIVATE, INTERFACE).

Example
^^^^^^^

.. code-block:: cmake

  include(Sanitizer)
  
  add_executable(my_test test.c)
  Sanitizer_AddToTarget(my_test PRIVATE)

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
function(Sanitizer_AddToTarget TARGET SCOPE)
    if(NOT TARGET ${TARGET})
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Target '${TARGET}' does not exist")
    endif()

    target_compile_options(
        ${TARGET}
        ${SCOPE}
        ${SANITIZER_FLAGS}
    )

    target_link_libraries(
        ${TARGET}
        ${SCOPE}
        ${SANITIZER_FLAGS}
    )

    set_target_properties(
        ${TARGET}
        PROPERTIES
            ENVIRONMENT "${SANITIZER_ENV_VARS}"
    )
endfunction()

# ==============================================================================
# Backward Compatibility Alias
# ==============================================================================

function(target_add_sanitizer _target _scope)
    message(DEPRECATION "target_add_sanitizer() is deprecated, use Sanitizer_AddToTarget() instead")
    Sanitizer_AddToTarget(${_target} ${_scope})
endfunction()
