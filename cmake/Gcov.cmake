# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
Gcov
----

Code coverage instrumentation with gcov/gcovr.

The module instruments targets with ``--coverage`` (per language, via generator
expressions, so mixed toolchains only instrument the languages that support it)
and creates a ``gcovr`` target that produces the coverage report.

Supported Compilers
^^^^^^^^^^^^^^^^^^^

- **GNU**, **Clang**, **AppleClang**: ``--coverage`` on compile and link.
- **MSVC** / **clang-cl**: not supported. gcov/gcovr are GCC-specific; use
  Visual Studio Code Coverage or OpenCppCoverage instead. ``include(Gcov)``
  stays harmless there: it warns, defines a no-op ``Gcov_AddToTarget`` and
  creates no ``gcovr`` target.

Set ``GCOV_COMPILE_FLAGS`` / ``GCOV_LINK_FLAGS`` to bypass the automatic
detection entirely.

For Clang/AppleClang the module looks for ``llvm-cov`` and, when found, tells
gcovr to read the coverage data with ``llvm-cov gcov`` instead of ``gcov``.

Configuration Modes
^^^^^^^^^^^^^^^^^^^

**CONFIG_FILE mode** (preferred): set ``CMT_GCOVR_CONFIG_FILE`` to your own
``gcovr.cfg``; it is passed verbatim to gcovr via ``--config`` and nothing is
generated. A non-existent path is a hard error.

**Generated mode** (default): a ``gcovr.cfg`` is written to
``${CMT_GCOVR_OUTPUT_DIR}/gcovr_generated.cfg`` from the ``CMT_GCOVR_*`` cache
variables, in gcovr's own ``key = value`` syntax.

Threshold enforcement behaves identically in **both** modes: when
``CMT_GCOVR_ENFORCE_THRESHOLDS`` is ON the ``fail-under-*`` values are appended
to the gcovr command line, where they take precedence over the config file.

Dependencies
^^^^^^^^^^^^

Requires gcovr. Call ``find_package(Gcovr)`` first or let the module find it.

Cache Variables
^^^^^^^^^^^^^^^

``CMT_GCOVR_CONFIG_FILE``
  External gcovr config file. Empty (default) selects generated mode.
``CMT_GCOVR_OUTPUT_DIR``
  Report output directory. Default: ``${CMAKE_CURRENT_BINARY_DIR}/coverage``
``CMT_GCOVR_ROOT_DIR``
  Root directory for the analysis. Default: ``${CMAKE_SOURCE_DIR}``
``CMT_GCOVR_OUTPUT_FORMATS``
  Any of ``html``, ``xml``, ``cobertura``, ``json``, ``lcov``, ``csv``,
  ``coveralls``, ``txt``. Default: ``html``
``CMT_GCOVR_ENFORCE_THRESHOLDS``
  Enforce the ``fail-under`` thresholds. Default: OFF
``CMT_GCOVR_FAIL_UNDER_LINE``, ``..._BRANCH``, ``..._FUNCTION``, ``..._DECISION``
  Minimum coverage percentages, 0-100; ``0`` disables the threshold. Default: 0.
  There are no ``CMT_GCOVR_MIN_*`` aliases.
``CMT_GCOVR_SEARCH_PATH``, ``CMT_GCOVR_FILTER``, ``CMT_GCOVR_EXCLUDE``,
``CMT_GCOVR_EXCLUDE_DIRECTORIES``
  Semicolon-separated lists; each entry becomes its own config file line.
``CMT_GCOVR_EXCLUDE_UNREACHABLE_BRANCHES``, ``CMT_GCOVR_EXCLUDE_THROW_BRANCHES``,
``CMT_GCOVR_EXCLUDE_FUNCTION_LINES``, ``CMT_GCOVR_DECISIONS``,
``CMT_GCOVR_CALLS``, ``CMT_GCOVR_PRINT_SUMMARY``
  Boolean gcovr switches.
