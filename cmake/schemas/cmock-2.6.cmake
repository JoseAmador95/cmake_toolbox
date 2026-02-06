# ==============================================================================
# CMock 2.6 Schema and Configuration Generator
# ==============================================================================
#
# This file defines the schema and default values for CMock version 2.6.x
# It provides cached variable definitions and YAML generation functionality.
#
# ==============================================================================

# CMock 2.6 Configuration Variables (with sensible defaults)
# These can be overridden by the user before calling Unity_Initialize()

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
    "Type treatment mappings in TYPE:TREATMENT;TYPE:TREATMENT format (e.g., uint8_t:HEX8;size_t:HEX32)"
)

set(CMOCK_WHEN_NO_PROTOTYPES
    "warn"
    CACHE STRING
    "Action when no function prototypes found: ignore, warn, or error"
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

set(CMOCK_INCLUDES_C_PRE_HEADER "" CACHE STRING "Source content to insert before header inclusion")

set(CMOCK_INCLUDES_C_POST_HEADER "" CACHE STRING "Source content to insert after header inclusion")

# ==============================================================================
# CMockSchema_2.6_GenerateYAML
# ==============================================================================
#
# Generate CMock 2.6 YAML configuration file from cached variables
#
# Parameters:
#   CONFIG_FILE - Path where the YAML configuration will be written
#
function(CMockSchema_2.6_GenerateYAML CONFIG_FILE)
    # Convert semicolon-separated lists to YAML arrays
    string(REPLACE ";" "\n    - " INCLUDES_YAML "${CMOCK_INCLUDES}")
    string(REPLACE ";" "\n    - " PLUGINS_YAML "${CMOCK_PLUGINS}")

    # Handle TREAT_AS mappings (TYPE:TREATMENT;TYPE:TREATMENT -> YAML)
    set(TREAT_AS_YAML "")
    if(CMOCK_TREAT_AS)
        set(TREAT_AS_YAML "  :treat_as:\n")
        foreach(mapping IN LISTS CMOCK_TREAT_AS)
            if(mapping MATCHES "^([^:]+):([^:]+)$")
                set(type "${CMAKE_MATCH_1}")
                set(treatment "${CMAKE_MATCH_2}")
                string(APPEND TREAT_AS_YAML "    ${type}: ${treatment}\n")
            else()
                message(
                    WARNING
                    "${CMAKE_CURRENT_FUNCTION}: Invalid TREAT_AS mapping format: ${mapping} (expected TYPE:TREATMENT)"
                )
            endif()
        endforeach()
    endif()

    # Generate boolean values
    if(CMOCK_ENFORCE_STRICT_ORDERING)
        set(STRICT_ORDERING_YAML "1")
    else()
        set(STRICT_ORDERING_YAML "0")
    endif()

    if(CMOCK_CALLBACK_INCLUDE_COUNT)
        set(CALLBACK_COUNT_YAML "1")
    else()
        set(CALLBACK_COUNT_YAML "0")
    endif()

    if(CMOCK_CALLBACK_AFTER_ARG_CHECK)
        set(CALLBACK_AFTER_ARG_YAML "1")
    else()
        set(CALLBACK_AFTER_ARG_YAML "0")
    endif()

    # Create directory if it doesn't exist
    get_filename_component(CONFIG_DIR "${CONFIG_FILE}" DIRECTORY)
    file(MAKE_DIRECTORY "${CONFIG_DIR}")

    # Generate YAML content
    set(YAML_CONTENT
        ":cmock:
  :mock_path: '${CONFIG_DIR}/${CMOCK_MOCK_PATH}'
  :mock_prefix: '${CMOCK_MOCK_PREFIX}'
  :mock_suffix: '${CMOCK_MOCK_SUFFIX}'
  :includes:
    - ${INCLUDES_YAML}
  :plugins:
    - ${PLUGINS_YAML}
${TREAT_AS_YAML}  :when_no_prototypes: ${CMOCK_WHEN_NO_PROTOTYPES}
  :enforce_strict_ordering: ${STRICT_ORDERING_YAML}
  :callback_include_count: ${CALLBACK_COUNT_YAML}
  :callback_after_arg_check: ${CALLBACK_AFTER_ARG_YAML}"
    )

    # Add optional includes if provided
    if(CMOCK_INCLUDES_H_PRE_ORIG_HEADER)
        string(
            APPEND
            YAML_CONTENT
            "
  :includes_h_pre_orig_header: \"${CMOCK_INCLUDES_H_PRE_ORIG_HEADER}\""
        )
    endif()

    if(CMOCK_INCLUDES_H_POST_ORIG_HEADER)
        string(
            APPEND
            YAML_CONTENT
            "
  :includes_h_post_orig_header: \"${CMOCK_INCLUDES_H_POST_ORIG_HEADER}\""
        )
    endif()

    if(CMOCK_INCLUDES_C_PRE_HEADER)
        string(
            APPEND
            YAML_CONTENT
            "
  :includes_c_pre_header: \"${CMOCK_INCLUDES_C_PRE_HEADER}\""
        )
    endif()

    if(CMOCK_INCLUDES_C_POST_HEADER)
        string(
            APPEND
            YAML_CONTENT
            "
  :includes_c_post_header: \"${CMOCK_INCLUDES_C_POST_HEADER}\""
        )
    endif()

    # Write YAML file
    file(WRITE "${CONFIG_FILE}" "${YAML_CONTENT}")
endfunction()
