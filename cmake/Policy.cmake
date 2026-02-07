# ==============================================================================
# CMake Policy Management System
# ==============================================================================
#
# This module provides a comprehensive policy management system that mimics
# CMake's built-in policy behavior. It allows registration, management, and
# lifecycle tracking of policies with automatic warning generation.
#
# FEATURES:
#   - Policy registration with version tracking
#   - Automatic warning generation for unset policies
#   - Deprecation and removal notices
#   - "Warn once" behavior to avoid verbose output
#   - CMake-like behavior for policy lifecycle management
#
# POLICY LIFECYCLE:
#   1. CURRENT: Active policy that may have warnings when unset
#   2. DEPRECATED: Policy marked for future removal, always warns
#   3. REMOVED: Policy no longer supported, always warns
#
# WARNING BEHAVIOR:
#   - Current policies: Warn only when accessed without explicit setting
#   - Deprecated policies: Always warn with appropriate message based on set status
#   - Removed policies: Always warn that policy is no longer supported
#   - All warnings shown only once per CMake run to avoid verbose output
#
# USAGE EXAMPLE:
#   # Register a policy
#   Policy_Register(NAME CMP0001 
#                   DESCRIPTION "Modern target_link_libraries usage"
#                   DEFAULT OLD 
#                   INTRODUCED_VERSION 3.0
#                   WARNING "Use PUBLIC/PRIVATE/INTERFACE keywords")
#   
#   # Set policy value
#   Policy_Set(POLICY CMP0001 VALUE NEW)
#   
#   # Get policy value (with automatic warning if unset)
#   Policy_Get(POLICY CMP0001 OUTVAR my_policy_value)
#
# ==============================================================================

# ==============================================================================
# PUBLIC API FUNCTIONS
# ==============================================================================

# ==============================================================================
# Policy_Register
# ==============================================================================
#
# Register a new policy in the policy management system.
#
# Parameters:
#   NAME - The unique identifier for the policy (e.g., "CMP0001")
#   DESCRIPTION - Human-readable description of what the policy controls
#   DEFAULT - Default behavior when policy is not explicitly set: "NEW" or "OLD"
#   INTRODUCED_VERSION - Version when the policy was first introduced (e.g., "3.0")
#   WARNING (optional) - Warning message shown when policy is accessed but not explicitly set
#   DEPRECATED_VERSION (optional) - Version when the policy was deprecated
#   REMOVED_VERSION (optional) - Version when the policy was removed
#
# Example:
#   Policy_Register(NAME CMP0001
#                   DESCRIPTION "Use modern target_link_libraries syntax"
#                   DEFAULT OLD
#                   INTRODUCED_VERSION 3.0
#                   WARNING "Consider using PUBLIC/PRIVATE/INTERFACE keywords"
#                   DEPRECATED_VERSION 4.0)
#
function(Policy_Register)
    set(options)
    set(oneValueArgs
        NAME
        DESCRIPTION
        DEFAULT
        INTRODUCED_VERSION
        WARNING
        DEPRECATED_VERSION
        REMOVED_VERSION
    )
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_NAME)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: requires NAME <policy_name>")
    endif()
    if(NOT ARG_DESCRIPTION)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: requires DESCRIPTION <description>")
    endif()
    if(NOT ARG_DEFAULT)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: requires DEFAULT <NEW|OLD>")
    endif()
    if(NOT ARG_INTRODUCED_VERSION)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: requires INTRODUCED_VERSION <version>")
    endif()

    # WARNING is optional, default to empty string
    if(NOT ARG_WARNING)
        set(ARG_WARNING "")
    endif()

    # DEPRECATED_VERSION and REMOVED_VERSION are optional
    if(NOT ARG_DEPRECATED_VERSION)
        set(ARG_DEPRECATED_VERSION "")
    endif()
    if(NOT ARG_REMOVED_VERSION)
        set(ARG_REMOVED_VERSION "")
    endif()

    # Escape pipe characters in warning message to avoid conflicts with field separator
    string(REPLACE "|" "\\|" _escaped_warning "${ARG_WARNING}")

    _policy_check_newold("${ARG_DEFAULT}")
    _policy_registry_get(_policy_registry)
    foreach(_entry ${_policy_registry})
        if(NOT _entry STREQUAL "")
            string(REPLACE ";" "|" __sep_check "${_entry}")
            string(REPLACE ";" ";" _fields "${_entry}") # legacy, not needed
            separate_arguments(_fields UNIX_COMMAND "${_entry}")
            list(GET _fields 0 _existing)
            if(_existing STREQUAL "${ARG_NAME}")
                message(FATAL_ERROR "POLICY: Already registered: ${ARG_NAME}")
            endif()
        endif()
    endforeach()
    _policy_registry_append(
        "'${ARG_NAME}'|'${ARG_DESCRIPTION}'|'${ARG_DEFAULT}'|'${ARG_INTRODUCED_VERSION}'|'${_escaped_warning}'|'${ARG_DEPRECATED_VERSION}'|'${ARG_REMOVED_VERSION}'"
    )
