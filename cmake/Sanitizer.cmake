# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
Sanitizer
---------

CMake module for enabling compiler sanitizers on targets.

This module provides functions to add sanitizer instrumentation (AddressSanitizer,
UndefinedBehaviorSanitizer, LeakSanitizer) to CMake targets with automatic
per-language compiler detection using generator expressions.

**This module handles mixed-compiler scenarios** - for example, a project with
C compiled by GCC and C++ compiled by MSVC will receive appropriate flags for
each language independently.

Supported Compilers & Sanitizers
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^^\n
Flags are applied automatically per language (C/CXX) based on compiler:

- **GNU (GCC)**: address, undefined, leak
- **Clang**: address, undefined, leak
- **AppleClang**: address, undefined (leak not supported on macOS)
- **MSVC**: address only (UBSan and LeakSanitizer not supported)
- **Clang-cl**: address only (detected via MSVC frontend variant)

Unsupported compilers are silently skipped (no flags applied).

Sanitizer Options
^^^^^^^^^^^^^^^^^^

Control which sanitizers are enabled via CMake options:

``ENABLE_SANITIZER_ADDRESS``
  Enable AddressSanitizer (ASAN). Default: ``ON``

``ENABLE_SANITIZER_UNDEFINED``
  Enable UndefinedBehaviorSanitizer (UBSAN). Default: ``ON``.
  Note: Not supported by MSVC.

``ENABLE_SANITIZER_LEAK``
  Enable LeakSanitizer (LSAN). Default: ``ON``.
  Note: Not supported by MSVC. May cause issues in threaded/forking code.

**Example:** To disable leak detection (useful in CI to speed up tests)::

  cmake -DENABLE_SANITIZER_LEAK=OFF ..

Cache Variables
^^^^^^^^^^^^^^^

``SANITIZER_COMPILE_FLAGS``
  Manual override for sanitizer compile flags.
  When empty (default), uses automatic per-language detection via generator expressions.
  Set this to provide custom flags for unsupported compilers.

``SANITIZER_LINK_FLAGS``
  Manual override for sanitizer link flags.
  When empty (default), uses automatic detection.
  Useful for advanced scenarios like static linking (``-static-libasan``).

``SANITIZER_ENV_VARS``
  Environment variables for sanitizer runtime configuration.
  Default: ``ASAN_OPTIONS=detect_leaks=1:abort_on_error=1;UBSAN_OPTIONS=print_stacktrace=1``
  Use with ``Sanitizer_ApplyEnvironmentToTests()``.

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

.. command:: Sanitizer_ApplyEnvironmentToTests

  Apply sanitizer runtime environment variables to CTest tests::

    Sanitizer_ApplyEnvironmentToTests(
      TESTS <test1> [<test2> ...]
      [ENVIRONMENT <env_var1> [<env_var2> ...]]
      [APPEND]
    )

  ``TESTS``
    Test names created with ``add_test()``.

  ``ENVIRONMENT``
    Optional environment list. Defaults to ``SANITIZER_ENV_VARS``.

  ``APPEND``
    Append to existing test environment instead of replacing it.

Example
^^^^^^^

.. code-block:: cmake

  include(Sanitizer)
  
  add_executable(my_test test.c)
  Sanitizer_AddToTarget(TARGET my_test SCOPE PRIVATE)

#]=======================================================================]

include_guard(GLOBAL)

# ==============================================================================
# Sanitizer Type Options
# ==============================================================================
option(ENABLE_SANITIZER_ADDRESS "Enable AddressSanitizer (ASAN)" ON)
option(ENABLE_SANITIZER_UNDEFINED "Enable UndefinedBehaviorSanitizer (UBSAN)" ON)
option(ENABLE_SANITIZER_LEAK "Enable LeakSanitizer (LSAN)" ON)

# ==============================================================================
# Compiler Compatibility Matrices
# ==============================================================================
# Define which sanitizers are supported by each compiler and their argument names

# C language compiler support matrix
if(CMAKE_C_COMPILER_ID MATCHES "^(GNU|Clang)$")
    set(_SUPPORTED_C_SANITIZERS "address;undefined;leak")
    set(_SANITIZER_C_ADDRESS_ARG "address")
    set(_SANITIZER_C_UNDEFINED_ARG "undefined")
    set(_SANITIZER_C_LEAK_ARG "leak")
