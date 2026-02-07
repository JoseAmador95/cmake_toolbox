# SPDX-License-Identifier: MIT
# ==============================================================================
# Gcovr 7.0 Schema and Configuration Generator
# ==============================================================================
#
# This file defines the schema and default values for gcovr version 7.x
# It provides cached variable definitions and config file generation functionality.
#
# ==============================================================================

# Gcovr 7.0 Configuration Variables (with sensible defaults)
# These can be overridden by the user before calling Gcovr_Initialize()

# ------------------------------------------------------------------------------
# Coverage Thresholds
# ------------------------------------------------------------------------------

set(GCOVR_FAIL_UNDER_LINE
    "0"
    CACHE STRING
    "Fail if line coverage is below this percentage (0-100)"
)

set(GCOVR_FAIL_UNDER_BRANCH
    "0"
    CACHE STRING
    "Fail if branch coverage is below this percentage (0-100)"
)

set(GCOVR_FAIL_UNDER_FUNCTION
    "0"
    CACHE STRING
    "Fail if function coverage is below this percentage (0-100)"
)

set(GCOVR_FAIL_UNDER_DECISION
    "0"
    CACHE STRING
    "Fail if decision coverage is below this percentage (0-100)"
)

# ------------------------------------------------------------------------------
# HTML Report Thresholds
# ------------------------------------------------------------------------------

set(GCOVR_HTML_HIGH_THRESHOLD
    "95"
    CACHE STRING
    "High coverage threshold for HTML reports (0-100)"
)

set(GCOVR_HTML_MEDIUM_THRESHOLD
    "85"
    CACHE STRING
    "Medium coverage threshold for HTML reports (0-100)"
)

# ------------------------------------------------------------------------------
# File Filters
# ------------------------------------------------------------------------------

set(GCOVR_FILTER
    ""
    CACHE STRING
    "Semicolon-separated list of regex patterns to include files"
)

set(GCOVR_EXCLUDE
    ""
    CACHE STRING
    "Semicolon-separated list of regex patterns to exclude files"
)

set(GCOVR_EXCLUDE_DIRECTORIES
    ""
    CACHE STRING
    "Semicolon-separated list of regex patterns to exclude directories"
)

set(GCOVR_EXCLUDE_UNREACHABLE_BRANCHES
    ON
    CACHE BOOL
    "Exclude unreachable branches from coverage"
)

set(GCOVR_EXCLUDE_THROW_BRANCHES
    ON
    CACHE BOOL
    "Exclude throw branches from coverage"
)

set(GCOVR_EXCLUDE_FUNCTION_LINES
    OFF
    CACHE BOOL
    "Exclude function definition lines from coverage"
)

# ------------------------------------------------------------------------------
# Output Configuration
# ------------------------------------------------------------------------------

set(GCOVR_OUTPUT_FORMATS
    "html"
    CACHE STRING
    "Semicolon-separated list of output formats (html;xml;json;cobertura;lcov;csv;txt)"
)

set(GCOVR_PRINT_SUMMARY
    ON
    CACHE BOOL
    "Print summary to console"
)

set(GCOVR_SORT
    "uncovered-number"
    CACHE STRING
    "Sort order for HTML report (filename, uncovered-number, uncovered-percent)"
)

# ------------------------------------------------------------------------------
# HTML Report Options
# ------------------------------------------------------------------------------

set(GCOVR_HTML_DETAILS
    ON
    CACHE BOOL
    "Generate detailed HTML with per-file coverage"
)

set(GCOVR_HTML_NESTED
    OFF
    CACHE BOOL
    "Generate nested HTML structure following source layout"
)

set(GCOVR_HTML_TITLE
    "Coverage Report"
    CACHE STRING
    "Title for HTML report"
)

set(GCOVR_HTML_SELF_CONTAINED
    ON
    CACHE BOOL
    "Generate self-contained HTML (inline CSS/JS)"
)

# ------------------------------------------------------------------------------
# Advanced Options
# ------------------------------------------------------------------------------

set(GCOVR_GCOV_EXECUTABLE
    ""
    CACHE FILEPATH
    "Path to gcov executable (empty = auto-detect)"
)

set(GCOVR_SEARCH_PATH
    ""
    CACHE STRING
    "Semicolon-separated list of search paths for .gcda files"
)

set(GCOVR_DECISIONS
    OFF
    CACHE BOOL
    "Enable decision coverage (MC/DC)"
)

set(GCOVR_CALLS
    OFF
    CACHE BOOL
    "Enable call coverage"
)

