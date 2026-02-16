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

**SCHEMA Mode** (default when gcovr capabilities are detected):
  Configuration is managed through CMake cache variables (``GCOVR_*``).
  A configuration file is auto-generated from these variables, skipping options
  unsupported by the installed gcovr.
  No external config file is required.

**CONFIG_FILE Mode** (explicit override):
  Uses an external configuration file specified by ``GCOVR_CONFIG_FILE``.

Dependencies
^^^^^^^^^^^^

This module requires gcovr to be installed. Use ``find_package(Gcovr)`` before
including this module, or let the module find it automatically.

Cache Variables (SCHEMA Mode)
^^^^^^^^^^^^^^^^^^^^^^^^^^^^^

When in SCHEMA mode, the following variables control gcovr behavior.
See ``cmake/GcovrSchema.cmake`` for the complete list.

``GCOVR_FAIL_UNDER_LINE``
  Minimum line coverage percentage (0-100). Default: 0

``GCOVR_FAIL_UNDER_BRANCH``
  Minimum branch coverage percentage (0-100). Default: 0

Note: Thresholds use the ``GCOVR_FAIL_UNDER_*`` naming. There are no ``GCOVR_MIN_*`` aliases.

``GCOVR_ENFORCE_THRESHOLDS``
    Enable enforcement of fail-under thresholds. Default: OFF

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

  Detects gcovr capabilities and sets up appropriate configuration mode.

Targets
^^^^^^^

``gcovr``
  Custom target to generate coverage reports. Always prints text summary.
  Generates all formats specified in ``GCOVR_OUTPUT_FORMATS`` (filtered by gcovr capabilities).

Example
^^^^^^^

.. code-block:: cmake

  include(Gcov)
  
  # Configure coverage thresholds via CMake (SCHEMA mode)
  set(GCOVR_FAIL_UNDER_LINE 80 CACHE STRING "" FORCE)
  set(GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL "" FORCE)
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
elseif(
    (
        CMAKE_C_COMPILER_ID
            STREQUAL
            "MSVC"
        OR CMAKE_C_COMPILER_FRONTEND_VARIANT
            STREQUAL
            "MSVC"
    )
    AND NOT GCOV_COMPILE_FLAGS
)
    message(
        WARNING
        "Gcov: C compiler '${CMAKE_C_COMPILER_ID}' does not support gcov/gcovr. "
        "For MSVC coverage, use Visual Studio Code Coverage or OpenCppCoverage instead. "
        "Or set GCOV_COMPILE_FLAGS and GCOV_LINK_FLAGS to use a custom tool."
    )
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
elseif(
    (
        CMAKE_CXX_COMPILER_ID
            STREQUAL
            "MSVC"
        OR CMAKE_CXX_COMPILER_FRONTEND_VARIANT
            STREQUAL
            "MSVC"
    )
    AND NOT GCOV_COMPILE_FLAGS
)
    message(
        WARNING
        "Gcov: C++ compiler '${CMAKE_CXX_COMPILER_ID}' does not support gcov/gcovr. "
        "For MSVC coverage, use Visual Studio Code Coverage or OpenCppCoverage instead. "
        "Or set GCOV_COMPILE_FLAGS and GCOV_LINK_FLAGS to use a custom tool."
    )
    set(_GCOV_CXX_COMPILE_FLAGS "")
    set(_GCOV_CXX_LINK_FLAGS "")
else()
    set(_GCOV_CXX_COMPILE_FLAGS "")
    set(_GCOV_CXX_LINK_FLAGS "")
endif()

# Link flags: Use --coverage if any compiler supports it
if(
    CMAKE_C_COMPILER_ID
        MATCHES
        "^(GNU|Clang|AppleClang)$"
    OR CMAKE_CXX_COMPILER_ID
        MATCHES
        "^(GNU|Clang|AppleClang)$"
)
    set(_GCOV_LINK_FLAGS --coverage)
else()
    set(_GCOV_LINK_FLAGS "")
endif()

# ==============================================================================
# Find Dependencies
# ==============================================================================

if(NOT _GCOV_LINK_FLAGS AND NOT GCOV_COMPILE_FLAGS AND NOT GCOV_LINK_FLAGS)
    message(
        WARNING
        "Gcov: No supported compiler detected for gcov coverage. Module disabled. "
        "For MSVC coverage, use Visual Studio Code Coverage or OpenCppCoverage instead. "
        "Or set GCOV_COMPILE_FLAGS and GCOV_LINK_FLAGS to use a custom tool."
    )

    function(Gcovr_Initialize)
        message(WARNING "Gcovr_Initialize: gcov support is disabled for this toolchain")
    endfunction()

    function(Gcov_AddToTarget TARGET SCOPE)
        message(
            WARNING
            "${CMAKE_CURRENT_FUNCTION}: gcov not supported for this toolchain. "
            "No instrumentation will be applied to target '${TARGET}'."
        )
    endfunction()
    return()
