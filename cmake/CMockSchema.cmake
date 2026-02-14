# SPDX-License-Identifier: MIT
# ==============================================================================
# CMock Configuration Management
# ==============================================================================
#
# This module provides template-based CMock configuration generation.
# It renders the cmock.yml template using cached CMake variables and
# produces a configuration file for CMock.
#
# FEATURES:
#   - Template-based configuration (cmock.yml)
#   - Cached variable defaults
#   - YAML generation with overrides
#
# ==============================================================================

include_guard(GLOBAL)

function(CMockSchema_SetDefaults)
    set(CMOCK_MOCK_PREFIX "mock_" CACHE STRING "Prefix for generated mock file names")

    set(CMOCK_MOCK_SUFFIX "" CACHE STRING "Suffix for generated mock file names")

    set(CMOCK_MOCK_PATH "mocks" CACHE STRING "Subdirectory name for generated mock files")

    set(CMOCK_INCLUDES
        "unity.h"
        CACHE STRING
        "Semicolon-separated list of header files to include in mocks"
    )

    set(CMOCK_PLUGINS
        "ignore;callback"
        CACHE STRING
        "Semicolon-separated list of CMock plugins to enable"
    )

    set(CMOCK_TREAT_AS
        ""
        CACHE STRING
        "Type treatment mappings in TYPE:TREATMENT format (e.g., uint8:HEX8;size_t:HEX32)"
    )

    set(CMOCK_WHEN_NO_PROTOTYPES
        ":warn"
        CACHE STRING
        "Action when no function prototypes found: :ignore, :warn, or :error"
    )

    set(CMOCK_ENFORCE_STRICT_ORDERING OFF CACHE BOOL "Enforce strict call ordering in mocks")

    set(CMOCK_CALLBACK_INCLUDE_COUNT ON CACHE BOOL "Include call count in callback functions")

    set(CMOCK_CALLBACK_AFTER_ARG_CHECK OFF CACHE BOOL "Call callbacks after argument validation")

    set(CMOCK_INCLUDES_H_PRE_ORIG_HEADER
        ""
        CACHE STRING
        "Header content to insert before original header inclusion"
    )

    set(CMOCK_INCLUDES_H_POST_ORIG_HEADER
        ""
        CACHE STRING
        "Header content to insert after original header inclusion"
    )

    set(CMOCK_INCLUDES_C_PRE_HEADER
        ""
        CACHE STRING
        "Source content to insert before header inclusion"
    )

    set(CMOCK_INCLUDES_C_POST_HEADER
        ""
        CACHE STRING
        "Source content to insert after header inclusion"
    )
endfunction()

function(_CMockSchema_BoolToYaml INPUT OUTPUT_VAR)
    if(INPUT)
        set(${OUTPUT_VAR} "true" PARENT_SCOPE)
    else()
        set(${OUTPUT_VAR} "false" PARENT_SCOPE)
    endif()
endfunction()

function(_CMockSchema_NormalizeSymbol INPUT OUTPUT_VAR)
    string(STRIP "${INPUT}" value)
    if(value STREQUAL "")
        set(${OUTPUT_VAR} "" PARENT_SCOPE)
    elseif(value MATCHES "^:")
        set(${OUTPUT_VAR} "${value}" PARENT_SCOPE)
    else()
        set(${OUTPUT_VAR} ":${value}" PARENT_SCOPE)
    endif()
endfunction()

function(_CMockSchema_FindTemplate OUTPUT_VAR)
    set(template_file "")
    set(template_candidates
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/cmock.yml"
        "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/../cmock.yml"
        "${CMAKE_SOURCE_DIR}/cmock.yml"
    )

    foreach(candidate IN LISTS template_candidates)
        if(EXISTS "${candidate}")
            set(template_file "${candidate}")
            break()
        endif()
    endforeach()

    if(NOT template_file)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: cmock.yml template not found. "
            "Provide CONFIG_FILE to Unity functions or add cmock.yml to the project."
        )
    endif()

    set(${OUTPUT_VAR} "${template_file}" PARENT_SCOPE)
endfunction()