endfunction()

# ==============================================================================
# Policy_Set
# ==============================================================================
#
# Set the value of a previously registered policy.
#
# Parameters:
#   POLICY - The name of the policy to set (must be previously registered)
#   VALUE - The value to set: "NEW" or "OLD"
#
# Example:
#   Policy_Set(POLICY CMP0001 VALUE NEW)
#
function(Policy_Set POLICY VALUE)
    if(NOT POLICY)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: POLICY parameter is required")
    endif()
    if(NOT VALUE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: VALUE parameter is required")
    endif()

    _policy_find("${POLICY}" _idx)
    if(_idx LESS 0)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: ${POLICY} not registered")
    endif()
    _policy_check_newold("${VALUE}")
    _policy_write("${POLICY}" "${VALUE}")

    # Clear warning flags since the policy state has changed
    # This allows appropriate warnings to be shown again if accessed
    set_property(
        GLOBAL
        PROPERTY
            POLICY_WARNED_CURRENT_${POLICY}
                FALSE
    )
    set_property(
        GLOBAL
        PROPERTY
            POLICY_WARNED_DEPRECATED_UNSET_${POLICY}
                FALSE
    )
    set_property(
        GLOBAL
        PROPERTY
            POLICY_WARNED_DEPRECATED_SET_${POLICY}
                FALSE
    )
    # Note: REMOVED warnings are not cleared as they should always warn once regardless
endfunction()

# ==============================================================================
# Policy_Get
# ==============================================================================
#
# Get the current value of a policy, with automatic warning generation.
#
# Parameters:
#   POLICY - The name of the policy to retrieve (must be previously registered)
#   OUTVAR - Variable name to store the policy value in parent scope
#
# Example:
#   Policy_Get(POLICY CMP0001 OUTVAR my_policy_value)
#   if(my_policy_value STREQUAL "NEW")
#       # Use new behavior
#   endif()
#
function(Policy_Get POLICY OUTVAR)
    if(NOT POLICY)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: POLICY parameter is required")
    endif()
    if(NOT OUTVAR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: OUTVAR parameter is required")
    endif()

    _policy_find("${POLICY}" _idx)
    if(_idx LESS 0)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: ${POLICY} not registered")
    endif()

    # Check policy status and print warnings before getting value
    _policy_check_and_warn("${POLICY}")

    _policy_registry_get(_policy_registry)
    list(GET _policy_registry ${_idx} _entry)
    if("${_entry}" STREQUAL "")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Registry is corrupted or empty for ${POLICY}")
    endif()
    _policy_record_unpack("${_entry}" _fields)
    if(NOT _fields)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Policy entry malformed for ${POLICY}: ${_entry}")
    endif()
    list(LENGTH _fields _field_len)
    if(_field_len LESS 3)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: Policy registry entry too short for ${POLICY} (fields: ${_fields})"
        )
    endif()
    list(GET _fields 2 _def)
    _policy_read(${POLICY} _val)
    if(NOT _val STREQUAL "")
        _policy_check_newold("${_val}")
        set(${OUTVAR} "${_val}" PARENT_SCOPE)
    else()
        message(NOTICE "${CMAKE_CURRENT_FUNCTION}: '${POLICY}' not set, using default: ${_def}")
        set(${OUTVAR} "${_def}" PARENT_SCOPE)
    endif()
endfunction()

# ==============================================================================
# Policy_Version
# ==============================================================================
#
# Set multiple policies based on their introduction version range.
# Mimics CMake's cmake_policy(VERSION) behavior.
#
# Parameters:
#   MINIMUM - Minimum version for policy range
#   MAXIMUM (optional) - Maximum version for policy range
#
# Example:
#   Policy_Version(MINIMUM 3.0 MAXIMUM 3.15)
#   Policy_Version(MINIMUM 3.0)
#
function(Policy_Version)
    set(options)
    set(oneValueArgs
        MINIMUM
        MAXIMUM
    )
    set(multiValueArgs)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_MINIMUM)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: MINIMUM parameter is required"
        )
    endif()

    set(min_version "${ARG_MINIMUM}")
    set(do_max 0)
    if(ARG_MAXIMUM)
        set(max_version "${ARG_MAXIMUM}")
        set(do_max 1)
        
        # Validate that MAXIMUM >= MINIMUM
        _policy_version_compare_gte("${min_version}" "${max_version}" _min_gte_max)
        if(_min_gte_max)
            message(
                FATAL_ERROR
                "${CMAKE_CURRENT_FUNCTION}: MAXIMUM (${max_version}) must be greater than or equal to MINIMUM (${min_version})"
            )
        endif()
    endif()

    _policy_registry_get(_policy_registry)
    foreach(_entry ${_policy_registry})
        if(NOT _entry STREQUAL "")
            _policy_record_unpack("${_entry}" _fields)
            list(LENGTH _fields _field_len)
            if(_field_len LESS 4)
                message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Registry entry too short (fields: ${_fields})")
            endif()
            list(GET _fields 0 pname)
            list(GET _fields 3 introver)
            _policy_version_compare_gte("${min_version}" "${introver}" _gte)
            if(_gte)
                Policy_Set("${pname}" NEW)
            endif()
            if(do_max)
                _policy_version_compare_gte("${introver}" "${max_version}" _overmax)
                if(_overmax)
                    Policy_Set("${pname}" OLD)
                endif()
            endif()
        endif()
    endforeach()
