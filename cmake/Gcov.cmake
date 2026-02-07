# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
Gcov
----

CMake module for enabling code coverage instrumentation using gcov/gcovr.

This module provides functions to add coverage instrumentation to CMake targets
and custom targets to generate coverage reports. Compiler detection is automatic
per language using generator expressions.

**This module handles mixed-compiler scenarios** - for example, a project with
C compiled by GCC and C++ compiled by Clang will receive ``--coverage`` for both,
while C with GCC and C++ with MSVC will only instrument the C code.

Supported Compilers
^^^^^^^^^^^^^^^^^^^

Flags are applied automatically per language (C/CXX) based on compiler:

- **GNU (GCC)**: ``--coverage`` (compile and link)
- **Clang**: ``--coverage`` (compile and link)
- **AppleClang**: ``--coverage`` (compile and link)
- **MSVC**: Not supported (gcov/gcovr are GCC-specific tools)
- **Clang-cl**: Not supported (uses MSVC ABI, incompatible with gcov)

**Note:** MSVC does not support gcov/gcovr. For coverage on MSVC, use:

- **Visual Studio Code Coverage** (Enterprise edition)
- **OpenCppCoverage** (free third-party tool for MSVC)

Unsupported compilers trigger a warning at configuration time and are skipped (no flags applied).
To override automatic detection or suppress warnings, set ``GCOV_COMPILE_FLAGS`` and
``GCOV_LINK_FLAGS`` cache variables explicitly.

Configuration Modes
^^^^^^^^^^^^^^^^^^^

This module supports two configuration modes:

**SCHEMA Mode** (default when gcovr version is supported):
  Configuration is managed through CMake cache variables (``GCOVR_*``).
  A configuration file is auto-generated from these variables.
  No external config file is required.

**CONFIG_FILE Mode** (fallback for unsupported gcovr versions):
  Uses an external configuration file specified by ``GCOVR_CONFIG_FILE``.

Dependencies
^^^^^^^^^^^^

This module requires gcovr to be installed. Use ``find_package(Gcovr)`` before
including this module, or let the module find it automatically.

Cache Variables (SCHEMA Mode)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When in SCHEMA mode, the following variables control gcovr behavior.
See ``cmake/schemas/gcovr-<version>.cmake`` for the complete list.

``GCOVR_FAIL_UNDER_LINE``
  Minimum line coverage percentage (0-100). Default: 0

``GCOVR_FAIL_UNDER_BRANCH``
  Minimum branch coverage percentage (0-100). Default: 0

``GCOVR_HTML_HIGH_THRESHOLD``
  High coverage threshold for HTML reports. Default: 95

``GCOVR_HTML_MEDIUM_THRESHOLD``
  Medium coverage threshold for HTML reports. Default: 85

``GCOVR_EXCLUDE``
  Semicolon-separated list of regex patterns to exclude files.

``GCOVR_FILTER``
  Semicolon-separated list of regex patterns to include files.

``GCOVR_OUTPUT_FORMATS``
  Semicolon-separated list of output formats (html, xml, json, cobertura, lcov).

Cache Variables (Both Modes)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^

``GCOVR_CONFIG_FILE``
  Path to gcovr configuration file.
  Only required in CONFIG_FILE mode.
  In SCHEMA mode, this is auto-generated.

``GCOVR_OUTPUT_DIR``
  Directory for coverage output files.
  Default: ``${CMAKE_CURRENT_BINARY_DIR}/coverage``

``GCOVR_ROOT_DIR``
  Root directory for coverage analysis.
  Default: ``${CMAKE_SOURCE_DIR}``

``GCOV_COMPILE_FLAGS``
  Manual override for coverage compile flags.
  When empty (default), uses automatic per-language detection (``--coverage`` for GNU/Clang).
  Set this to provide custom flags for unsupported compilers or advanced scenarios.

``GCOV_LINK_FLAGS``
  Manual override for coverage link flags.
  When empty (default), uses automatic detection (``--coverage`` for GNU/Clang).
  Useful for advanced scenarios like static linking (``-static-libgcov``).

Functions
^^^^^^^^^

.. command:: Gcov_AddToTarget

  Add coverage instrumentation to a target::

    Gcov_AddToTarget(<target> <scope>)

  ``<target>``
    The target to add coverage instrumentation to.

  ``<scope>``
    The scope for compile options and link libraries (PUBLIC, PRIVATE, INTERFACE).