# ==============================================================================
# GcovrSchema_7_0_GenerateConfig
# ==============================================================================
#
# Generate gcovr 7.0 configuration file from cached variables
#
# Parameters:
#   CONFIG_FILE - Path where the configuration will be written
#
function(GcovrSchema_7_0_GenerateConfig CONFIG_FILE)
    set(CONFIG_CONTENT "")

    # Helper macro to append config line
    macro(_gcovr_append_config key value)
        string(APPEND CONFIG_CONTENT "${key} = ${value}\n")
    endmacro()

    macro(_gcovr_append_if_set key var)
        if(DEFINED ${var} AND NOT "${${var}}" STREQUAL "")
            _gcovr_append_config("${key}" "${${var}}")
        endif()
    endmacro()

    macro(_gcovr_append_bool key var)
        if(${var})
            _gcovr_append_config("${key}" "yes")
        endif()
    endmacro()

    # Search paths
    if(GCOVR_SEARCH_PATH)
        foreach(path IN LISTS GCOVR_SEARCH_PATH)
            string(APPEND CONFIG_CONTENT "search-path = ${path}\n")
        endforeach()
    endif()

    # Filters
    if(GCOVR_FILTER)
        foreach(pattern IN LISTS GCOVR_FILTER)
            string(APPEND CONFIG_CONTENT "filter = ${pattern}\n")
        endforeach()
    endif()

    # Exclusions
    if(GCOVR_EXCLUDE)
        foreach(pattern IN LISTS GCOVR_EXCLUDE)
            string(APPEND CONFIG_CONTENT "exclude = ${pattern}\n")
        endforeach()
    endif()

    if(GCOVR_EXCLUDE_DIRECTORIES)
        foreach(pattern IN LISTS GCOVR_EXCLUDE_DIRECTORIES)
            string(APPEND CONFIG_CONTENT "exclude-directories = ${pattern}\n")
        endforeach()
    endif()

    # Exclusion flags
    if(GCOVR_EXCLUDE_UNREACHABLE_BRANCHES)
        _gcovr_append_config("exclude-unreachable-branches" "yes")
    endif()

    if(GCOVR_EXCLUDE_THROW_BRANCHES)
        _gcovr_append_config("exclude-throw-branches" "yes")
    endif()

    if(GCOVR_EXCLUDE_FUNCTION_LINES)
        _gcovr_append_config("exclude-function-lines" "yes")
    endif()

    # Thresholds
    if(NOT "${GCOVR_FAIL_UNDER_LINE}" STREQUAL "0")
        _gcovr_append_config("fail-under-line" "${GCOVR_FAIL_UNDER_LINE}")
    endif()

    if(NOT "${GCOVR_FAIL_UNDER_BRANCH}" STREQUAL "0")
        _gcovr_append_config("fail-under-branch" "${GCOVR_FAIL_UNDER_BRANCH}")
    endif()

    if(NOT "${GCOVR_FAIL_UNDER_FUNCTION}" STREQUAL "0")
        _gcovr_append_config("fail-under-function" "${GCOVR_FAIL_UNDER_FUNCTION}")
    endif()

    if(NOT "${GCOVR_FAIL_UNDER_DECISION}" STREQUAL "0")
        _gcovr_append_config("fail-under-decision" "${GCOVR_FAIL_UNDER_DECISION}")
    endif()

    # HTML thresholds
    _gcovr_append_config("html-high-threshold" "${GCOVR_HTML_HIGH_THRESHOLD}")
    _gcovr_append_config("html-medium-threshold" "${GCOVR_HTML_MEDIUM_THRESHOLD}")

    # HTML options
    if(GCOVR_HTML_TITLE AND NOT "${GCOVR_HTML_TITLE}" STREQUAL "Coverage Report")
        _gcovr_append_config("html-title" "${GCOVR_HTML_TITLE}")
    endif()

    if(NOT GCOVR_HTML_SELF_CONTAINED)
        _gcovr_append_config("html-self-contained" "no")
    endif()

    # Sort order
    if(GCOVR_SORT AND NOT "${GCOVR_SORT}" STREQUAL "uncovered-number")
        _gcovr_append_config("sort" "${GCOVR_SORT}")
    endif()

    # Advanced options
    if(GCOVR_GCOV_EXECUTABLE AND EXISTS "${GCOVR_GCOV_EXECUTABLE}")
        _gcovr_append_config("gcov-executable" "${GCOVR_GCOV_EXECUTABLE}")
    endif()

    if(GCOVR_DECISIONS)
        _gcovr_append_config("decisions" "yes")
    endif()

    if(GCOVR_CALLS)
        _gcovr_append_config("calls" "yes")
    endif()

    # Create directory if it doesn't exist
    get_filename_component(CONFIG_DIR "${CONFIG_FILE}" DIRECTORY)
    file(MAKE_DIRECTORY "${CONFIG_DIR}")

    # Write configuration file
    file(WRITE "${CONFIG_FILE}" "${CONFIG_CONTENT}")
endfunction()