function(CMockSchema_GenerateConfigFile CONFIG_FILE)
    if(NOT CONFIG_FILE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE must be provided")
    endif()

    set(options "")
    set(oneValueArgs TEMPLATE_FILE)
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    CMockSchema_SetDefaults()

    cmake_path(GET CONFIG_FILE PARENT_PATH output_dir)
    if(NOT output_dir)
        set(output_dir "${CMAKE_CURRENT_BINARY_DIR}")
    endif()
    file(MAKE_DIRECTORY "${output_dir}")

    if(DEFINED CMOCK_MOCK_SUBDIR AND NOT CMOCK_MOCK_SUBDIR STREQUAL "")
        set(_cmock_mock_subdir "${CMOCK_MOCK_SUBDIR}")
    elseif(DEFINED CMOCK_MOCK_PATH AND NOT CMOCK_MOCK_PATH STREQUAL "")
        set(_cmock_mock_subdir "${CMOCK_MOCK_PATH}")
    else()
        set(_cmock_mock_subdir "mocks")
    endif()

    set(CMOCK_MOCK_PATH_YAML "${output_dir}/${_cmock_mock_subdir}")

    set(CMOCK_INCLUDES_YAML "")
    if(CMOCK_INCLUDES)
        string(REPLACE ";" "\n    - " includes_yaml "${CMOCK_INCLUDES}")
        set(CMOCK_INCLUDES_YAML "    - ${includes_yaml}")
    else()
        set(CMOCK_INCLUDES_YAML "    []")
    endif()

    set(CMOCK_PLUGINS_YAML "")
    if(CMOCK_PLUGINS)
        string(REPLACE ";" "\n    - " plugins_yaml "${CMOCK_PLUGINS}")
        set(CMOCK_PLUGINS_YAML "    - ${plugins_yaml}")
    else()
        set(CMOCK_PLUGINS_YAML "    []")
    endif()

    set(CMOCK_TREAT_AS_YAML "")
    if(CMOCK_TREAT_AS)
        set(CMOCK_TREAT_AS_YAML "  :treat_as:\n")
        foreach(mapping IN LISTS CMOCK_TREAT_AS)
            if(mapping MATCHES "^([^:]+):([^:]+)$")
                set(type "${CMAKE_MATCH_1}")
                set(treatment "${CMAKE_MATCH_2}")
                string(APPEND CMOCK_TREAT_AS_YAML "    ${type}: ${treatment}\n")
            else()
                message(
                    WARNING
                    "${CMAKE_CURRENT_FUNCTION}: Invalid CMOCK_TREAT_AS mapping: ${mapping}"
                )
            endif()
        endforeach()
    endif()

    _CMockSchema_BoolToYaml(
        "${CMOCK_ENFORCE_STRICT_ORDERING}"
        CMOCK_ENFORCE_STRICT_ORDERING_YAML
    )
    _CMockSchema_BoolToYaml(
        "${CMOCK_CALLBACK_INCLUDE_COUNT}"
        CMOCK_CALLBACK_INCLUDE_COUNT_YAML
    )
    _CMockSchema_BoolToYaml(
        "${CMOCK_CALLBACK_AFTER_ARG_CHECK}"
        CMOCK_CALLBACK_AFTER_ARG_CHECK_YAML
    )

    _CMockSchema_NormalizeSymbol(
        "${CMOCK_WHEN_NO_PROTOTYPES}"
        CMOCK_WHEN_NO_PROTOTYPES_YAML
    )

    set(CMOCK_INCLUDES_H_PRE_ORIG_HEADER_YAML "")
    if(CMOCK_INCLUDES_H_PRE_ORIG_HEADER)
        set(
            CMOCK_INCLUDES_H_PRE_ORIG_HEADER_YAML
            "  :includes_h_pre_orig_header: \"${CMOCK_INCLUDES_H_PRE_ORIG_HEADER}\""
        )
    endif()

    set(CMOCK_INCLUDES_H_POST_ORIG_HEADER_YAML "")
    if(CMOCK_INCLUDES_H_POST_ORIG_HEADER)
        set(
            CMOCK_INCLUDES_H_POST_ORIG_HEADER_YAML
            "  :includes_h_post_orig_header: \"${CMOCK_INCLUDES_H_POST_ORIG_HEADER}\""
        )
    endif()

    set(CMOCK_INCLUDES_C_PRE_HEADER_YAML "")
    if(CMOCK_INCLUDES_C_PRE_HEADER)
        set(
            CMOCK_INCLUDES_C_PRE_HEADER_YAML
            "  :includes_c_pre_header: \"${CMOCK_INCLUDES_C_PRE_HEADER}\""
        )
    endif()

    set(CMOCK_INCLUDES_C_POST_HEADER_YAML "")
    if(CMOCK_INCLUDES_C_POST_HEADER)
        set(
            CMOCK_INCLUDES_C_POST_HEADER_YAML
            "  :includes_c_post_header: \"${CMOCK_INCLUDES_C_POST_HEADER}\""
        )
    endif()

    if(DEFINED _CEEDLING_EXTRACT_FUNCTIONS AND _CEEDLING_EXTRACT_FUNCTIONS)
        set(TB_EXTRACT_FUNCTIONS_TF "true")
    else()
        set(TB_EXTRACT_FUNCTIONS_TF "false")
    endif()

    if(ARG_TEMPLATE_FILE)
        set(template_file "${ARG_TEMPLATE_FILE}")
        if(NOT EXISTS "${template_file}")
            message(
                FATAL_ERROR
                "${CMAKE_CURRENT_FUNCTION}: Template file does not exist: ${template_file}"
            )
        endif()
    else()
        _CMockSchema_FindTemplate(template_file)
    endif()

    configure_file("${template_file}" "${CONFIG_FILE}" @ONLY)
endfunction()