endfunction()

# ==============================================================================
# Policy_Info
# ==============================================================================
#
# Display comprehensive information about a registered policy.
#
# Parameters:
#   POLICY - The name of the policy to display information for
#
# Example:
#   Policy_Info(POLICY CMP0001)
#
function(Policy_Info POLICY)
    if(NOT POLICY)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: POLICY parameter is required")
    endif()

    _policy_find("${POLICY}" _idx)
    if(_idx LESS 0)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: ${POLICY} not registered")
    endif()
    _policy_registry_get(_policy_registry)
    list(GET _policy_registry ${_idx} _entry)
    if("${_entry}" STREQUAL "")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Registry is corrupted or empty for ${POLICY}")
    endif()
    _policy_record_unpack("${_entry}" _fields)
    if(NOT _fields)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Policy entry malformed for ${POLICY}: ${_entry}")
    endif()
    list(LENGTH _fields _field_len)
    if(_field_len LESS 4)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: Policy registry entry too short for ${POLICY} (fields: ${_fields})"
        )
    endif()

    list(GET _fields 0 _name)
    list(GET _fields 1 _desc)
    list(GET _fields 2 _default)
    list(GET _fields 3 _version)

    # Get optional fields
    set(_warning "")
    set(_deprecated_ver "")
    set(_removed_ver "")

    if(_field_len GREATER 4)
        list(GET _fields 4 _warning)
    endif()
    if(_field_len GREATER 5)
        list(GET _fields 5 _deprecated_ver)
    endif()
    if(_field_len GREATER 6)
        list(GET _fields 6 _removed_ver)
    endif()

    # Get current value
    _policy_read("${POLICY}" _current_value)
    if(_current_value STREQUAL "")
        set(_current_value "${_default} (default)")
    endif()

    message(STATUS "Policy Information for ${POLICY}:")
    message(STATUS "  Description: ${_desc}")
    message(STATUS "  Default: ${_default}")
    message(STATUS "  Introduced in version: ${_version}")
    message(STATUS "  Current value: ${_current_value}")

    if(NOT _deprecated_ver STREQUAL "")
        message(STATUS "  Deprecated in version: ${_deprecated_ver}")
    endif()
    if(NOT _removed_ver STREQUAL "")
        message(STATUS "  Removed in version: ${_removed_ver}")
    endif()
    if(NOT _warning STREQUAL "")
        message(STATUS "  Warning: ${_warning}")
    endif()
