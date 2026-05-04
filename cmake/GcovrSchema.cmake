# SPDX-License-Identifier: MIT
# ==============================================================================
# Gcovr Schema Management
# ==============================================================================
#
# This module provides capability-based gcovr configuration schema management.
# It detects supported gcovr flags from --help output and generates configuration
# files from cached CMake variables.
#
# FEATURES:
#   - Capability detection via gcovr --help
#   - Cached variable to config file generation
#   - Sensible defaults
#
# ==============================================================================

include_guard(GLOBAL)

set(CMT_GCOVR_SCHEMA_KNOWN_FLAGS
    --search-path
    --filter
    --exclude
    --exclude-directories
    --exclude-unreachable-branches
    --exclude-throw-branches
    --exclude-function-lines
    --fail-under-line
    --fail-under-branch
    --fail-under-function
    --fail-under-decision
    --html
    --html-details
    --html-nested
    --html-title
    --html-self-contained
    --html-high-threshold
    --html-medium-threshold
    --xml
    --cobertura
    --json
    --lcov
    --csv
    --coveralls
    --txt
    --sort
    --gcov-executable
    --decisions
    --calls
    --print-summary
)

# ==============================================================================
# GcovrSchema_DetectVersion
# ==============================================================================
#
# Detect gcovr version from executable (informational only).
#
# Parameters:
#   CMT_GCOVR_EXE  - Path to gcovr executable
#   OUTPUT_VAR - Variable name to store the detected version (MAJOR.MINOR)
#
function(GcovrSchema_DetectVersion CMT_GCOVR_EXE OUTPUT_VAR)
    set(DETECTED_VERSION "")

    if(EXISTS "${CMT_GCOVR_EXE}")
        execute_process(
            COMMAND
                "${CMT_GCOVR_EXE}" --version
            OUTPUT_VARIABLE gcovr_version_output
            ERROR_VARIABLE gcovr_version_error
            RESULT_VARIABLE gcovr_version_result
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_STRIP_TRAILING_WHITESPACE
        )

        if(gcovr_version_result EQUAL 0 AND gcovr_version_output)
            if(gcovr_version_output MATCHES "gcovr ([0-9]+)\\.([0-9]+)")
                set(DETECTED_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}")
                message(
                    STATUS
                    "${CMAKE_CURRENT_FUNCTION}: Version detected from executable: ${DETECTED_VERSION}"
                )
            endif()
        else()
            message(
                STATUS
                "${CMAKE_CURRENT_FUNCTION}: Could not query gcovr executable version: ${gcovr_version_error}"
            )
        endif()
    endif()

    set(${OUTPUT_VAR} "${DETECTED_VERSION}" PARENT_SCOPE)
endfunction()

function(_GcovrSchema_EscapeRegex INPUT OUTPUT_VAR)
    string(REGEX REPLACE "([][+.*()^$|\\\\?{}\\-])" "\\\\\\1" escaped "${INPUT}")
    set(${OUTPUT_VAR} "${escaped}" PARENT_SCOPE)
endfunction()

function(_GcovrSchema_HelpHasFlag HELP_TEXT FLAG OUTPUT_VAR)
    _GcovrSchema_EscapeRegex("${FLAG}" flag_escaped)
    set(pattern "(^|[ \t\r\n,])${flag_escaped}([= \t\r\n,\\[]|$)")
    string(REGEX MATCH "${pattern}" has_flag "${HELP_TEXT}")
    if(has_flag)
        set(${OUTPUT_VAR} TRUE PARENT_SCOPE)
    else()
        set(${OUTPUT_VAR} FALSE PARENT_SCOPE)
    endif()
endfunction()