.. command:: Gcovr_Initialize

  Initialize gcovr configuration (called automatically on first use)::

    Gcovr_Initialize()

  Detects gcovr version and sets up appropriate configuration mode.

Targets
^^^^^^^

``gcovr``
  Custom target to generate coverage reports. Always prints text summary.
  Generates all formats specified in ``GCOVR_OUTPUT_FORMATS`` (html, xml, json, lcov, csv, coveralls).

Example
^^^^^^^

.. code-block:: cmake

  include(Gcov)
  
  # Configure coverage thresholds via CMake (SCHEMA mode)
  set(GCOVR_FAIL_UNDER_LINE 80 CACHE STRING "" FORCE)
  set(GCOVR_EXCLUDE "test;build" CACHE STRING "" FORCE)
  
  add_executable(my_test test.c)
  Gcov_AddToTarget(my_test PRIVATE)
  
  # Run tests and generate report:
  # cmake --build . --target my_test
  # ctest
  # cmake --build . --target gcovr_html

#]=======================================================================]

include_guard(GLOBAL)

# ==============================================================================
# Compiler Flag Lookup Tables (LUT)
# ==============================================================================
# Map compiler IDs to appropriate coverage flags per language
# Coverage (--coverage) is only supported by GNU/Clang compilers

# C compiler flags
if(CMAKE_C_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
    set(_GCOV_C_COMPILE_FLAGS --coverage)
    set(_GCOV_C_LINK_FLAGS --coverage)
elseif((CMAKE_C_COMPILER_ID STREQUAL "MSVC" OR CMAKE_C_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC") AND NOT GCOV_COMPILE_FLAGS)
    message(WARNING "Gcov: C compiler '${CMAKE_C_COMPILER_ID}' does not support gcov/gcovr. "
                    "For MSVC coverage, use Visual Studio Code Coverage or OpenCppCoverage instead. "
                    "Or set GCOV_COMPILE_FLAGS and GCOV_LINK_FLAGS to use a custom tool.")
    set(_GCOV_C_COMPILE_FLAGS "")
    set(_GCOV_C_LINK_FLAGS "")
else()
    set(_GCOV_C_COMPILE_FLAGS "")
    set(_GCOV_C_LINK_FLAGS "")
endif()

# CXX compiler flags
if(CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
    set(_GCOV_CXX_COMPILE_FLAGS --coverage)
    set(_GCOV_CXX_LINK_FLAGS --coverage)
elseif((CMAKE_CXX_COMPILER_ID STREQUAL "MSVC" OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC") AND NOT GCOV_COMPILE_FLAGS)
    message(WARNING "Gcov: C++ compiler '${CMAKE_CXX_COMPILER_ID}' does not support gcov/gcovr. "
                    "For MSVC coverage, use Visual Studio Code Coverage or OpenCppCoverage instead. "
                    "Or set GCOV_COMPILE_FLAGS and GCOV_LINK_FLAGS to use a custom tool.")
    set(_GCOV_CXX_COMPILE_FLAGS "")
    set(_GCOV_CXX_LINK_FLAGS "")
else()
    set(_GCOV_CXX_COMPILE_FLAGS "")
    set(_GCOV_CXX_LINK_FLAGS "")
endif()

# Link flags: Use --coverage if any compiler supports it
if(CMAKE_C_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$" OR CMAKE_CXX_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
    set(_GCOV_LINK_FLAGS --coverage)
else()
    set(_GCOV_LINK_FLAGS "")
endif()

# ==============================================================================
# Find Dependencies
# ==============================================================================

find_package(Gcovr REQUIRED)
include(GcovrSchema)

# ==============================================================================
# Internal State Variables
# ==============================================================================

set(_GCOVR_CONFIG_MODE
    ""
    CACHE INTERNAL
    "Gcovr configuration mode: SCHEMA or CONFIG_FILE"
)

set(_GCOVR_SCHEMA_VERSION
    ""
    CACHE INTERNAL
    "Detected gcovr schema version"
)

set(_GCOVR_INITIALIZED
    FALSE
    CACHE INTERNAL
    "Whether Gcovr module has been initialized"
)

# ==============================================================================
# Cache Variables (preserved from original + new)
# ==============================================================================

set(GCOVR_CONFIG_FILE
    ""
    CACHE FILEPATH
    "Path to gcovr configuration file (optional in SCHEMA mode)"
)

set(GCOVR_OUTPUT_DIR
    "${CMAKE_CURRENT_BINARY_DIR}/coverage"
    CACHE PATH
    "Directory for coverage output files"
)

set(GCOVR_ROOT_DIR
    "${CMAKE_SOURCE_DIR}"
    CACHE PATH
    "Root directory for coverage analysis"
)

# Manual overrides: If set, bypass automatic detection
set(GCOV_COMPILE_FLAGS
    ""
    CACHE STRING
    "Override coverage compile flags (if empty, uses compiler-specific defaults per language)"
)

set(GCOV_LINK_FLAGS
    ""
    CACHE STRING
    "Override coverage link flags (if empty, uses automatic detection)"
)

# Mark internal LUT variables as advanced (not for user modification)
mark_as_advanced(_GCOV_C_COMPILE_FLAGS _GCOV_C_LINK_FLAGS _GCOV_CXX_COMPILE_FLAGS _GCOV_CXX_LINK_FLAGS _GCOV_LINK_FLAGS)

# Backward compatibility alias
set(GCOV_OUTPUT_FILE
    "${GCOVR_OUTPUT_DIR}/results.html"
    CACHE FILEPATH
    "Path to coverage output file (deprecated, use GCOVR_OUTPUT_DIR)"
)
mark_as_advanced(GCOV_OUTPUT_FILE)

# ==============================================================================
# Gcovr_Initialize
# ==============================================================================
#
# Initialize gcovr configuration by detecting version and setting up
# the appropriate configuration mode (SCHEMA or CONFIG_FILE).
#
function(Gcovr_Initialize)
    if(_GCOVR_INITIALIZED)
        return()
    endif()

    # Create output directory
    file(MAKE_DIRECTORY "${GCOVR_OUTPUT_DIR}")

    # Check if user provided a config file explicitly
    if(GCOVR_CONFIG_FILE AND EXISTS "${GCOVR_CONFIG_FILE}")
        set(_GCOVR_CONFIG_MODE "CONFIG_FILE" CACHE INTERNAL "" FORCE)
        set(_GCOVR_INITIALIZED TRUE CACHE INTERNAL "" FORCE)
        message(STATUS "Gcovr_Initialize: Using provided config file: ${GCOVR_CONFIG_FILE}")
        return()
    endif()

    # Try to detect version and use SCHEMA mode
    GcovrSchema_DetectVersion("${Gcovr_EXECUTABLE}" DETECTED_VERSION)

    if(DETECTED_VERSION)
        set(_GCOVR_SCHEMA_VERSION "${DETECTED_VERSION}" CACHE INTERNAL "" FORCE)
        set(_GCOVR_CONFIG_MODE "SCHEMA" CACHE INTERNAL "" FORCE)
        
        # Load schema defaults
        GcovrSchema_SetDefaults("${DETECTED_VERSION}")
        
        message(STATUS "Gcovr_Initialize: Using SCHEMA mode with gcovr ${DETECTED_VERSION}")
    else()
        set(_GCOVR_CONFIG_MODE "CONFIG_FILE" CACHE INTERNAL "" FORCE)
        
        # In CONFIG_FILE mode without a file, check for default location
        set(DEFAULT_CONFIG "${CMAKE_SOURCE_DIR}/gcovr.cfg")
        if(EXISTS "${DEFAULT_CONFIG}")
            set(GCOVR_CONFIG_FILE "${DEFAULT_CONFIG}" CACHE FILEPATH "" FORCE)
            message(STATUS "Gcovr_Initialize: Found config file at ${DEFAULT_CONFIG}")
        else()
            message(WARNING 
                "Gcovr_Initialize: Unsupported gcovr version and no config file found.\n"
                "Please either:\n"
                "  1. Update to a supported gcovr version (see GcovrSchema_GetSupportedVersions())\n"
                "  2. Provide a config file via GCOVR_CONFIG_FILE\n"
                "  3. Create ${DEFAULT_CONFIG}"
            )
        endif()
    endif()

    set(_GCOVR_INITIALIZED TRUE CACHE INTERNAL "" FORCE)
endfunction()

# ==============================================================================
# _Gcovr_EnsureInitialized (Internal)
# ==============================================================================
#
# Ensure Gcovr is initialized before use
#
macro(_Gcovr_EnsureInitialized)
    if(NOT _GCOVR_INITIALIZED)
        Gcovr_Initialize()
    endif()
endmacro()

# ==============================================================================
# _Gcovr_GetConfigFile (Internal)
# ==============================================================================
#
# Get the configuration file path, generating it if in SCHEMA mode
#
# Parameters:
#   OUTPUT_VAR - Variable to store the config file path
#
function(_Gcovr_GetConfigFile OUTPUT_VAR)
    _Gcovr_EnsureInitialized()

    if(_GCOVR_CONFIG_MODE STREQUAL "SCHEMA")
        # Generate config file from cached variables
        set(GENERATED_CONFIG "${GCOVR_OUTPUT_DIR}/gcovr_generated.cfg")
        GcovrSchema_GenerateConfigFile("${GENERATED_CONFIG}")
        set(${OUTPUT_VAR} "${GENERATED_CONFIG}" PARENT_SCOPE)
    else()
        # Use provided config file
        if(NOT GCOVR_CONFIG_FILE OR NOT EXISTS "${GCOVR_CONFIG_FILE}")
            message(FATAL_ERROR 
                "_Gcovr_GetConfigFile: CONFIG_FILE mode requires GCOVR_CONFIG_FILE to be set "
                "and point to an existing file. Current value: '${GCOVR_CONFIG_FILE}'"
            )
        endif()
        set(${OUTPUT_VAR} "${GCOVR_CONFIG_FILE}" PARENT_SCOPE)
    endif()
endfunction()

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

    # Apply compile options: manual override or automatic per-language detection
    if(GCOV_COMPILE_FLAGS)
        target_compile_options(
            ${TARGET}
            ${SCOPE}
            ${GCOV_COMPILE_FLAGS}
        )
    else()
        # Apply per-language flags using LUT-determined values and generator expressions
        # This handles mixed compiler scenarios (e.g., GCC for C, Clang for CXX)
        if(_GCOV_C_COMPILE_FLAGS)
            target_compile_options(
                ${TARGET}
                ${SCOPE}
                $<$<COMPILE_LANGUAGE:C>:${_GCOV_C_COMPILE_FLAGS}>
            )
        endif()
        
        if(_GCOV_CXX_COMPILE_FLAGS)
            target_compile_options(
                ${TARGET}
                ${SCOPE}
                $<$<COMPILE_LANGUAGE:CXX>:${_GCOV_CXX_COMPILE_FLAGS}>
            )
        endif()
    endif()

    # Apply link options: manual override or automatic detection
    if(GCOV_LINK_FLAGS)
        target_link_options(
            ${TARGET}
            ${SCOPE}
            ${GCOV_LINK_FLAGS}
        )
    else()
        # Link options: Single set determined by LUT logic
        if(_GCOV_LINK_FLAGS)
            target_link_options(
                ${TARGET}
                ${SCOPE}
                ${_GCOV_LINK_FLAGS}
            )
        endif()
    endif()
endfunction()

# ==============================================================================
# Coverage Report Targets
# ==============================================================================

# Initialize on include to set up defaults
_Gcovr_EnsureInitialized()

# Create output directory
file(MAKE_DIRECTORY "${GCOVR_OUTPUT_DIR}")

# ==============================================================================
# Generate Config File at Configure Time (SCHEMA mode)
# ==============================================================================
# 
# In SCHEMA mode, the config file is generated at configure time from the
# GCOVR_* cache variables. This ensures all user-configured values are included.
# The file will be regenerated on each cmake configure.
#

set(_GCOVR_GENERATED_CONFIG_FILE "")
if(_GCOVR_CONFIG_MODE STREQUAL "SCHEMA")
    set(_GCOVR_GENERATED_CONFIG_FILE "${GCOVR_OUTPUT_DIR}/gcovr_generated.cfg")
    GcovrSchema_GenerateConfigFile("${_GCOVR_GENERATED_CONFIG_FILE}")
    set(_GCOVR_ACTIVE_CONFIG_FILE "${_GCOVR_GENERATED_CONFIG_FILE}")
else()
    set(_GCOVR_ACTIVE_CONFIG_FILE "${GCOVR_CONFIG_FILE}")
endif()

# ==============================================================================
# Coverage Report Target
# ==============================================================================
#
# Single 'gcovr' target that generates all configured output formats.
# Always prints text summary to console.
# Output formats are controlled by GCOVR_OUTPUT_FORMATS variable.
#

if(NOT TARGET gcovr)
    # Build gcovr command arguments
    set(_gcovr_args
        "${Gcovr_EXECUTABLE}"
        --config "${_GCOVR_ACTIVE_CONFIG_FILE}"
        --root "${GCOVR_ROOT_DIR}"
        --print-summary  # Always print text summary
    )

    # Collect output files for comment
    set(_gcovr_outputs "")

    # HTML output
    if("html" IN_LIST GCOVR_OUTPUT_FORMATS)
        set(_gcovr_html_output "${GCOVR_OUTPUT_DIR}/coverage.html")
        if(GCOVR_HTML_NESTED)
            list(APPEND _gcovr_args --html-nested "${_gcovr_html_output}")
        elseif(GCOVR_HTML_DETAILS)
            list(APPEND _gcovr_args --html-details "${_gcovr_html_output}")
        else()
            list(APPEND _gcovr_args --html "${_gcovr_html_output}")
        endif()
        list(APPEND _gcovr_outputs "HTML")
    endif()

    # XML/Cobertura output
    if("xml" IN_LIST GCOVR_OUTPUT_FORMATS OR "cobertura" IN_LIST GCOVR_OUTPUT_FORMATS)
        list(APPEND _gcovr_args --xml "${GCOVR_OUTPUT_DIR}/coverage.xml")
        list(APPEND _gcovr_outputs "XML")
    endif()

    # JSON output
    if("json" IN_LIST GCOVR_OUTPUT_FORMATS)
        list(APPEND _gcovr_args --json "${GCOVR_OUTPUT_DIR}/coverage.json")
        list(APPEND _gcovr_outputs "JSON")
    endif()

    # LCOV output
    if("lcov" IN_LIST GCOVR_OUTPUT_FORMATS)
        list(APPEND _gcovr_args --lcov "${GCOVR_OUTPUT_DIR}/coverage.lcov")
        list(APPEND _gcovr_outputs "LCOV")
    endif()

    # CSV output
    if("csv" IN_LIST GCOVR_OUTPUT_FORMATS)
        list(APPEND _gcovr_args --csv "${GCOVR_OUTPUT_DIR}/coverage.csv")
        list(APPEND _gcovr_outputs "CSV")
    endif()

    # Coveralls output
    if("coveralls" IN_LIST GCOVR_OUTPUT_FORMATS)
        list(APPEND _gcovr_args --coveralls "${GCOVR_OUTPUT_DIR}/coveralls.json")
        list(APPEND _gcovr_outputs "Coveralls")
    endif()

    # Build comment string
    list(JOIN _gcovr_outputs ", " _gcovr_outputs_str)
    if(_gcovr_outputs_str)
        set(_gcovr_comment "Generate coverage report (${_gcovr_outputs_str}) -> ${GCOVR_OUTPUT_DIR}")
    else()
        set(_gcovr_comment "Generate coverage summary (text only)")
    endif()

    add_custom_target(gcovr
        COMMAND ${_gcovr_args}
        WORKING_DIRECTORY "${GCOVR_ROOT_DIR}"
        COMMENT "${_gcovr_comment}"
    )
endif()

# ==============================================================================
# Backward Compatibility
# ==============================================================================

# Deprecated alias for old config variable
if(DEFINED GCOV_CONFIG_FILE AND NOT GCOVR_CONFIG_FILE)
    set(GCOVR_CONFIG_FILE "${GCOV_CONFIG_FILE}" CACHE FILEPATH "" FORCE)
    message(DEPRECATION "GCOV_CONFIG_FILE is deprecated, use GCOVR_CONFIG_FILE instead")
endif()

function(target_add_gcov _target _scope)
    message(DEPRECATION "target_add_gcov() is deprecated, use Gcov_AddToTarget() instead")
    Gcov_AddToTarget(${_target} ${_scope})
endfunction()