endfunction()

# ==============================================================================
# Policy_GetFields
# ==============================================================================
#
# Get all fields of a policy as separate variables in parent scope.
#
# Parameters:
#   POLICY - The name of the policy to retrieve fields for
#   PREFIX - Prefix for output variables
#
# Output Variables:
#   ${PREFIX}_NAME - Policy name
#   ${PREFIX}_DESCRIPTION - Policy description
#   ${PREFIX}_DEFAULT - Default value (NEW or OLD)
#   ${PREFIX}_INTRODUCED_VERSION - Version when policy was introduced
#   ${PREFIX}_WARNING - Warning message (empty string if none)
#   ${PREFIX}_DEPRECATED_VERSION - Deprecated version (empty if not deprecated)
#   ${PREFIX}_REMOVED_VERSION - Removed version (empty string if not removed)
#   ${PREFIX}_CURRENT_VALUE - Current value (set or default)
#   ${PREFIX}_IS_DEFAULT - TRUE if using default, FALSE if explicitly set
#
# Example:
#   Policy_GetFields(POLICY CMP0001 PREFIX POLICY_INFO)
#   message(STATUS "Policy: ${POLICY_INFO_NAME}")
#   if(POLICY_INFO_IS_DEFAULT)
#       message(STATUS "Using default value")
#   endif()
#
function(Policy_GetFields POLICY PREFIX)
    if(NOT POLICY)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: POLICY parameter is required")
    endif()
    if(NOT PREFIX)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: PREFIX parameter is required")
    endif()

    _policy_find("${POLICY}" _idx)
    if(_idx LESS 0)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: ${POLICY} not registered")
    endif()
    _policy_registry_get(_policy_registry)
    list(GET _policy_registry ${_idx} _entry)
    if("${_entry}" STREQUAL "")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Registry is corrupted or empty for ${POLICY}")
    endif()
    _policy_record_unpack("${_entry}" _fields)
    if(NOT _fields)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Policy entry malformed for ${POLICY}: ${_entry}")
    endif()
    list(LENGTH _fields _field_len)
    if(_field_len LESS 4)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: Policy registry entry too short for ${POLICY} (fields: ${_fields})"
        )
    endif()

    # Set the basic fields
    list(GET _fields 0 _name)
    list(GET _fields 1 _desc)
    list(GET _fields 2 _default)
    list(GET _fields 3 _version)

    set(${PREFIX}_NAME "${_name}" PARENT_SCOPE)
    set(${PREFIX}_DESCRIPTION "${_desc}" PARENT_SCOPE)
    set(${PREFIX}_DEFAULT "${_default}" PARENT_SCOPE)
    set(${PREFIX}_INTRODUCED_VERSION "${_version}" PARENT_SCOPE)

    # Set optional fields
    if(_field_len GREATER 4)
        list(GET _fields 4 _warning)
        set(${PREFIX}_WARNING "${_warning}" PARENT_SCOPE)
    else()
        set(${PREFIX}_WARNING "" PARENT_SCOPE)
    endif()

    if(_field_len GREATER 5)
        list(GET _fields 5 _deprecated_ver)
        set(${PREFIX}_DEPRECATED_VERSION "${_deprecated_ver}" PARENT_SCOPE)
    else()
        set(${PREFIX}_DEPRECATED_VERSION "" PARENT_SCOPE)
    endif()

    if(_field_len GREATER 6)
        list(GET _fields 6 _removed_ver)
        set(${PREFIX}_REMOVED_VERSION "${_removed_ver}" PARENT_SCOPE)
    else()
        set(${PREFIX}_REMOVED_VERSION "" PARENT_SCOPE)
    endif()

    # Get and set current value
    _policy_read("${POLICY}" _current_value)
    if(_current_value STREQUAL "")
        set(${PREFIX}_CURRENT_VALUE "${_default}" PARENT_SCOPE)
        set(${PREFIX}_IS_DEFAULT TRUE PARENT_SCOPE)
    else()
        set(${PREFIX}_CURRENT_VALUE "${_current_value}" PARENT_SCOPE)
        set(${PREFIX}_IS_DEFAULT FALSE PARENT_SCOPE)
    endif()