# ==============================================================================
# GcovrSchema_DetectCapabilities
# ==============================================================================
#
# Detect supported gcovr flags from --help output.
#
# Parameters:
#   CMT_GCOVR_EXE  - Path to gcovr executable
#   OUTPUT_VAR - Variable name to store detected flag list
#
function(GcovrSchema_DetectCapabilities CMT_GCOVR_EXE OUTPUT_VAR)
    set(supported_flags "")
    set(help_output "")

    if(NOT CMT_GCOVR_EXE)
        set(help_output "")
    elseif(NOT EXISTS "${CMT_GCOVR_EXE}")
        set(help_output "")
    else()
        execute_process(
            COMMAND
                "${CMT_GCOVR_EXE}" --help
            OUTPUT_VARIABLE gcovr_help_output
            ERROR_VARIABLE gcovr_help_error
            RESULT_VARIABLE gcovr_help_result
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_STRIP_TRAILING_WHITESPACE
        )

        if(NOT gcovr_help_output STREQUAL "")
            set(help_output "${gcovr_help_output}")
            if(NOT gcovr_help_error STREQUAL "")
                string(APPEND help_output "\n${gcovr_help_error}")
            endif()
        elseif(NOT gcovr_help_error STREQUAL "")
            set(help_output "${gcovr_help_error}")
        endif()

        if(help_output STREQUAL "")
            execute_process(
                COMMAND
                    "${CMT_GCOVR_EXE}" -h
                OUTPUT_VARIABLE gcovr_help_output
                ERROR_VARIABLE gcovr_help_error
                RESULT_VARIABLE gcovr_help_result
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_STRIP_TRAILING_WHITESPACE
            )

            if(NOT gcovr_help_output STREQUAL "")
                set(help_output "${gcovr_help_output}")
                if(NOT gcovr_help_error STREQUAL "")
                    string(APPEND help_output "\n${gcovr_help_error}")
                endif()
            elseif(NOT gcovr_help_error STREQUAL "")
                set(help_output "${gcovr_help_error}")
            endif()
        endif()
    endif()

    if(help_output)
        foreach(flag IN LISTS CMT_GCOVR_SCHEMA_KNOWN_FLAGS)
            _GcovrSchema_HelpHasFlag("${help_output}" "${flag}" has_flag)
            if(has_flag)
                list(APPEND supported_flags "${flag}")
            endif()
        endforeach()
    endif()

    if(supported_flags)
        set(CMT_GCOVR_SUPPORTED_FLAGS
            "${supported_flags}"
            CACHE INTERNAL
            "Detected gcovr flags"
            FORCE
        )
        set(CMT_GCOVR_CAPABILITIES_DETECTED
            TRUE
            CACHE INTERNAL
            "Whether gcovr capabilities were detected"
            FORCE
        )
    else()
        set(CMT_GCOVR_SUPPORTED_FLAGS "" CACHE INTERNAL "Detected gcovr flags" FORCE)
        set(CMT_GCOVR_CAPABILITIES_DETECTED
            FALSE
            CACHE INTERNAL
            "Whether gcovr capabilities were detected"
            FORCE
        )
    endif()

    set(CMT_GCOVR_CAPABILITIES_EXE
        "${CMT_GCOVR_EXE}"
        CACHE INTERNAL
        "gcovr executable used for capabilities detection"
        FORCE
    )

    set(${OUTPUT_VAR} "${supported_flags}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# GcovrSchema_IsFlagSupported
# ==============================================================================
function(GcovrSchema_IsFlagSupported FLAG OUTPUT_VAR)
    if(DEFINED CMT_GCOVR_CAPABILITIES_DETECTED AND CMT_GCOVR_CAPABILITIES_DETECTED)
        list(
            FIND CMT_GCOVR_SUPPORTED_FLAGS
            "${FLAG}"
            flag_index
        )
        if(flag_index EQUAL -1)
            set(${OUTPUT_VAR} FALSE PARENT_SCOPE)
        else()
            set(${OUTPUT_VAR} TRUE PARENT_SCOPE)
        endif()
    else()
        set(${OUTPUT_VAR} TRUE PARENT_SCOPE)
    endif()
endfunction()

# ==============================================================================
# GcovrSchema_FilterOutputFormats
# ==============================================================================
function(GcovrSchema_FilterOutputFormats INPUT_FORMATS OUTPUT_VAR)
    set(filtered "")

    foreach(format IN LISTS INPUT_FORMATS)
        string(TOLOWER "${format}" format_lower)

        if(format_lower STREQUAL "html")
            GcovrSchema_IsFlagSupported("--html" has_html)
            GcovrSchema_IsFlagSupported("--html-details" has_html_details)
            GcovrSchema_IsFlagSupported("--html-nested" has_html_nested)
            if(has_html OR has_html_details OR has_html_nested)
                list(APPEND filtered "html")
            else()
                message(WARNING "GcovrSchema: Skipping HTML output (gcovr lacks HTML flags)")
            endif()
        elseif(format_lower STREQUAL "xml" OR format_lower STREQUAL "cobertura")
            GcovrSchema_IsFlagSupported("--xml" has_xml)
            GcovrSchema_IsFlagSupported("--cobertura" has_cobertura)
            if(has_xml OR has_cobertura)
                list(APPEND filtered "${format_lower}")
            else()
                message(
                    WARNING
                    "GcovrSchema: Skipping XML/Cobertura output (gcovr lacks --xml/--cobertura)"
                )
            endif()
        elseif(format_lower STREQUAL "json")
            GcovrSchema_IsFlagSupported("--json" has_json)
            if(has_json)
                list(APPEND filtered "json")
            else()
                message(WARNING "GcovrSchema: Skipping JSON output (gcovr lacks --json)")
            endif()
        elseif(format_lower STREQUAL "lcov")
            GcovrSchema_IsFlagSupported("--lcov" has_lcov)
            if(has_lcov)
                list(APPEND filtered "lcov")
            else()
                message(WARNING "GcovrSchema: Skipping LCOV output (gcovr lacks --lcov)")
            endif()
        elseif(format_lower STREQUAL "csv")
            GcovrSchema_IsFlagSupported("--csv" has_csv)
            if(has_csv)
                list(APPEND filtered "csv")
            else()
                message(WARNING "GcovrSchema: Skipping CSV output (gcovr lacks --csv)")
            endif()
        elseif(format_lower STREQUAL "coveralls")
            GcovrSchema_IsFlagSupported("--coveralls" has_coveralls)
            if(has_coveralls)
                list(APPEND filtered "coveralls")
            else()
                message(WARNING "GcovrSchema: Skipping Coveralls output (gcovr lacks --coveralls)")
            endif()
        elseif(format_lower STREQUAL "txt")
            GcovrSchema_IsFlagSupported("--txt" has_txt)
            if(has_txt)
                list(APPEND filtered "txt")
            else()
                message(WARNING "GcovrSchema: Skipping TXT output (gcovr lacks --txt)")
            endif()
        else()
            list(APPEND filtered "${format}")
        endif()
    endforeach()

    set(${OUTPUT_VAR} "${filtered}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# GcovrSchema_SetDefaults
# ==============================================================================
function(GcovrSchema_SetDefaults)
    if(ARGC GREATER 0)
        message(
            DEPRECATION
            "${CMAKE_CURRENT_FUNCTION} no longer takes a version argument; it is ignored"
        )
    endif()

    set(CMT_GCOVR_ENFORCE_THRESHOLDS
        OFF
        CACHE BOOL
        "Enable fail-under thresholds for coverage metrics"
    )

    set(CMT_GCOVR_FAIL_UNDER_LINE
        "0"
        CACHE STRING
        "Fail if line coverage is below this percentage (0-100)"
    )

    set(CMT_GCOVR_FAIL_UNDER_BRANCH
        "0"
        CACHE STRING
        "Fail if branch coverage is below this percentage (0-100)"
    )

    set(CMT_GCOVR_FAIL_UNDER_FUNCTION
        "0"
        CACHE STRING
        "Fail if function coverage is below this percentage (0-100)"
    )

    set(CMT_GCOVR_FAIL_UNDER_DECISION
        "0"
        CACHE STRING
        "Fail if decision coverage is below this percentage (0-100)"
    )

    set(CMT_GCOVR_HTML_HIGH_THRESHOLD
        "95"
        CACHE STRING
        "High coverage threshold for HTML reports (0-100)"
    )

    set(CMT_GCOVR_HTML_MEDIUM_THRESHOLD
        "85"
        CACHE STRING
        "Medium coverage threshold for HTML reports (0-100)"
    )

    set(CMT_GCOVR_FILTER
        ""
        CACHE STRING
        "Semicolon-separated list of regex patterns to include files"
    )

    set(CMT_GCOVR_EXCLUDE
        ""
        CACHE STRING
        "Semicolon-separated list of regex patterns to exclude files"
    )

    set(CMT_GCOVR_EXCLUDE_DIRECTORIES
        ""
        CACHE STRING
        "Semicolon-separated list of regex patterns to exclude directories"
    )

    set(CMT_GCOVR_EXCLUDE_UNREACHABLE_BRANCHES
        ON
        CACHE BOOL
        "Exclude unreachable branches from coverage"
    )

    set(CMT_GCOVR_EXCLUDE_THROW_BRANCHES ON CACHE BOOL "Exclude throw branches from coverage")

    set(CMT_GCOVR_EXCLUDE_FUNCTION_LINES
        OFF
        CACHE BOOL
        "Exclude function definition lines from coverage"
    )

    set(CMT_GCOVR_OUTPUT_FORMATS
        "html"
        CACHE STRING
        "Semicolon-separated list of output formats (html;xml;json;cobertura;lcov;csv;txt)"
    )

    set(CMT_GCOVR_PRINT_SUMMARY ON CACHE BOOL "Print summary to console")

    set(CMT_GCOVR_SORT
        "uncovered-number"
        CACHE STRING
        "Sort order for HTML report (filename, uncovered-number, uncovered-percent)"
    )

    set(CMT_GCOVR_HTML_DETAILS ON CACHE BOOL "Generate detailed HTML with per-file coverage")

    set(CMT_GCOVR_HTML_NESTED
        OFF
        CACHE BOOL
        "Generate nested HTML structure following source layout"
    )

    set(CMT_GCOVR_HTML_TITLE "Coverage Report" CACHE STRING "Title for HTML report")

    set(CMT_GCOVR_HTML_SELF_CONTAINED ON CACHE BOOL "Generate self-contained HTML (inline CSS/JS)")

    set(CMT_GCOVR_GCOV_EXECUTABLE
        ""
        CACHE STRING
        "Path or command (may include arguments) for gcov executable (empty = auto-detect)"
    )

    set(CMT_GCOVR_SEARCH_PATH
        ""
        CACHE STRING
        "Semicolon-separated list of search paths for .gcda files"
    )

    set(CMT_GCOVR_DECISIONS OFF CACHE BOOL "Enable decision coverage (MC/DC)")

    set(CMT_GCOVR_CALLS OFF CACHE BOOL "Enable call coverage")
endfunction()

# ==============================================================================
# GcovrSchema_GenerateConfigFile
# ==============================================================================
function(GcovrSchema_GenerateConfigFile CONFIG_FILE)
    if(NOT DEFINED CMT_GCOVR_CAPABILITIES_DETECTED)
        if(DEFINED Gcovr_EXECUTABLE AND EXISTS "${Gcovr_EXECUTABLE}")
            GcovrSchema_DetectCapabilities("${Gcovr_EXECUTABLE}" _gcovr_detected_flags)
        endif()
    endif()

    if(DEFINED CMT_GCOVR_CAPABILITIES_DETECTED AND NOT CMT_GCOVR_CAPABILITIES_DETECTED)
        message(
            WARNING
            "${CMAKE_CURRENT_FUNCTION}: gcovr capabilities not detected; assuming all known flags are supported"
        )
    endif()

    cmake_path(GET CONFIG_FILE PARENT_PATH output_dir)
    file(MAKE_DIRECTORY "${output_dir}")

    set(CONFIG_CONTENT "")

    macro(_gcovr_append_config key value)
        string(APPEND CONFIG_CONTENT "${key} = ${value}\n")
    endmacro()

    macro(_gcovr_warn_unsupported key flag)
        message(
            WARNING
            "${CMAKE_CURRENT_FUNCTION}: '${key}' not supported by gcovr (missing ${flag}); skipping"
        )
    endmacro()

    macro(_gcovr_append_if_supported key var flag)
        if(DEFINED ${var} AND NOT "${${var}}" STREQUAL "")
            GcovrSchema_IsFlagSupported("${flag}" _gcovr_supported)
            if(_gcovr_supported)
                _gcovr_append_config("${key}" "${${var}}")
            else()
                _gcovr_warn_unsupported("${key}" "${flag}")
            endif()
        endif()
    endmacro()

    if(CMT_GCOVR_SEARCH_PATH)
        GcovrSchema_IsFlagSupported("--search-path" _gcovr_supported)
        if(_gcovr_supported)
            foreach(path IN LISTS CMT_GCOVR_SEARCH_PATH)
                string(APPEND CONFIG_CONTENT "search-path = ${path}\n")
            endforeach()
        else()
            _gcovr_warn_unsupported("search-path" "--search-path")
        endif()
    endif()

    if(CMT_GCOVR_FILTER)
        GcovrSchema_IsFlagSupported("--filter" _gcovr_supported)
        if(_gcovr_supported)
            foreach(pattern IN LISTS CMT_GCOVR_FILTER)
                string(APPEND CONFIG_CONTENT "filter = ${pattern}\n")
            endforeach()
        else()
            _gcovr_warn_unsupported("filter" "--filter")
        endif()
    endif()

    if(CMT_GCOVR_EXCLUDE)
        GcovrSchema_IsFlagSupported("--exclude" _gcovr_supported)
        if(_gcovr_supported)
            foreach(pattern IN LISTS CMT_GCOVR_EXCLUDE)
                string(APPEND CONFIG_CONTENT "exclude = ${pattern}\n")
            endforeach()
        else()
            _gcovr_warn_unsupported("exclude" "--exclude")
        endif()
    endif()

    if(CMT_GCOVR_EXCLUDE_DIRECTORIES)
        GcovrSchema_IsFlagSupported("--exclude-directories" _gcovr_supported)
        if(_gcovr_supported)
            foreach(pattern IN LISTS CMT_GCOVR_EXCLUDE_DIRECTORIES)
                string(APPEND CONFIG_CONTENT "exclude-directories = ${pattern}\n")
            endforeach()
        else()
            _gcovr_warn_unsupported("exclude-directories" "--exclude-directories")
        endif()
    endif()

    if(CMT_GCOVR_EXCLUDE_UNREACHABLE_BRANCHES)
        GcovrSchema_IsFlagSupported("--exclude-unreachable-branches" _gcovr_supported)
        if(_gcovr_supported)
            _gcovr_append_config("exclude-unreachable-branches" "yes")
        else()
            _gcovr_warn_unsupported("exclude-unreachable-branches" "--exclude-unreachable-branches")
        endif()
    endif()

    if(CMT_GCOVR_EXCLUDE_THROW_BRANCHES)
        GcovrSchema_IsFlagSupported("--exclude-throw-branches" _gcovr_supported)
        if(_gcovr_supported)
            _gcovr_append_config("exclude-throw-branches" "yes")
        else()
            _gcovr_warn_unsupported("exclude-throw-branches" "--exclude-throw-branches")
        endif()
    endif()

    if(CMT_GCOVR_EXCLUDE_FUNCTION_LINES)
        GcovrSchema_IsFlagSupported("--exclude-function-lines" _gcovr_supported)
        if(_gcovr_supported)
            _gcovr_append_config("exclude-function-lines" "yes")
        else()
            _gcovr_warn_unsupported("exclude-function-lines" "--exclude-function-lines")
        endif()
    endif()

    if(CMT_GCOVR_ENFORCE_THRESHOLDS)
        if(NOT "${CMT_GCOVR_FAIL_UNDER_LINE}" STREQUAL "0")
            _gcovr_append_if_supported(
                "fail-under-line"
                CMT_GCOVR_FAIL_UNDER_LINE
                "--fail-under-line"
            )
        endif()

        if(NOT "${CMT_GCOVR_FAIL_UNDER_BRANCH}" STREQUAL "0")
            _gcovr_append_if_supported(
                "fail-under-branch"
                CMT_GCOVR_FAIL_UNDER_BRANCH
                "--fail-under-branch"
            )
        endif()

        if(NOT "${CMT_GCOVR_FAIL_UNDER_FUNCTION}" STREQUAL "0")
            _gcovr_append_if_supported(
                "fail-under-function"
                CMT_GCOVR_FAIL_UNDER_FUNCTION
                "--fail-under-function"
            )
        endif()

        if(NOT "${CMT_GCOVR_FAIL_UNDER_DECISION}" STREQUAL "0")
            _gcovr_append_if_supported(
                "fail-under-decision"
                CMT_GCOVR_FAIL_UNDER_DECISION
                "--fail-under-decision"
            )
        endif()
    endif()

    _gcovr_append_if_supported(
        "html-high-threshold"
        CMT_GCOVR_HTML_HIGH_THRESHOLD
        "--html-high-threshold"
    )
    _gcovr_append_if_supported(
        "html-medium-threshold"
        CMT_GCOVR_HTML_MEDIUM_THRESHOLD
        "--html-medium-threshold"
    )

    if(CMT_GCOVR_HTML_TITLE AND NOT "${CMT_GCOVR_HTML_TITLE}" STREQUAL "Coverage Report")
        _gcovr_append_if_supported("html-title" CMT_GCOVR_HTML_TITLE "--html-title")
    endif()

    if(NOT CMT_GCOVR_HTML_SELF_CONTAINED)
        GcovrSchema_IsFlagSupported("--html-self-contained" _gcovr_supported)
        if(_gcovr_supported)
            _gcovr_append_config("html-self-contained" "no")
        else()
            _gcovr_warn_unsupported("html-self-contained" "--html-self-contained")
        endif()
    endif()

    if(CMT_GCOVR_SORT AND NOT "${CMT_GCOVR_SORT}" STREQUAL "uncovered-number")
        _gcovr_append_if_supported("sort" CMT_GCOVR_SORT "--sort")
    endif()

    if(CMT_GCOVR_GCOV_EXECUTABLE)
        if(CMT_GCOVR_GCOV_EXECUTABLE MATCHES " ")
            if(EXISTS "${CMT_GCOVR_GCOV_EXECUTABLE}")
                _gcovr_append_if_supported(
                    "gcov-executable"
                    CMT_GCOVR_GCOV_EXECUTABLE
                    "--gcov-executable"
                )
            else()
                string(REGEX MATCH "^[^ ]+" _gcovr_gcov_cmd_first "${CMT_GCOVR_GCOV_EXECUTABLE}")
                if(_gcovr_gcov_cmd_first)
                    cmake_path(IS_ABSOLUTE _gcovr_gcov_cmd_first _gcovr_is_absolute)
                    if(_gcovr_is_absolute)
                        if(EXISTS "${_gcovr_gcov_cmd_first}")
                            _gcovr_append_if_supported(
                                "gcov-executable"
                                CMT_GCOVR_GCOV_EXECUTABLE
                                "--gcov-executable"
                            )
                        else()
                            message(
                                WARNING
                                "${CMAKE_CURRENT_FUNCTION}: gcov-executable not found: ${CMT_GCOVR_GCOV_EXECUTABLE}"
                            )
                        endif()
                    else()
                        find_program(_gcovr_gcov_cmd NAMES "${_gcovr_gcov_cmd_first}")
                        if(_gcovr_gcov_cmd)
                            _gcovr_append_if_supported(
                                "gcov-executable"
                                CMT_GCOVR_GCOV_EXECUTABLE
                                "--gcov-executable"
                            )
                        else()
                            message(
                                WARNING
                                "${CMAKE_CURRENT_FUNCTION}: gcov-executable not found: ${CMT_GCOVR_GCOV_EXECUTABLE}"
                            )
                        endif()
                        unset(_gcovr_gcov_cmd CACHE)
                    endif()
                    unset(_gcovr_gcov_cmd_first)
                    unset(_gcovr_is_absolute)
                else()
                    message(
                        WARNING
                        "${CMAKE_CURRENT_FUNCTION}: gcov-executable not found: ${CMT_GCOVR_GCOV_EXECUTABLE}"
                    )
                endif()
            endif()
        else()
            cmake_path(IS_ABSOLUTE CMT_GCOVR_GCOV_EXECUTABLE _gcovr_is_absolute)
            if(_gcovr_is_absolute)
                if(EXISTS "${CMT_GCOVR_GCOV_EXECUTABLE}")
                    _gcovr_append_if_supported(
                        "gcov-executable"
                        CMT_GCOVR_GCOV_EXECUTABLE
                        "--gcov-executable"
                    )
                else()
                    message(
                        WARNING
                        "${CMAKE_CURRENT_FUNCTION}: gcov-executable not found: ${CMT_GCOVR_GCOV_EXECUTABLE}"
                    )
                endif()
            else()
                find_program(_gcovr_gcov_cmd NAMES "${CMT_GCOVR_GCOV_EXECUTABLE}")
                if(_gcovr_gcov_cmd)
                    _gcovr_append_if_supported(
                        "gcov-executable"
                        CMT_GCOVR_GCOV_EXECUTABLE
                        "--gcov-executable"
                    )
                else()
                    message(
                        WARNING
                        "${CMAKE_CURRENT_FUNCTION}: gcov-executable not found: ${CMT_GCOVR_GCOV_EXECUTABLE}"
                    )
                endif()
                unset(_gcovr_gcov_cmd CACHE)
            endif()
        endif()
    endif()

    if(CMT_GCOVR_DECISIONS)
        GcovrSchema_IsFlagSupported("--decisions" _gcovr_supported)
        if(_gcovr_supported)
            _gcovr_append_config("decisions" "yes")
        else()
            _gcovr_warn_unsupported("decisions" "--decisions")
        endif()
    endif()

    if(CMT_GCOVR_CALLS)
        GcovrSchema_IsFlagSupported("--calls" _gcovr_supported)
        if(_gcovr_supported)
            _gcovr_append_config("calls" "yes")
        else()
            _gcovr_warn_unsupported("calls" "--calls")
        endif()
    endif()

    file(WRITE "${CONFIG_FILE}" "${CONFIG_CONTENT}")
endfunction()

# ==============================================================================
# GcovrSchema_Validate
# ==============================================================================
function(GcovrSchema_Validate)
    set(IS_VALID TRUE)
    set(ERRORS "")

    foreach(
        var
        CMT_GCOVR_FAIL_UNDER_LINE
        CMT_GCOVR_FAIL_UNDER_BRANCH
        CMT_GCOVR_FAIL_UNDER_FUNCTION
        CMT_GCOVR_FAIL_UNDER_DECISION
        CMT_GCOVR_HTML_HIGH_THRESHOLD
        CMT_GCOVR_HTML_MEDIUM_THRESHOLD
    )
        if(DEFINED ${var})
            if(NOT "${${var}}" MATCHES "^[0-9]+$")
                set(IS_VALID FALSE)
                list(APPEND ERRORS "${var} must be a number (got: ${${var}})")
            elseif("${${var}}" GREATER 100)
                set(IS_VALID FALSE)
                list(APPEND ERRORS "${var} must be <= 100 (got: ${${var}})")
            endif()
        endif()
    endforeach()

    if(DEFINED CMT_GCOVR_OUTPUT_FORMATS)
        set(VALID_FORMATS
            "html"
            "xml"
            "json"
            "cobertura"
            "coveralls"
            "lcov"
            "csv"
            "txt"
        )
        foreach(format IN LISTS CMT_GCOVR_OUTPUT_FORMATS)
            list(
                FIND VALID_FORMATS
                "${format}"
                _format_index
            )
            if(_format_index EQUAL -1)
                set(IS_VALID FALSE)
                list(
                    APPEND ERRORS
                    "Invalid output format: ${format}. Valid formats: ${VALID_FORMATS}"
                )
            endif()
        endforeach()
    endif()

    if(NOT IS_VALID)
        foreach(error IN LISTS ERRORS)
            message(WARNING "${CMAKE_CURRENT_FUNCTION}: ${error}")
        endforeach()
    endif()

    set(CMT_GCOVR_SCHEMA_VALID ${IS_VALID} PARENT_SCOPE)
endfunction()