``CMT_GCOVR_HTML_DETAILS``, ``CMT_GCOVR_HTML_NESTED``,
``CMT_GCOVR_HTML_SELF_CONTAINED``, ``CMT_GCOVR_HTML_TITLE``,
``CMT_GCOVR_HTML_HIGH_THRESHOLD``, ``CMT_GCOVR_HTML_MEDIUM_THRESHOLD``,
``CMT_GCOVR_SORT``
  HTML report options.
``CMT_GCOVR_GCOV_EXECUTABLE``
  gcov command, may include arguments. Empty means auto-detect.
``GCOV_COMPILE_FLAGS``, ``GCOV_LINK_FLAGS``
  Manual overrides for the instrumentation flags.

Read-only Variables
^^^^^^^^^^^^^^^^^^^

``CMT_GCOVR_ACTIVE_CONFIG_FILE``
  Config file actually passed to gcovr.
``CMT_GCOVR_COMMAND``
  Full command line run by the ``gcovr`` target; handy for debugging and tests.

Functions
^^^^^^^^^

.. command:: Gcov_AddToTarget

  Add coverage instrumentation to a target::

    Gcov_AddToTarget(<target> <scope>)

  ``<scope>`` is PUBLIC, PRIVATE or INTERFACE and applies to both the compile
  options and the link options.

Targets
^^^^^^^

``gcovr``
  Generates the report in every format listed in ``CMT_GCOVR_OUTPUT_FORMATS``.

Example
^^^^^^^

.. code-block:: cmake

  set(CMT_GCOVR_FAIL_UNDER_LINE 80 CACHE STRING "" FORCE)
  set(CMT_GCOVR_ENFORCE_THRESHOLDS ON CACHE BOOL "" FORCE)

  include(Gcov)

  add_executable(my_test test.c)
  Gcov_AddToTarget(my_test PRIVATE)

  # cmake --build . && ctest && cmake --build . --target gcovr

#]=======================================================================]

include_guard(GLOBAL)

# ==============================================================================
# Per-language Compiler Flags
# ==============================================================================
# --coverage is only understood by GNU/Clang front ends, so it is applied per
# language. Mixed toolchains (GCC for C, MSVC for C++) instrument what they can.

macro(_gcov_detect_language_flags lang)
    if(CMAKE_${lang}_COMPILER_ID MATCHES "^(GNU|Clang|AppleClang)$")
        set(_GCOV_${lang}_COMPILE_FLAGS --coverage)
    else()
        set(_GCOV_${lang}_COMPILE_FLAGS "")
        set(_gcov_is_msvc FALSE)
        if(CMAKE_${lang}_COMPILER_ID STREQUAL "MSVC")
            set(_gcov_is_msvc TRUE)
        elseif(CMAKE_${lang}_COMPILER_FRONTEND_VARIANT STREQUAL "MSVC")
            set(_gcov_is_msvc TRUE)
        endif()
        if(_gcov_is_msvc AND NOT GCOV_COMPILE_FLAGS)
            message(
                WARNING
                "Gcov: ${lang} compiler '${CMAKE_${lang}_COMPILER_ID}' does not support gcov/gcovr. "
                "For MSVC coverage, use Visual Studio Code Coverage or OpenCppCoverage instead. "
                "Or set GCOV_COMPILE_FLAGS and GCOV_LINK_FLAGS to use a custom tool."
            )
        endif()
    endif()
endmacro()

_gcov_detect_language_flags(C)
_gcov_detect_language_flags(CXX)

# Link flags are not language-scoped: one supported compiler is enough.
if(_GCOV_C_COMPILE_FLAGS OR _GCOV_CXX_COMPILE_FLAGS)
    set(_GCOV_LINK_FLAGS --coverage)
else()
    set(_GCOV_LINK_FLAGS "")
endif()

mark_as_advanced(
    _GCOV_C_COMPILE_FLAGS
    _GCOV_CXX_COMPILE_FLAGS
    _GCOV_LINK_FLAGS
)

# ==============================================================================
# Unsupported Toolchain Stub
# ==============================================================================
# Keep include(Gcov) harmless on MSVC-like toolchains: no gcovr requirement,
# no gcovr target, and a Gcov_AddToTarget that warns instead of failing.