endfunction()

# ==============================================================================
# PRIVATE HELPER FUNCTIONS
# ==============================================================================
#
# These functions are internal implementation details and should not be called
# directly by users. They provide core functionality for the public API.
#
# Function Overview:
#   _policy_check_newold     - Validates NEW/OLD values
#   _policy_read/_policy_write - Policy value storage/retrieval  
#   _policy_registry_*       - Policy registry management
#   _policy_record_unpack    - Parse stored policy records
#   _policy_find             - Locate policy in registry
#   _policy_version_compare_gte - Semantic version comparison
#   _policy_check_and_warn   - Warning generation logic
#

# ------------------------------------------------------------------------------
# _policy_check_newold
# ------------------------------------------------------------------------------
# Validates that a policy value is either "NEW" or "OLD".
# Used by policy_register() and policy_set() for input validation.
#
function(_policy_check_newold VALUE)
    if(NOT "${VALUE}" STREQUAL "NEW" AND NOT "${VALUE}" STREQUAL "OLD")
        message(FATAL_ERROR "POLICY: Value must be NEW or OLD (got '${VALUE}').")
    endif()
endfunction()

function(_policy_read POLICY OUTVAR)
    get_property(_policy GLOBAL PROPERTY POLICY_${POLICY})
    set(${OUTVAR} "${_policy}" PARENT_SCOPE)
endfunction()

function(_policy_write POLICY VALUE)
    set_property(
        GLOBAL
        PROPERTY
        PROPERTY
            POLICY_${POLICY}
                "${VALUE}"
    )
endfunction()

function(_policy_registry_write REGISTRY)
    set_property(
        GLOBAL
        PROPERTY
            POLICY_REGISTRY
                "${REGISTRY}"
    )
endfunction()

function(_policy_registry_get OUTVAR)
    get_property(_registry GLOBAL PROPERTY POLICY_REGISTRY)
    set(${OUTVAR} "${_registry}" PARENT_SCOPE)
endfunction()

function(_policy_registry_append RECORD)
    _policy_registry_get(_policy_registry)
    list(APPEND _policy_registry "${RECORD}")
    _policy_registry_write("${_policy_registry}")
endfunction()