elseif(CMAKE_C_COMPILER_ID STREQUAL "AppleClang")
    # AppleClang supports address and undefined but NOT leak sanitizer
    set(_SUPPORTED_C_SANITIZERS "address;undefined")
    set(_SANITIZER_C_ADDRESS_ARG "address")
    set(_SANITIZER_C_UNDEFINED_ARG "undefined")
    set(_SANITIZER_C_LEAK_ARG "")
elseif(CMAKE_C_COMPILER_ID STREQUAL "MSVC" OR CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    set(_SUPPORTED_C_SANITIZERS "address")
    set(_SANITIZER_C_ADDRESS_ARG "address")
    set(_SANITIZER_C_UNDEFINED_ARG "")
    set(_SANITIZER_C_LEAK_ARG "")
else()
    set(_SUPPORTED_C_SANITIZERS "")
endif()

# CXX language compiler support matrix
if(CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang)$")
    set(_SUPPORTED_CXX_SANITIZERS "address;undefined;leak")
    set(_SANITIZER_CXX_ADDRESS_ARG "address")
    set(_SANITIZER_CXX_UNDEFINED_ARG "undefined")
    set(_SANITIZER_CXX_LEAK_ARG "leak")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    # AppleClang supports address and undefined but NOT leak sanitizer
    set(_SUPPORTED_CXX_SANITIZERS "address;undefined")
    set(_SANITIZER_CXX_ADDRESS_ARG "address")
    set(_SANITIZER_CXX_UNDEFINED_ARG "undefined")
    set(_SANITIZER_CXX_LEAK_ARG "")
elseif(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    set(_SUPPORTED_CXX_SANITIZERS "address")
    set(_SANITIZER_CXX_ADDRESS_ARG "address")
    set(_SANITIZER_CXX_UNDEFINED_ARG "")
    set(_SANITIZER_CXX_LEAK_ARG "")
else()
    set(_SUPPORTED_CXX_SANITIZERS "")
endif()

# ==============================================================================
# Helper: Build sanitizer flags from enabled options
# ==============================================================================
# Constructs -fsanitize=<list> or /fsanitize=<list> based on enabled options
# that are supported by the compiler.
function(_sanitizer_build_flags SUPPORTED_LIST PREFIX IS_MSVC OUTPUT_VAR)
    set(_FLAGS "")

    list(
        FIND SUPPORTED_LIST
        "address"
        _address_idx
    )
    if(ENABLE_SANITIZER_ADDRESS AND NOT _address_idx EQUAL -1)
        string(APPEND _FLAGS "${${PREFIX}_ADDRESS_ARG},")
    endif()

    list(
        FIND SUPPORTED_LIST
        "undefined"
        _undefined_idx
    )
    if(ENABLE_SANITIZER_UNDEFINED AND NOT _undefined_idx EQUAL -1)
        string(APPEND _FLAGS "${${PREFIX}_UNDEFINED_ARG},")
    endif()

    list(
        FIND SUPPORTED_LIST
        "leak"
        _leak_idx
    )
    if(ENABLE_SANITIZER_LEAK AND NOT _leak_idx EQUAL -1)
        string(APPEND _FLAGS "${${PREFIX}_LEAK_ARG},")
    endif()

    # Remove trailing comma
    string(REGEX REPLACE ",$" "" _FLAGS "${_FLAGS}")

    # Prepend appropriate compiler flag prefix
    if(_FLAGS)
        if(IS_MSVC)
            string(PREPEND _FLAGS "/fsanitize=")
        else()
            string(PREPEND _FLAGS "-fsanitize=")
        endif()
    endif()

    set(${OUTPUT_VAR} "${_FLAGS}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# Compiler Flag Lookup Tables (LUT)
# ==============================================================================
# Determine if we're using MSVC-style compilers for C and CXX
set(_C_IS_MSVC OFF)
if(CMAKE_C_COMPILER_ID STREQUAL "MSVC" OR CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    set(_C_IS_MSVC ON)
endif()

set(_CXX_IS_MSVC OFF)
if(CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
    set(_CXX_IS_MSVC ON)
endif()

# Build C language flags (filters by enabled + supported sanitizers)
_sanitizer_build_flags(
    "${_SUPPORTED_C_SANITIZERS}"
    "_SANITIZER_C"
    "${_C_IS_MSVC}"
    _SANITIZER_C_FLAGS
)

# Build CXX language flags
_sanitizer_build_flags(
    "${_SUPPORTED_CXX_SANITIZERS}"
    "_SANITIZER_CXX"
    "${_CXX_IS_MSVC}"
    _SANITIZER_CXX_FLAGS
)

# Link flags: Merge supported sanitizers from both languages
set(_SUPPORTED_LINK_SANITIZERS "")
foreach(_SANITIZER IN LISTS _SUPPORTED_C_SANITIZERS _SUPPORTED_CXX_SANITIZERS)
    list(
        FIND _SUPPORTED_LINK_SANITIZERS
        "${_SANITIZER}"
        _link_sanitizer_idx
    )
    if(_link_sanitizer_idx EQUAL -1)
        list(APPEND _SUPPORTED_LINK_SANITIZERS "${_SANITIZER}")
    endif()
endforeach()

# For linking, use MSVC style only if both compilers are MSVC
set(_LINK_IS_MSVC OFF)
if(_C_IS_MSVC AND _CXX_IS_MSVC)
    set(_LINK_IS_MSVC ON)
endif()

set(_LINK_FLAGS "")
list(
    FIND _SUPPORTED_LINK_SANITIZERS
    "address"
    _link_address_idx
)
if(ENABLE_SANITIZER_ADDRESS AND NOT _link_address_idx EQUAL -1)
    string(APPEND _LINK_FLAGS "address,")
endif()
list(
    FIND _SUPPORTED_LINK_SANITIZERS
    "undefined"
    _link_undefined_idx
)
if(ENABLE_SANITIZER_UNDEFINED AND NOT _link_undefined_idx EQUAL -1)
    string(APPEND _LINK_FLAGS "undefined,")
endif()
list(
    FIND _SUPPORTED_LINK_SANITIZERS
    "leak"
    _link_leak_idx
)
if(ENABLE_SANITIZER_LEAK AND NOT _link_leak_idx EQUAL -1)
    string(APPEND _LINK_FLAGS "leak,")
endif()

string(REGEX REPLACE ",$" "" _LINK_FLAGS "${_LINK_FLAGS}")
if(_LINK_FLAGS)
    if(_LINK_IS_MSVC)
        string(PREPEND _LINK_FLAGS "/fsanitize=")
    else()
        string(PREPEND _LINK_FLAGS "-fsanitize=")
    endif()
endif()
set(_SANITIZER_LINK_FLAGS "${_LINK_FLAGS}")

# ==============================================================================
# Cache Variables
# ==============================================================================

# Manual overrides: If set, bypass automatic detection
set(SANITIZER_COMPILE_FLAGS
    ""
    CACHE STRING
    "Override sanitizer compile flags (if empty, uses compiler-specific defaults per language)"
)

set(SANITIZER_LINK_FLAGS
    ""
    CACHE STRING
    "Override sanitizer link flags (if empty, uses automatic detection)"
)

set(_SANITIZER_ASAN_OPTIONS "detect_leaks=1:abort_on_error=1")
if(CMAKE_C_COMPILER_ID STREQUAL "AppleClang" OR CMAKE_CXX_COMPILER_ID STREQUAL "AppleClang")
    set(_SANITIZER_ASAN_OPTIONS "abort_on_error=1")
endif()

set(SANITIZER_ENV_VARS
    "ASAN_OPTIONS=${_SANITIZER_ASAN_OPTIONS};UBSAN_OPTIONS=print_stacktrace=1"
    CACHE STRING
    "Sanitizer environment variables to use"
)
unset(_SANITIZER_ASAN_OPTIONS)

set(_SANITIZER_MSVC_ASAN_DIR "")
if(_LINK_IS_MSVC AND ENABLE_SANITIZER_ADDRESS)
    set(_SANITIZER_VS_INSTALL_DIR "")
    if(DEFINED CMAKE_VS_INSTALL_DIR AND EXISTS "${CMAKE_VS_INSTALL_DIR}")
        set(_SANITIZER_VS_INSTALL_DIR "${CMAKE_VS_INSTALL_DIR}")
    elseif(DEFINED ENV{VSINSTALLDIR} AND EXISTS "$ENV{VSINSTALLDIR}")
        set(_SANITIZER_VS_INSTALL_DIR "$ENV{VSINSTALLDIR}")
    endif()

    if(_SANITIZER_VS_INSTALL_DIR)
        file(GLOB _SANITIZER_MSVC_TOOLSET_DIRS "${_SANITIZER_VS_INSTALL_DIR}/VC/Tools/MSVC/*")
        list(SORT _SANITIZER_MSVC_TOOLSET_DIRS DESC)
        foreach(_SANITIZER_TOOLSET_DIR IN LISTS _SANITIZER_MSVC_TOOLSET_DIRS)
            file(
                GLOB _SANITIZER_ASAN_DLLS
                "${_SANITIZER_TOOLSET_DIR}/bin/Host*/*/clang_rt.asan_dynamic-x86_64.dll"
            )
            if(_SANITIZER_ASAN_DLLS)
                list(GET _SANITIZER_ASAN_DLLS 0 _SANITIZER_ASAN_DLL)
                get_filename_component(_SANITIZER_MSVC_ASAN_DIR "${_SANITIZER_ASAN_DLL}" DIRECTORY)
                break()
            endif()
        endforeach()
    endif()
endif()

if(_SANITIZER_MSVC_ASAN_DIR)
    set(_SANITIZER_HAS_PATH_ENV FALSE)
    foreach(_SANITIZER_ENV_ENTRY IN LISTS SANITIZER_ENV_VARS)
        if(_SANITIZER_ENV_ENTRY MATCHES "^PATH=")
            set(_SANITIZER_HAS_PATH_ENV TRUE)
            break()
        endif()
    endforeach()

    if(NOT _SANITIZER_HAS_PATH_ENV)
        set(_SANITIZER_ENV_PATH_VALUE "$ENV{PATH}")
        string(REPLACE ";" "\\;" _SANITIZER_ENV_PATH_VALUE "${_SANITIZER_ENV_PATH_VALUE}")
        set(_SANITIZER_ASAN_PATH_ENTRY
            "PATH=${_SANITIZER_MSVC_ASAN_DIR}\\;${_SANITIZER_ENV_PATH_VALUE}"
        )
        list(APPEND SANITIZER_ENV_VARS "${_SANITIZER_ASAN_PATH_ENTRY}")
        unset(_SANITIZER_ENV_PATH_VALUE)
        unset(_SANITIZER_ASAN_PATH_ENTRY)
    endif()
    unset(_SANITIZER_HAS_PATH_ENV)
endif()

unset(_SANITIZER_MSVC_ASAN_DIR)
unset(_SANITIZER_MSVC_TOOLSET_DIRS)
unset(_SANITIZER_TOOLSET_DIR)
unset(_SANITIZER_ASAN_DLLS)
unset(_SANITIZER_ASAN_DLL)
unset(_SANITIZER_VS_INSTALL_DIR)

# Mark internal LUT and compatibility variables as advanced (not for user modification)
mark_as_advanced(
    _SUPPORTED_C_SANITIZERS
    _SANITIZER_C_ADDRESS_ARG
    _SANITIZER_C_UNDEFINED_ARG
    _SANITIZER_C_LEAK_ARG
    _SUPPORTED_CXX_SANITIZERS
    _SANITIZER_CXX_ADDRESS_ARG
    _SANITIZER_CXX_UNDEFINED_ARG
    _SANITIZER_CXX_LEAK_ARG
    _SUPPORTED_LINK_SANITIZERS
    _C_IS_MSVC
    _CXX_IS_MSVC
    _LINK_IS_MSVC
    _SANITIZER_C_FLAGS
    _SANITIZER_CXX_FLAGS
    _SANITIZER_LINK_FLAGS
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
    set(oneValueArgs
        TARGET
        SCOPE
    )
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

    # Apply compile options: manual override or automatic per-language detection
    if(SANITIZER_COMPILE_FLAGS)
        target_compile_options(
            ${ARG_TARGET}
            ${ARG_SCOPE}
            ${SANITIZER_COMPILE_FLAGS}
        )
    else()
        # Apply per-language flags using LUT-determined values and generator expressions
        # This handles mixed compiler scenarios (e.g., GCC for C, Clang for CXX)
        if(_SANITIZER_C_FLAGS)
            target_compile_options(
                ${ARG_TARGET}
                ${ARG_SCOPE}
                $<$<COMPILE_LANGUAGE:C>:${_SANITIZER_C_FLAGS}>
            )
        endif()

        if(_SANITIZER_CXX_FLAGS)
            target_compile_options(
                ${ARG_TARGET}
                ${ARG_SCOPE}
                $<$<COMPILE_LANGUAGE:CXX>:${_SANITIZER_CXX_FLAGS}>
            )
        endif()
    endif()

    # Apply link options: manual override or automatic detection
    if(SANITIZER_LINK_FLAGS)
        target_link_options(
            ${ARG_TARGET}
            ${ARG_SCOPE}
            ${SANITIZER_LINK_FLAGS}
        )
    else()
        # Link options: Single set determined by LUT logic
        if(_SANITIZER_LINK_FLAGS)
            target_link_options(
                ${ARG_TARGET}
                ${ARG_SCOPE}
                ${_SANITIZER_LINK_FLAGS}
            )
        endif()
    endif()
endfunction()

# ==============================================================================
# Sanitizer_ApplyEnvironmentToTests
# ==============================================================================
#
# Apply sanitizer runtime environment variables to CTest tests.
#
# Parameters:
#   TESTS       - CTest names to update
#   ENVIRONMENT - Optional env list (defaults to SANITIZER_ENV_VARS)
#   APPEND      - Append env values instead of replacing existing values
#
function(Sanitizer_ApplyEnvironmentToTests)
    set(options APPEND)
    set(oneValueArgs "")
    set(multiValueArgs
        TESTS
        ENVIRONMENT
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_TESTS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TESTS must be specified")
    endif()

    foreach(test_name IN LISTS ARG_TESTS)
        if(NOT TEST "${test_name}")
            message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Test '${test_name}' does not exist")
        endif()
    endforeach()

    set(_SANITIZER_TEST_ENV "${SANITIZER_ENV_VARS}")
    if(ARG_ENVIRONMENT)
        set(_SANITIZER_TEST_ENV "${ARG_ENVIRONMENT}")
    endif()

    if(ARG_APPEND)
        foreach(test_name IN LISTS ARG_TESTS)
            get_test_property(${test_name} ENVIRONMENT _SANITIZER_CURRENT_ENV)
            if(_SANITIZER_CURRENT_ENV STREQUAL "_SANITIZER_CURRENT_ENV-NOTFOUND")
                set(_SANITIZER_CURRENT_ENV "")
            endif()

            set(_SANITIZER_MERGED_ENV "${_SANITIZER_CURRENT_ENV}")
            if(_SANITIZER_MERGED_ENV)
                list(APPEND _SANITIZER_MERGED_ENV ${_SANITIZER_TEST_ENV})
            else()
                set(_SANITIZER_MERGED_ENV "${_SANITIZER_TEST_ENV}")
            endif()

            set_property(
                TEST
                    ${test_name}
                PROPERTY
                    ENVIRONMENT
                        "${_SANITIZER_MERGED_ENV}"
            )
        endforeach()
    else()
        set_property(
            TEST
                ${ARG_TESTS}
            PROPERTY
                ENVIRONMENT
                    "${_SANITIZER_TEST_ENV}"
        )
    endif()
endfunction()

# ==============================================================================
# Backward Compatibility Alias
# ==============================================================================

function(target_add_sanitizer _target _scope)
    message(DEPRECATION "target_add_sanitizer() is deprecated, use Sanitizer_AddToTarget() instead")
    Sanitizer_AddToTarget(TARGET ${_target} SCOPE ${_scope})
endfunction()
