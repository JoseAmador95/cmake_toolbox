# ==============================================================================
# CMock Schema Management
# ==============================================================================
#
# This module provides version-aware CMock configuration schema management.
# It handles different CMock versions and generates appropriate YAML configurations
# from cached CMake variables.
#
# FEATURES:
#   - Auto-detection of CMock version from tag
#   - Version-specific schema handling
#   - Cached variable to YAML generation
#   - Sensible defaults per version
#
# ==============================================================================

include_guard(GLOBAL)

# ==============================================================================
# CMockSchema_GetSupportedVersions
# ==============================================================================
#
# Get list of supported CMock versions
#
# Parameters:
#   OUTPUT_VAR - Variable name to store the list of supported versions
#
function(CMockSchema_GetSupportedVersions OUTPUT_VAR)
    set(SUPPORTED_VERSIONS "2.6")
    set(${OUTPUT_VAR} "${SUPPORTED_VERSIONS}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# CMockSchema_DetectVersion
# ==============================================================================
#
# Detect CMock version from executable or fallback to git tag
#
# Parameters:
#   CMOCK_EXE  - Path to CMock Ruby executable
#   TAG        - CMock git tag (fallback, e.g., "v2.6.0", "v2.5.3")
#   OUTPUT_VAR - Variable name to store the detected schema version
#
function(CMockSchema_DetectVersion CMOCK_EXE TAG OUTPUT_VAR)
    set(DETECTED_VERSION "")

    # First try to get version from CMock executable
    if(EXISTS "${CMOCK_EXE}")
        find_program(Ruby_EXECUTABLE ruby)
        if(Ruby_EXECUTABLE)
            execute_process(
                COMMAND
                    ${Ruby_EXECUTABLE} "${CMOCK_EXE}" --version
                OUTPUT_VARIABLE cmock_version_output
                ERROR_VARIABLE cmock_version_error
                RESULT_VARIABLE cmock_version_result
                OUTPUT_STRIP_TRAILING_WHITESPACE
                ERROR_STRIP_TRAILING_WHITESPACE
            )

            if(cmock_version_result EQUAL 0 AND cmock_version_output)
                # Try to extract version from output (common formats: "CMock 2.6.0" or "2.6.0")
                if(cmock_version_output MATCHES "([0-9]+)\\.([0-9]+)")
                    set(DETECTED_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}")
                    message(
                        STATUS
                        "${CMAKE_CURRENT_FUNCTION}: Version detected from executable: ${DETECTED_VERSION}"
                    )
                endif()
            else()
                message(
                    STATUS
                    "${CMAKE_CURRENT_FUNCTION}: Could not query CMock executable version: ${cmock_version_error}"
                )
            endif()
        endif()
    endif()

    # Fallback to git tag parsing if executable query failed
    if(NOT DETECTED_VERSION)
        if(TAG MATCHES "^v?([0-9]+)\\.([0-9]+)")
            set(DETECTED_VERSION "${CMAKE_MATCH_1}.${CMAKE_MATCH_2}")
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Version detected from git tag: ${DETECTED_VERSION}")
        else()
            message(WARNING "${CMAKE_CURRENT_FUNCTION}: Could not parse version from tag: ${TAG}")
        endif()
    endif()

    # Check if detected version is supported
    if(DETECTED_VERSION)
        CMockSchema_GetSupportedVersions(SUPPORTED_VERSIONS)
        if(DETECTED_VERSION IN_LIST SUPPORTED_VERSIONS)
            set(${OUTPUT_VAR} "${DETECTED_VERSION}" PARENT_SCOPE)
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Using CMock schema version: ${DETECTED_VERSION}")
        else()
            set(${OUTPUT_VAR} "" PARENT_SCOPE)
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Unsupported CMock version ${DETECTED_VERSION}")
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Supported versions: ${SUPPORTED_VERSIONS}")
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Falling back to CONFIG_FILE mode")
        endif()
    else()
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
        message(
            STATUS
            "${CMAKE_CURRENT_FUNCTION}: Could not detect CMock version, falling back to CONFIG_FILE mode"
        )
    endif()
endfunction()

# ==============================================================================
# CMockSchema_SetDefaults
# ==============================================================================
#
# Set version-specific default values for CMock configuration variables
#
# Parameters:
#   VERSION - CMock schema version (e.g., "2.6")
#
function(CMockSchema_SetDefaults VERSION)
    # Load version-specific schema
    set(SCHEMA_FILE "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/schemas/cmock-${VERSION}.cmake")
    if(EXISTS "${SCHEMA_FILE}")
        include("${SCHEMA_FILE}")
    message(STATUS "${CMAKE_CURRENT_FUNCTION}: Applied defaults for CMock ${VERSION}")
    else()
    message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Schema file not found: ${SCHEMA_FILE}")
    endif()
endfunction()

# ==============================================================================
# CMockSchema_GenerateConfigFile
# ==============================================================================
#
# Generates a CMock configuration file using the currently detected schema version.
#
# Parameters:
#   CONFIG_FILE - Full path where the YAML configuration file should be generated
#
function(CMockSchema_GenerateConfigFile CONFIG_FILE)
    if(NOT _CMOCK_SCHEMA_VERSION)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: No CMock schema version detected. Call CMockSchema_DetectVersion() first."
        )
    endif()

    cmake_path(GET CONFIG_FILE PARENT_PATH output_dir)
    file(MAKE_DIRECTORY "${output_dir}")

    # Load version-specific schema
    set(SCHEMA_FILE
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/schemas/cmock-${_CMOCK_SCHEMA_VERSION}.cmake"
    )
    if(NOT EXISTS "${SCHEMA_FILE}")
    message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Schema file not found: ${SCHEMA_FILE}")
    endif()

    # Include schema to get generation function
    include("${SCHEMA_FILE}")

    # Call version-specific generation function
    cmake_language(
        CALL
            "CMockSchema_${_CMOCK_SCHEMA_VERSION}_GenerateYAML"
            "${CONFIG_FILE}"
    )

    message(
        STATUS
        "${CMAKE_CURRENT_FUNCTION}: Generated CMock ${_CMOCK_SCHEMA_VERSION} configuration: ${CONFIG_FILE}"
    )
endfunction()