function(_policy_record_unpack RECORD OUTVAR)
    # First, temporarily replace escaped pipes with a placeholder
    string(REPLACE "\\|" "___ESCAPED_PIPE___" RECORD "${RECORD}")
    # Then split on pipes to get fields
    string(REPLACE "|" ";" _fields "${RECORD}")
    # Restore escaped pipes and strip quotes from each field
    set(_restored_fields "")
    foreach(_field ${_fields})
        string(REPLACE "___ESCAPED_PIPE___" "|" _field "${_field}")
        # Strip leading and trailing single quotes
        string(REPLACE "'" "" _field "${_field}")
        list(APPEND _restored_fields "${_field}")
    endforeach()
    set(${OUTVAR} "${_restored_fields}" PARENT_SCOPE)
endfunction()

function(_policy_find POLICY_NAME OUTINDEX)
    set(_found -1)
    set(_i 0)
    _policy_registry_get(_policy_registry)
    foreach(_entry ${_policy_registry})
        if(NOT _entry STREQUAL "")
            _policy_record_unpack("${_entry}" _fields)
            list(GET _fields 0 _key)
            if(_key STREQUAL "${POLICY_NAME}")
                set(_found ${_i})
                break()
            endif()
        endif()
        math(EXPR _i "${_i} + 1")
    endforeach()
    set(${OUTINDEX} ${_found} PARENT_SCOPE)
endfunction()

function(_policy_version_compare_gte v1 v2 OUT)
    string(REPLACE "." ";" _v1list "${v1}")
    string(REPLACE "." ";" _v2list "${v2}")
    list(LENGTH _v1list _v1len)
    list(LENGTH _v2list _v2len)
    if(_v1len LESS 3)
        math(EXPR _diff "3 - ${_v1len}")
        foreach(_i RANGE 1 ${_diff})
            list(APPEND _v1list "0")
        endforeach()
    endif()
    if(_v2len LESS 3)
        math(EXPR _diff "3 - ${_v2len}")
        foreach(_i RANGE 1 ${_diff})
            list(APPEND _v2list "0")
        endforeach()
    endif()

    list(GET _v1list 0 _v1maj)
    list(GET _v2list 0 _v2maj)
    list(GET _v1list 1 _v1min)
    list(GET _v2list 1 _v2min)
    list(GET _v1list 2 _v1pat)
    list(GET _v2list 2 _v2pat)

    if(_v1maj GREATER _v2maj)
        set(${OUT} 1 PARENT_SCOPE)
        return()
    elseif(_v1maj LESS _v2maj)
        set(${OUT} 0 PARENT_SCOPE)
        return()
    endif()
    if(_v1min GREATER _v2min)
        set(${OUT} 1 PARENT_SCOPE)
        return()
    elseif(_v1min LESS _v2min)
        set(${OUT} 0 PARENT_SCOPE)
        return()
    endif()
    if(_v1pat GREATER_EQUAL _v2pat)
        set(${OUT} 1 PARENT_SCOPE)
    else()
        set(${OUT} 0 PARENT_SCOPE)
    endif()
endfunction()