if(NOT _GCOV_LINK_FLAGS AND NOT GCOV_COMPILE_FLAGS AND NOT GCOV_LINK_FLAGS)
    message(
        WARNING
        "Gcov: No supported compiler detected for gcov coverage. Module disabled. "
        "For MSVC coverage, use Visual Studio Code Coverage or OpenCppCoverage instead. "
        "Or set GCOV_COMPILE_FLAGS and GCOV_LINK_FLAGS to use a custom tool."
    )

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

# ==============================================================================
# Cache Variables
# ==============================================================================

set(CMT_GCOVR_CONFIG_FILE "" CACHE FILEPATH "External gcovr configuration file")
set(CMT_GCOVR_OUTPUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/coverage" CACHE PATH "Report output dir")
set(CMT_GCOVR_ROOT_DIR "${CMAKE_SOURCE_DIR}" CACHE PATH "Root directory for coverage analysis")
set(CMT_GCOVR_OUTPUT_FORMATS "html" CACHE STRING "html;xml;cobertura;json;lcov;csv;coveralls;txt")

set(CMT_GCOVR_ENFORCE_THRESHOLDS OFF CACHE BOOL "Enforce the fail-under thresholds")
set(CMT_GCOVR_FAIL_UNDER_LINE "0" CACHE STRING "Minimum line coverage % (0 = disabled)")
set(CMT_GCOVR_FAIL_UNDER_BRANCH "0" CACHE STRING "Minimum branch coverage % (0 = disabled)")
set(CMT_GCOVR_FAIL_UNDER_FUNCTION "0" CACHE STRING "Minimum function coverage % (0 = disabled)")
set(CMT_GCOVR_FAIL_UNDER_DECISION "0" CACHE STRING "Minimum decision coverage % (0 = disabled)")

set(CMT_GCOVR_SEARCH_PATH "" CACHE STRING "Search paths for .gcda files")
set(CMT_GCOVR_FILTER "" CACHE STRING "Regex patterns of files to include")
set(CMT_GCOVR_EXCLUDE "" CACHE STRING "Regex patterns of files to exclude")
set(CMT_GCOVR_EXCLUDE_DIRECTORIES "" CACHE STRING "Regex patterns of directories to exclude")
set(CMT_GCOVR_EXCLUDE_UNREACHABLE_BRANCHES ON CACHE BOOL "Exclude unreachable branches")
set(CMT_GCOVR_EXCLUDE_THROW_BRANCHES ON CACHE BOOL "Exclude throw branches")
set(CMT_GCOVR_EXCLUDE_FUNCTION_LINES OFF CACHE BOOL "Exclude function definition lines")
set(CMT_GCOVR_DECISIONS OFF CACHE BOOL "Enable decision coverage")
set(CMT_GCOVR_CALLS OFF CACHE BOOL "Enable call coverage")
set(CMT_GCOVR_PRINT_SUMMARY ON CACHE BOOL "Print the coverage summary to the console")

set(CMT_GCOVR_HTML_DETAILS ON CACHE BOOL "Detailed HTML with per-file coverage")
set(CMT_GCOVR_HTML_NESTED OFF CACHE BOOL "Nested HTML following the source layout")
set(CMT_GCOVR_HTML_SELF_CONTAINED ON CACHE BOOL "Self-contained HTML (inline CSS/JS)")
set(CMT_GCOVR_HTML_TITLE "Coverage Report" CACHE STRING "Title for the HTML report")
set(CMT_GCOVR_HTML_HIGH_THRESHOLD "95" CACHE STRING "High coverage threshold for HTML reports")
set(CMT_GCOVR_HTML_MEDIUM_THRESHOLD "85" CACHE STRING "Medium coverage threshold for HTML reports")
set(CMT_GCOVR_SORT "uncovered-number" CACHE STRING "filename|uncovered-number|uncovered-percent")

set(CMT_GCOVR_GCOV_EXECUTABLE "" CACHE STRING "gcov command (empty = auto-detect)")
set(GCOV_COMPILE_FLAGS "" CACHE STRING "Override the coverage compile flags")
set(GCOV_LINK_FLAGS "" CACHE STRING "Override the coverage link flags")

# ==============================================================================
# llvm-cov Auto-detection (Clang / AppleClang)
# ==============================================================================
# Clang emits gcov-compatible data, but it must be read back with
# `llvm-cov gcov` rather than the system `gcov`.

if(
    NOT CMT_GCOVR_GCOV_EXECUTABLE
    AND (
        CMAKE_C_COMPILER_ID
            MATCHES
            "Clang"
        OR CMAKE_CXX_COMPILER_ID
            MATCHES
            "Clang"
    )
)
    # Versioned names cover distributions that only ship suffixed LLVM binaries.
    # Generated rather than hard-coded so new LLVM releases need no commit here.
    set(_gcov_llvm_cov_names "")
    foreach(_gcov_llvm_major RANGE 12 40)
        list(APPEND _gcov_llvm_cov_names "llvm-cov-${_gcov_llvm_major}")
    endforeach()
    list(REVERSE _gcov_llvm_cov_names)
    list(
        INSERT _gcov_llvm_cov_names
        0
        llvm-cov
    )

    find_program(_GCOV_LLVM_COV NAMES ${_gcov_llvm_cov_names})
    if(_GCOV_LLVM_COV)
        set(CMT_GCOVR_GCOV_EXECUTABLE "${_GCOV_LLVM_COV} gcov" CACHE STRING "" FORCE)
        message(STATUS "Gcov: Using '${CMT_GCOVR_GCOV_EXECUTABLE}' to read Clang coverage data")
    endif()
    unset(_GCOV_LLVM_COV CACHE)
    unset(_gcov_llvm_cov_names)
endif()

# ==============================================================================
# gcovr Configuration File
# ==============================================================================

foreach(
    _gcov_var
    CMT_GCOVR_FAIL_UNDER_LINE
    CMT_GCOVR_FAIL_UNDER_BRANCH
    CMT_GCOVR_FAIL_UNDER_FUNCTION
    CMT_GCOVR_FAIL_UNDER_DECISION
    CMT_GCOVR_HTML_HIGH_THRESHOLD
    CMT_GCOVR_HTML_MEDIUM_THRESHOLD
)
    if(NOT "${${_gcov_var}}" MATCHES "^[0-9]+$" OR "${${_gcov_var}}" GREATER 100)
        message(WARNING "Gcov: ${_gcov_var} must be 0-100 (got: '${${_gcov_var}}')")
    endif()
endforeach()

file(MAKE_DIRECTORY "${CMT_GCOVR_OUTPUT_DIR}")

if(CMT_GCOVR_CONFIG_FILE)
    if(NOT EXISTS "${CMT_GCOVR_CONFIG_FILE}")
        message(
            FATAL_ERROR
            "Gcov: CMT_GCOVR_CONFIG_FILE does not exist: '${CMT_GCOVR_CONFIG_FILE}'"
        )
    endif()
    set(CMT_GCOVR_ACTIVE_CONFIG_FILE "${CMT_GCOVR_CONFIG_FILE}")
    message(STATUS "Gcov: Using gcovr config file ${CMT_GCOVR_ACTIVE_CONFIG_FILE}")
else()
    # Emit gcovr's native `key = value` syntax. Empty values and disabled
    # switches are omitted so that gcovr's own defaults apply.
    macro(_gcov_cfg_value key value)
        if(NOT "${value}" STREQUAL "")
            string(APPEND _gcov_cfg "${key} = ${value}\n")
        endif()
    endmacro()

    macro(_gcov_cfg_switch key enabled)
        if(${enabled})
            string(APPEND _gcov_cfg "${key} = yes\n")
        endif()
    endmacro()

    macro(_gcov_cfg_list key listvar)
        foreach(_gcov_cfg_item IN LISTS ${listvar})
            string(APPEND _gcov_cfg "${key} = ${_gcov_cfg_item}\n")
        endforeach()
    endmacro()

    set(_gcov_cfg "# Generated by cmake_toolbox Gcov.cmake - do not edit\n")
    _gcov_cfg_list("search-path" CMT_GCOVR_SEARCH_PATH)
    _gcov_cfg_list("filter" CMT_GCOVR_FILTER)
    _gcov_cfg_list("exclude" CMT_GCOVR_EXCLUDE)
    _gcov_cfg_list("exclude-directories" CMT_GCOVR_EXCLUDE_DIRECTORIES)
    _gcov_cfg_switch("exclude-unreachable-branches" CMT_GCOVR_EXCLUDE_UNREACHABLE_BRANCHES)
    _gcov_cfg_switch("exclude-throw-branches" CMT_GCOVR_EXCLUDE_THROW_BRANCHES)
    _gcov_cfg_switch("exclude-function-lines" CMT_GCOVR_EXCLUDE_FUNCTION_LINES)
    _gcov_cfg_switch("decisions" CMT_GCOVR_DECISIONS)
    _gcov_cfg_switch("calls" CMT_GCOVR_CALLS)
    _gcov_cfg_value("html-high-threshold" "${CMT_GCOVR_HTML_HIGH_THRESHOLD}")
    _gcov_cfg_value("html-medium-threshold" "${CMT_GCOVR_HTML_MEDIUM_THRESHOLD}")
    _gcov_cfg_value("html-title" "${CMT_GCOVR_HTML_TITLE}")
    _gcov_cfg_value("sort" "${CMT_GCOVR_SORT}")
    _gcov_cfg_value("gcov-executable" "${CMT_GCOVR_GCOV_EXECUTABLE}")
    if(NOT CMT_GCOVR_HTML_SELF_CONTAINED)
        string(APPEND _gcov_cfg "html-self-contained = no\n")
    endif()

    set(CMT_GCOVR_ACTIVE_CONFIG_FILE "${CMT_GCOVR_OUTPUT_DIR}/gcovr_generated.cfg")
    file(WRITE "${CMT_GCOVR_ACTIVE_CONFIG_FILE}" "${_gcov_cfg}")
    unset(_gcov_cfg)
endif()

# ==============================================================================
# Gcov_AddToTarget
# ==============================================================================
#
# Add coverage instrumentation to a target.
#
# Parameters:
#   TARGET - The target to instrument
#   SCOPE  - PUBLIC, PRIVATE or INTERFACE
#
function(Gcov_AddToTarget TARGET SCOPE)
    if(NOT TARGET ${TARGET})
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Target '${TARGET}' does not exist")
    endif()

    if(GCOV_COMPILE_FLAGS)
        target_compile_options(
            ${TARGET}
            ${SCOPE}
            ${GCOV_COMPILE_FLAGS}
        )
    else()
        # Language-gated so that mixed toolchains only instrument the languages
        # whose compiler understands --coverage.
        foreach(lang C CXX)
            if(_GCOV_${lang}_COMPILE_FLAGS)
                target_compile_options(
                    ${TARGET}
                    ${SCOPE}
                    $<$<COMPILE_LANGUAGE:${lang}>:${_GCOV_${lang}_COMPILE_FLAGS}>
                )
            endif()
        endforeach()
    endif()

    if(GCOV_LINK_FLAGS)
        target_link_options(
            ${TARGET}
            ${SCOPE}
            ${GCOV_LINK_FLAGS}
        )
    elseif(_GCOV_LINK_FLAGS)
        target_link_options(
            ${TARGET}
            ${SCOPE}
            ${_GCOV_LINK_FLAGS}
        )
    endif()
endfunction()

# ==============================================================================
# Coverage Report Target
# ==============================================================================
# A single 'gcovr' target generates every requested format. Thresholds go on the
# command line so they behave the same in generated and CONFIG_FILE mode.

set(CMT_GCOVR_COMMAND
    "${CMT_GCOVR_EXECUTABLE}"
    --config
    "${CMT_GCOVR_ACTIVE_CONFIG_FILE}"
    --root
    "${CMT_GCOVR_ROOT_DIR}"
)

if(CMT_GCOVR_PRINT_SUMMARY)
    list(APPEND CMT_GCOVR_COMMAND --print-summary)
endif()

if(CMT_GCOVR_ENFORCE_THRESHOLDS)
    foreach(_gcov_metric line branch function decision)
        string(TOUPPER "${_gcov_metric}" _gcov_metric_upper)
        set(_gcov_threshold "${CMT_GCOVR_FAIL_UNDER_${_gcov_metric_upper}}")
        if(_gcov_threshold AND NOT _gcov_threshold STREQUAL "0")
            list(
                APPEND CMT_GCOVR_COMMAND
                "--fail-under-${_gcov_metric}"
                "${_gcov_threshold}"
            )
        endif()
    endforeach()
endif()

# 'cobertura' is gcovr's newer name for the same XML report.
set(_gcov_formats "${CMT_GCOVR_OUTPUT_FORMATS}")
list(
    TRANSFORM _gcov_formats
    REPLACE
        "^cobertura$"
        "xml"
)
list(REMOVE_DUPLICATES _gcov_formats)

# format / gcovr flag / output file name, three entries per format
set(_gcov_format_table
    xml
    --xml
    coverage.xml
    json
    --json
    coverage.json
    lcov
    --lcov
    coverage.lcov
    csv
    --csv
    coverage.csv
    coveralls
    --coveralls
    coveralls.json
    txt
    --txt
    coverage.txt
)

set(_gcov_report_formats "")

if("html" IN_LIST _gcov_formats)
    set(_gcov_html_flag --html)
    if(CMT_GCOVR_HTML_NESTED)
        set(_gcov_html_flag --html-nested)
    elseif(CMT_GCOVR_HTML_DETAILS)
        set(_gcov_html_flag --html-details)
    endif()
    list(
        APPEND CMT_GCOVR_COMMAND
        ${_gcov_html_flag}
        "${CMT_GCOVR_OUTPUT_DIR}/coverage.html"
    )
    list(APPEND _gcov_report_formats "HTML")
endif()

list(LENGTH _gcov_format_table _gcov_table_last)
math(EXPR _gcov_table_last "${_gcov_table_last} / 3 - 1")
foreach(_gcov_i RANGE ${_gcov_table_last})
    math(EXPR _gcov_base "${_gcov_i} * 3")
    list(GET _gcov_format_table ${_gcov_base} _gcov_fmt)
    if(NOT "${_gcov_fmt}" IN_LIST _gcov_formats)
        continue()
    endif()

    math(EXPR _gcov_flag_idx "${_gcov_base} + 1")
    math(EXPR _gcov_file_idx "${_gcov_base} + 2")
    list(GET _gcov_format_table ${_gcov_flag_idx} _gcov_flag)
    list(GET _gcov_format_table ${_gcov_file_idx} _gcov_file)
    list(
        APPEND CMT_GCOVR_COMMAND
        ${_gcov_flag}
        "${CMT_GCOVR_OUTPUT_DIR}/${_gcov_file}"
    )
    string(TOUPPER "${_gcov_fmt}" _gcov_fmt_upper)
    list(APPEND _gcov_report_formats "${_gcov_fmt_upper}")
endforeach()

if(NOT TARGET gcovr)
    if(_gcov_report_formats)
        list(
            JOIN _gcov_report_formats
            ", "
            _gcov_report_formats_str
        )
        set(_gcov_comment
            "Generate coverage report (${_gcov_report_formats_str}) -> ${CMT_GCOVR_OUTPUT_DIR}"
        )
    else()
        set(_gcov_comment "Generate coverage summary (text only)")
    endif()

    add_custom_target(
        gcovr
        COMMAND
            ${CMT_GCOVR_COMMAND}
        WORKING_DIRECTORY "${CMT_GCOVR_ROOT_DIR}"
        COMMENT "${_gcov_comment}"
    )
endif()
