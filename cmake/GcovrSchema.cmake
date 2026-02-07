# SPDX-License-Identifier: MIT
# ==============================================================================
# Gcovr Schema Management
# ==============================================================================
#
# This module provides version-aware gcovr configuration schema management.
# It handles different gcovr versions and generates appropriate configuration
# files from cached CMake variables.
#
# FEATURES:
#   - Auto-detection of gcovr version from executable
#   - Version-specific schema handling
#   - Cached variable to config file generation
#   - Sensible defaults per version
#
# ==============================================================================

include_guard(GLOBAL)

# ==============================================================================
# GcovrSchema_GetSupportedVersions
# ==============================================================================
#
# Get list of supported gcovr versions
#
# Parameters:
#   OUTPUT_VAR - Variable name to store the list of supported versions
#
function(GcovrSchema_GetSupportedVersions OUTPUT_VAR)
    set(SUPPORTED_VERSIONS "7.0")
    set(${OUTPUT_VAR} "${SUPPORTED_VERSIONS}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# GcovrSchema_DetectVersion
# ==============================================================================
#
# Detect gcovr version from executable
#
# Parameters:
#   GCOVR_EXE  - Path to gcovr executable
#   OUTPUT_VAR - Variable name to store the detected schema version
#
function(GcovrSchema_DetectVersion GCOVR_EXE OUTPUT_VAR)
    set(DETECTED_VERSION "")

    # Try to get version from gcovr executable
    if(EXISTS "${GCOVR_EXE}")
        execute_process(
            COMMAND
                "${GCOVR_EXE}" --version
            OUTPUT_VARIABLE gcovr_version_output
            ERROR_VARIABLE gcovr_version_error
            RESULT_VARIABLE gcovr_version_result
            OUTPUT_STRIP_TRAILING_WHITESPACE
            ERROR_STRIP_TRAILING_WHITESPACE
        )

        if(gcovr_version_result EQUAL 0 AND gcovr_version_output)
            # Extract version from output (format: "gcovr 7.0" or "gcovr 7.2.1")
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

    # Check if detected version is supported
    if(DETECTED_VERSION)
        GcovrSchema_GetSupportedVersions(SUPPORTED_VERSIONS)
        
        # Check for exact match first
        if(DETECTED_VERSION IN_LIST SUPPORTED_VERSIONS)
            set(${OUTPUT_VAR} "${DETECTED_VERSION}" PARENT_SCOPE)
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Using gcovr schema version: ${DETECTED_VERSION}")
            return()
        endif()
        
        # Try to find a compatible major version schema
        string(REGEX MATCH "^([0-9]+)" MAJOR_VERSION "${DETECTED_VERSION}")
        foreach(supported IN LISTS SUPPORTED_VERSIONS)
            string(REGEX MATCH "^([0-9]+)" supported_major "${supported}")
            if(MAJOR_VERSION STREQUAL supported_major)
                set(${OUTPUT_VAR} "${supported}" PARENT_SCOPE)
                message(
                    STATUS
                    "${CMAKE_CURRENT_FUNCTION}: Using compatible schema ${supported} for gcovr ${DETECTED_VERSION}"
                )
                return()
            endif()
        endforeach()
        
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Unsupported gcovr version ${DETECTED_VERSION}")
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Supported versions: ${SUPPORTED_VERSIONS}")
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Falling back to CONFIG_FILE mode")
    else()
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
        message(
            STATUS
            "${CMAKE_CURRENT_FUNCTION}: Could not detect gcovr version, falling back to CONFIG_FILE mode"
        )
    endif()
endfunction()

# ==============================================================================
# GcovrSchema_SetDefaults
# ==============================================================================
#
# Set version-specific default values for gcovr configuration variables
#
# Parameters:
#   VERSION - Gcovr schema version (e.g., "7.0")
#
function(GcovrSchema_SetDefaults VERSION)
    # Normalize version for filename (7.0 -> 7.0)
    string(REPLACE "." "." VERSION_NORMALIZED "${VERSION}")
    
    # Load version-specific schema
    set(SCHEMA_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/schemas/gcovr-${VERSION_NORMALIZED}.cmake")
    if(EXISTS "${SCHEMA_FILE}")
        include("${SCHEMA_FILE}")
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Applied defaults for gcovr ${VERSION}")
    else()
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Schema file not found: ${SCHEMA_FILE}")
    endif()
endfunction()

# ==============================================================================
# GcovrSchema_GenerateConfigFile
# ==============================================================================
#
# Generates a gcovr configuration file using the currently detected schema version.
#
# Parameters:
#   CONFIG_FILE - Full path where the configuration file should be generated
#
function(GcovrSchema_GenerateConfigFile CONFIG_FILE)
    if(NOT _GCOVR_SCHEMA_VERSION)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: No gcovr schema version detected. Call GcovrSchema_DetectVersion() first."
        )
    endif()

    cmake_path(GET CONFIG_FILE PARENT_PATH output_dir)
    file(MAKE_DIRECTORY "${output_dir}")

    # Load version-specific schema
    set(SCHEMA_FILE
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/schemas/gcovr-${_GCOVR_SCHEMA_VERSION}.cmake"
    )
    if(NOT EXISTS "${SCHEMA_FILE}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Schema file not found: ${SCHEMA_FILE}")
    endif()

    # Include schema to get generation function
    include("${SCHEMA_FILE}")

    # Call version-specific generation function (replace . with _ for function name)
    string(REPLACE "." "_" VERSION_UNDERSCORE "${_GCOVR_SCHEMA_VERSION}")
    cmake_language(
        CALL
            "GcovrSchema_${VERSION_UNDERSCORE}_GenerateConfig"
            "${CONFIG_FILE}"
    )

    message(
        STATUS
        "${CMAKE_CURRENT_FUNCTION}: Generated gcovr ${_GCOVR_SCHEMA_VERSION} configuration: ${CONFIG_FILE}"
    )
endfunction()

# ==============================================================================
# GcovrSchema_Validate
# ==============================================================================
#
# Validate gcovr configuration variables
#
# Returns:
#   Sets GCOVR_SCHEMA_VALID to TRUE/FALSE in parent scope
#
function(GcovrSchema_Validate)
    set(IS_VALID TRUE)
    set(ERRORS "")

    # Validate threshold values are numbers between 0 and 100
    foreach(var GCOVR_FAIL_UNDER_LINE GCOVR_FAIL_UNDER_BRANCH 
                GCOVR_HTML_HIGH_THRESHOLD GCOVR_HTML_MEDIUM_THRESHOLD)
        if(DEFINED ${var})
            if(NOT "${${var}}" MATCHES "^[0-9]+$")
                set(IS_VALID FALSE)
                list(APPEND ERRORS "${var} must be a number (got: ${${var}})")
            elseif(${var} GREATER 100)
                set(IS_VALID FALSE)
                list(APPEND ERRORS "${var} must be <= 100 (got: ${${var}})")
            endif()
        endif()
    endforeach()

    # Validate output formats
    if(DEFINED GCOVR_OUTPUT_FORMATS)
        set(VALID_FORMATS "html" "xml" "json" "cobertura" "coveralls" "lcov" "csv" "txt")
        foreach(format IN LISTS GCOVR_OUTPUT_FORMATS)
            if(NOT format IN_LIST VALID_FORMATS)
                set(IS_VALID FALSE)
                list(APPEND ERRORS "Invalid output format: ${format}. Valid formats: ${VALID_FORMATS}")
            endif()
        endforeach()
    endif()

    if(NOT IS_VALID)
        foreach(error IN LISTS ERRORS)
            message(WARNING "${CMAKE_CURRENT_FUNCTION}: ${error}")
        endforeach()
    endif()

    set(GCOVR_SCHEMA_VALID ${IS_VALID} PARENT_SCOPE)
endfunction()