# ------------------------------------------------------------------------------
# _policy_check_and_warn
# ------------------------------------------------------------------------------
# Core warning generation logic with "warn once" behavior.
# Determines appropriate warning type based on policy lifecycle stage and
# current set status. Tracks warnings to ensure each scenario only warns once.
#
# Warning Types:
#   - REMOVED: Policy was removed, always warn once regardless of set status
#   - DEPRECATED_UNSET: Policy deprecated and not explicitly set
#   - DEPRECATED_SET: Policy deprecated but explicitly set (shorter message)  
#   - CURRENT: Current policy with warning, only when unset
#
# Tracking: Uses separate global properties for each warning scenario to
# ensure appropriate warnings are shown exactly once per CMake run.
#
function(_policy_check_and_warn POLICY_NAME)
    _policy_find("${POLICY_NAME}" _idx)
    if(_idx LESS 0)
        return() # Policy not found, caller will handle error
    endif()

    _policy_registry_get(_policy_registry)
    list(GET _policy_registry ${_idx} _entry)
    _policy_record_unpack("${_entry}" _fields)
    list(LENGTH _fields _field_len)

    if(_field_len LESS 4)
        return() # Malformed entry, caller will handle error
    endif()

    # Get policy information
    list(GET _fields 0 _name)
    list(GET _fields 1 _desc)
    list(GET _fields 2 _default)
    list(GET _fields 3 _introduced_ver)

    # Get optional fields
    set(_warning "")
    set(_deprecated_ver "")
    set(_removed_ver "")

    if(_field_len GREATER 4)
        list(GET _fields 4 _warning)
    endif()
    if(_field_len GREATER 5)
        list(GET _fields 5 _deprecated_ver)
    endif()
    if(_field_len GREATER 6)
        list(GET _fields 6 _removed_ver)
    endif()

    # Check if policy is explicitly set
    _policy_read("${POLICY_NAME}" _current_value)
    set(_is_explicitly_set FALSE)
    if(NOT _current_value STREQUAL "")
        set(_is_explicitly_set TRUE)
    endif()

    # Determine warning type and check if we've already warned about this specific scenario
    set(_warning_key "")
    set(_should_warn FALSE)

    # Check policy status and determine appropriate warning
    # Priority: REMOVED > DEPRECATED > REGULAR WARNING
    if(NOT _removed_ver STREQUAL "")
        # Policy is removed - always warn regardless of whether it's set
        set(_warning_key "POLICY_WARNED_REMOVED_${POLICY_NAME}")
        get_property(_already_warned GLOBAL PROPERTY ${_warning_key})
        if(NOT _already_warned)
            message(
                AUTHOR_WARNING
                "Policy ${POLICY_NAME} was removed in version ${_removed_ver}. "
                "This policy is no longer supported and should not be used."
            )
            set(_should_warn TRUE)
        endif()
    elseif(NOT _deprecated_ver STREQUAL "")
        # Policy is deprecated - different warning based on whether it's set
        if(NOT _is_explicitly_set)
            set(_warning_key "POLICY_WARNED_DEPRECATED_UNSET_${POLICY_NAME}")
            get_property(_already_warned GLOBAL PROPERTY ${_warning_key})
            if(NOT _already_warned)
                message(
                    AUTHOR_WARNING
                    "Policy ${POLICY_NAME} is deprecated since version ${_deprecated_ver}. "
                    "Please set this policy explicitly using cmake_policy(SET ${POLICY_NAME} NEW) or cmake_policy(SET ${POLICY_NAME} OLD). "
                    "This policy will be removed in a future version."
                )
                set(_should_warn TRUE)
            endif()
        else()
            set(_warning_key "POLICY_WARNED_DEPRECATED_SET_${POLICY_NAME}")
            get_property(_already_warned GLOBAL PROPERTY ${_warning_key})
            if(NOT _already_warned)
                message(
                    AUTHOR_WARNING
                    "Policy ${POLICY_NAME} is deprecated since version ${_deprecated_ver} "
                    "and will be removed in a future version."
                )
                set(_should_warn TRUE)
            endif()
        endif()
    else()
        # Policy is current - print warning only if not explicitly set and has a warning
        if(NOT _is_explicitly_set AND NOT _warning STREQUAL "")
            set(_warning_key "POLICY_WARNED_CURRENT_${POLICY_NAME}")
            get_property(_already_warned GLOBAL PROPERTY ${_warning_key})
            if(NOT _already_warned)
                message(
                    AUTHOR_WARNING
                    "Policy ${POLICY_NAME}: ${_warning} "
                    "Please set this policy explicitly using cmake_policy(SET ${POLICY_NAME} NEW) or cmake_policy(SET ${POLICY_NAME} OLD)."
                )
                set(_should_warn TRUE)
            endif()
        endif()
    endif()

    # Mark this specific warning scenario as shown
    if(_should_warn AND NOT _warning_key STREQUAL "")
        set_property(
            GLOBAL
            PROPERTY
                ${_warning_key}
                    TRUE
        )
    endif()
endfunction()