endif()

find_package(Gcovr REQUIRED)
include(GcovrSchema)

# ==============================================================================
# Internal State Variables
# ==============================================================================

set(_GCOVR_CONFIG_MODE "" CACHE INTERNAL "Gcovr configuration mode: SCHEMA or CONFIG_FILE")

set(_GCOVR_INITIALIZED FALSE CACHE INTERNAL "Whether Gcovr module has been initialized")

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

set(GCOVR_ROOT_DIR "${CMAKE_SOURCE_DIR}" CACHE PATH "Root directory for coverage analysis")

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
mark_as_advanced(
    _GCOV_C_COMPILE_FLAGS
    _GCOV_C_LINK_FLAGS
    _GCOV_CXX_COMPILE_FLAGS
    _GCOV_CXX_LINK_FLAGS
    _GCOV_LINK_FLAGS
)

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

    # Detect capabilities and prefer SCHEMA mode
    set(_GCOVR_CONFIG_MODE "SCHEMA" CACHE INTERNAL "" FORCE)

    if(
        (CMAKE_C_COMPILER_ID MATCHES "Clang|AppleClang")
        OR (CMAKE_CXX_COMPILER_ID MATCHES "Clang|AppleClang")
    )
        if(NOT DEFINED GCOVR_GCOV_EXECUTABLE OR GCOVR_GCOV_EXECUTABLE STREQUAL "")
            find_program(
                _GCOVR_LLVM_COV
                NAMES
                    llvm-cov
                    llvm-cov-18
                    llvm-cov-17
                    llvm-cov-16
                    llvm-cov-15
                    llvm-cov-14
                    llvm-cov-13
                    llvm-cov-12
            )
            if(_GCOVR_LLVM_COV)
                set(
                    GCOVR_GCOV_EXECUTABLE
                    "${_GCOVR_LLVM_COV} gcov"
                    CACHE STRING
                    "Path or command (may include arguments) for gcov executable (empty = auto-detect)"
                )
                message(STATUS "Gcovr_Initialize: Using llvm-cov gcov for Clang coverage")
            endif()
            unset(_GCOVR_LLVM_COV CACHE)
        endif()
    endif()

    GcovrSchema_SetDefaults()
    GcovrSchema_DetectCapabilities("${Gcovr_EXECUTABLE}" DETECTED_FLAGS)

    if(DEFINED _GCOVR_CAPABILITIES_DETECTED AND NOT _GCOVR_CAPABILITIES_DETECTED)
        # In CONFIG_FILE mode without a file, check for default location
        set(DEFAULT_CONFIG "${CMAKE_SOURCE_DIR}/gcovr.cfg")
        if(EXISTS "${DEFAULT_CONFIG}")
            set(_GCOVR_CONFIG_MODE "CONFIG_FILE" CACHE INTERNAL "" FORCE)
            set(GCOVR_CONFIG_FILE "${DEFAULT_CONFIG}" CACHE FILEPATH "" FORCE)
            message(STATUS "Gcovr_Initialize: Found config file at ${DEFAULT_CONFIG}")
        else()
            message(
                WARNING
                "Gcovr_Initialize: Unable to detect gcovr capabilities; assuming all known flags are supported.\n"
                "Provide GCOVR_CONFIG_FILE to use an external config."
            )
        endif()
    else()
        message(STATUS "Gcovr_Initialize: Using SCHEMA mode with gcovr capabilities detection")
    endif()

    if(_GCOVR_CONFIG_MODE STREQUAL "SCHEMA")
        GcovrSchema_Validate()
        if(DEFINED GCOVR_SCHEMA_VALID AND NOT GCOVR_SCHEMA_VALID)
            message(
                WARNING
                "Gcovr_Initialize: Some gcovr settings are invalid. Check earlier warnings."
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
            message(
                FATAL_ERROR
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

    set(_gcovr_thresholds "")
    foreach(
        var
        GCOVR_FAIL_UNDER_LINE
        GCOVR_FAIL_UNDER_BRANCH
        GCOVR_FAIL_UNDER_FUNCTION
        GCOVR_FAIL_UNDER_DECISION
    )
        if(DEFINED ${var} AND NOT "${${var}}" STREQUAL "0")
            list(APPEND _gcovr_thresholds "${var}=${${var}}")
        endif()
    endforeach()

    if(GCOVR_ENFORCE_THRESHOLDS)
        if(_gcovr_thresholds)
            list(
                JOIN _gcovr_thresholds
                ", "
                _gcovr_thresholds_str
            )
            message(STATUS "Gcovr: Enforcing coverage thresholds (${_gcovr_thresholds_str}).")
        else()
            message(STATUS "Gcovr: Threshold enforcement enabled, but no thresholds are set.")
        endif()
    else()
        if(_gcovr_thresholds)
            message(
                STATUS
                "Gcovr: Thresholds configured but enforcement disabled (set GCOVR_ENFORCE_THRESHOLDS=ON to enforce)."
            )
        endif()
    endif()
else()
    set(_GCOVR_ACTIVE_CONFIG_FILE "${GCOVR_CONFIG_FILE}")
    if(GCOVR_ENFORCE_THRESHOLDS)
        message(
            WARNING
            "Gcovr: GCOVR_ENFORCE_THRESHOLDS is ignored in CONFIG_FILE mode. Use fail-under options in the config file."
        )
    endif()
endif()

# ==============================================================================
# Coverage Report Target
# ==============================================================================
#
# Single 'gcovr' target that generates all configured output formats.
# Prints text summary to console when supported.
# Output formats are controlled by GCOVR_OUTPUT_FORMATS variable.
#

if(NOT TARGET gcovr)
    # Build gcovr command arguments
    set(_gcovr_args
        "${Gcovr_EXECUTABLE}"
        --config
        "${_GCOVR_ACTIVE_CONFIG_FILE}"
        --root
        "${GCOVR_ROOT_DIR}"
    )

    set(_gcovr_output_formats "${GCOVR_OUTPUT_FORMATS}")
    GcovrSchema_FilterOutputFormats("${_gcovr_output_formats}" _gcovr_output_formats)

    GcovrSchema_IsFlagSupported("--print-summary" _gcovr_has_print_summary)
    if(_gcovr_has_print_summary)
        list(APPEND _gcovr_args --print-summary)
    else()
        message(WARNING "Gcovr: gcovr does not support --print-summary; skipping text summary")
    endif()

    # Collect output files for comment
    set(_gcovr_outputs "")

    # HTML output
    list(
        FIND _gcovr_output_formats
        "html"
        _fmt_html_idx
    )
    if(NOT _fmt_html_idx EQUAL -1)
        GcovrSchema_IsFlagSupported("--html" _gcovr_has_html)
        GcovrSchema_IsFlagSupported("--html-details" _gcovr_has_html_details)
        GcovrSchema_IsFlagSupported("--html-nested" _gcovr_has_html_nested)

        set(_gcovr_html_flag "")
        if(GCOVR_HTML_NESTED)
            if(_gcovr_has_html_nested)
                set(_gcovr_html_flag "--html-nested")
            elseif(_gcovr_has_html_details)
                message(WARNING "Gcovr: --html-nested not supported, falling back to --html-details")
                set(_gcovr_html_flag "--html-details")
            elseif(_gcovr_has_html)
                message(WARNING "Gcovr: --html-nested not supported, falling back to --html")
                set(_gcovr_html_flag "--html")
            else()
                message(
                    WARNING
                    "Gcovr: HTML output requested but gcovr does not support HTML flags; skipping"
                )
            endif()
        elseif(GCOVR_HTML_DETAILS)
            if(_gcovr_has_html_details)
                set(_gcovr_html_flag "--html-details")
            elseif(_gcovr_has_html)
                message(WARNING "Gcovr: --html-details not supported, falling back to --html")
                set(_gcovr_html_flag "--html")
            elseif(_gcovr_has_html_nested)
                message(WARNING "Gcovr: --html-details not supported, falling back to --html-nested")
                set(_gcovr_html_flag "--html-nested")
            else()
                message(
                    WARNING
                    "Gcovr: HTML output requested but gcovr does not support HTML flags; skipping"
                )
            endif()
        else()
            if(_gcovr_has_html)
                set(_gcovr_html_flag "--html")
            elseif(_gcovr_has_html_details)
                message(WARNING "Gcovr: --html not supported, falling back to --html-details")
                set(_gcovr_html_flag "--html-details")
            elseif(_gcovr_has_html_nested)
                message(WARNING "Gcovr: --html not supported, falling back to --html-nested")
                set(_gcovr_html_flag "--html-nested")
            else()
                message(
                    WARNING
                    "Gcovr: HTML output requested but gcovr does not support HTML flags; skipping"
                )
            endif()
        endif()

        if(_gcovr_html_flag)
            set(_gcovr_html_output "${GCOVR_OUTPUT_DIR}/coverage.html")
            list(
                APPEND _gcovr_args
                ${_gcovr_html_flag}
                "${_gcovr_html_output}"
            )
            list(APPEND _gcovr_outputs "HTML")
        endif()
    endif()

    # XML/Cobertura output
    list(
        FIND _gcovr_output_formats
        "xml"
        _fmt_xml_idx
    )
    list(
        FIND _gcovr_output_formats
        "cobertura"
        _fmt_cobertura_idx
    )
    if(NOT _fmt_xml_idx EQUAL -1 OR NOT _fmt_cobertura_idx EQUAL -1)
        GcovrSchema_IsFlagSupported("--xml" _gcovr_has_xml)
        GcovrSchema_IsFlagSupported("--cobertura" _gcovr_has_cobertura)
        set(_gcovr_xml_flag "")
        if(_gcovr_has_xml)
            set(_gcovr_xml_flag "--xml")
        elseif(_gcovr_has_cobertura)
            set(_gcovr_xml_flag "--cobertura")
        else()
            message(
                WARNING
                "Gcovr: XML/Cobertura output requested but gcovr does not support --xml/--cobertura; skipping"
            )
        endif()

        if(_gcovr_xml_flag)
            list(
                APPEND _gcovr_args
                ${_gcovr_xml_flag}
                "${GCOVR_OUTPUT_DIR}/coverage.xml"
            )
            list(APPEND _gcovr_outputs "XML")
        endif()
    endif()

    # JSON output
    list(
        FIND _gcovr_output_formats
        "json"
        _fmt_json_idx
    )
    if(NOT _fmt_json_idx EQUAL -1)
        GcovrSchema_IsFlagSupported("--json" _gcovr_has_json)
        if(_gcovr_has_json)
            list(
                APPEND _gcovr_args
                --json
                "${GCOVR_OUTPUT_DIR}/coverage.json"
            )
            list(APPEND _gcovr_outputs "JSON")
        else()
            message(WARNING "Gcovr: JSON output requested but gcovr does not support --json; skipping")
        endif()
    endif()

    # LCOV output
    list(
        FIND _gcovr_output_formats
        "lcov"
        _fmt_lcov_idx
    )
    if(NOT _fmt_lcov_idx EQUAL -1)
        GcovrSchema_IsFlagSupported("--lcov" _gcovr_has_lcov)
        if(_gcovr_has_lcov)
            list(
                APPEND _gcovr_args
                --lcov
                "${GCOVR_OUTPUT_DIR}/coverage.lcov"
            )
            list(APPEND _gcovr_outputs "LCOV")
        else()
            message(WARNING "Gcovr: LCOV output requested but gcovr does not support --lcov; skipping")
        endif()
    endif()

    # CSV output
    list(
        FIND _gcovr_output_formats
        "csv"
        _fmt_csv_idx
    )
    if(NOT _fmt_csv_idx EQUAL -1)
        GcovrSchema_IsFlagSupported("--csv" _gcovr_has_csv)
        if(_gcovr_has_csv)
            list(
                APPEND _gcovr_args
                --csv
                "${GCOVR_OUTPUT_DIR}/coverage.csv"
            )
            list(APPEND _gcovr_outputs "CSV")
        else()
            message(WARNING "Gcovr: CSV output requested but gcovr does not support --csv; skipping")
        endif()
    endif()

    # Coveralls output
    list(
        FIND _gcovr_output_formats
        "coveralls"
        _fmt_coveralls_idx
    )
    if(NOT _fmt_coveralls_idx EQUAL -1)
        GcovrSchema_IsFlagSupported("--coveralls" _gcovr_has_coveralls)
        if(_gcovr_has_coveralls)
            list(
                APPEND _gcovr_args
                --coveralls
                "${GCOVR_OUTPUT_DIR}/coveralls.json"
            )
            list(APPEND _gcovr_outputs "Coveralls")
        else()
            message(
                WARNING
                "Gcovr: Coveralls output requested but gcovr does not support --coveralls; skipping"
            )
        endif()
    endif()

    # Build comment string
    list(
        JOIN _gcovr_outputs
        ", "
        _gcovr_outputs_str
    )
    if(_gcovr_outputs_str)
        set(_gcovr_comment
            "Generate coverage report (${_gcovr_outputs_str}) -> ${GCOVR_OUTPUT_DIR}"
        )
    else()
        set(_gcovr_comment "Generate coverage summary (text only)")
    endif()

    add_custom_target(
        gcovr
        COMMAND
            ${_gcovr_args}
        WORKING_DIRECTORY "${GCOVR_ROOT_DIR}"
        COMMENT "${_gcovr_comment}"
    )
endif()
