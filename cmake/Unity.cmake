# SPDX-License-Identifier: MIT
# ==============================================================================
# Unity Testing Framework Integration
# ==============================================================================
#
# This module provides integration with the Unity testing framework and CMock
# mocking library for C unit testing. It handles dependency management,
# configuration, and provides utilities for generating mocks and test runners.
#
# FEATURES:
#   - Automatic Unity and CMock dependency fetching
#   - Template-based CMock configuration via cached variables
#   - Mock generation from header files
#   - Test runner generation for Unity tests
#   - Configurable output directories and naming conventions
#   - Support for Ceedling extract functions mode
#   - Backward compatibility with CONFIG_FILE parameter
#
# CONFIGURATION VARIABLES:
#   Set these cached variables to configure CMock behavior:
#   - CMT_CMOCK_MOCK_PREFIX     - Prefix for mock files (default: "mock_")
#   - CMT_CMOCK_MOCK_SUFFIX     - Suffix for mock files (default: "")
#   - CMT_CMOCK_MOCK_PATH       - Mock subdirectory (default: "mocks")
#   - CMOCK_INCLUDES        - Semicolon list of includes (default: "unity.h")
#   - CMOCK_PLUGINS         - Semicolon list of plugins (default: "ignore;callback")
#   - CMOCK_TREAT_AS        - Type mappings: "TYPE:TREATMENT;..." (default: "")
#   - CMOCK_WHEN_NO_PROTOTYPES - Action for missing prototypes (default: "warn")
#   - CMT_CMOCK_ENFORCE_STRICT_ORDERING - Strict call ordering (default: OFF)
#   - CMT_CMOCK_MEM_DYNAMIC     - Use dynamic memory allocation (default: OFF)
#   - CMT_CMOCK_MEM_SIZE        - Memory pool size in bytes (static or dynamic increment)
#
# USAGE EXAMPLE:
#   # Configure CMock (optional - sensible defaults provided)
#   set(CMT_CMOCK_MOCK_PREFIX "Mock")
#   set(CMOCK_PLUGINS "ignore;callback;expect_any_args")
#   set(CMOCK_TREAT_AS "uint8_t:HEX8;uint16_t:HEX16;size_t:HEX32")
#
#   # Initialize Unity (call once per project)
#   Unity_Initialize()
#
#   # Generate mock for a header file (CONFIG_FILE now optional)
#   Unity_GenerateMock(
#       HEADER path/to/interface.h
#       OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}
#       MOCK_SOURCE_VAR mock_src
#       MOCK_HEADER_VAR mock_hdr
#   )
#
#   # Generate test runner (CONFIG_FILE now optional)
#   Unity_GenerateRunner(
#       TEST_SOURCE test_example.c
#       RUNNER_SOURCE_VAR runner_src
#   )
#
#   # Create complete test target (CONFIG_FILE now optional)
#   Unity_CreateTestTarget(
#       TARGET_NAME test_my_module
#       TEST_SOURCE test_my_module.c
#       MOCK_HEADERS interface.h protocol.h
#   )
#
# ==============================================================================

include_guard(GLOBAL)
include(CMockSchema)

option(CMT_CMOCK_MEM_DYNAMIC "Use dynamic memory allocation in CMock" OFF)
set(CMT_CMOCK_MEM_SIZE "" CACHE STRING "CMock memory pool size in bytes (empty uses CMock default)")

# Default repository and version configuration (can be overridden before calling Unity_Initialize)
set(CMT_UNITY_DEFAULT_REPO "https://github.com/ThrowTheSwitch/Unity.git")
set(CMT_UNITY_DEFAULT_TAG "v2.6.1")
set(CMT_CMOCK_DEFAULT_REPO "https://github.com/ThrowTheSwitch/CMock.git")
set(CMT_CMOCK_DEFAULT_TAG "v2.6.0")

# Internal state tracking
set(CMT_UNITY_INITIALIZED FALSE CACHE INTERNAL "Unity initialization status")

# ==============================================================================
# INITIALIZATION FUNCTION
# ==============================================================================

# ==============================================================================
# Unity_Initialize
# ==============================================================================
#
# Initialize Unity and CMock dependencies. Must be called once per project.
#
# Parameters:
#   CMT_UNITY_REPO        - Unity repository URL (optional, default: ThrowTheSwitch/Unity)
#   CMT_UNITY_TAG         - Unity version tag (optional, default: v2.6.1)
#   CMT_CMOCK_REPO        - CMock repository URL (optional, default: ThrowTheSwitch/CMock)
#   CMT_CMOCK_TAG         - CMock version tag (optional, default: v2.6.0)
#   ENABLE_CEEDLING   - Enable Ceedling extract functions mode (optional, default: OFF)
#
function(Unity_Initialize)
    # Prevent double initialization
    if(CMT_UNITY_INITIALIZED)
        return()
    endif()

    set(options ENABLE_CEEDLING)
    set(oneValueArgs
        CMT_UNITY_REPO
        CMT_UNITY_TAG
        CMT_CMOCK_REPO
        CMT_CMOCK_TAG
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Set defaults if not provided
    if(NOT ARG_UNITY_REPO)
        if(DEFINED CMT_UNITY_GIT_REPOSITORY AND NOT CMT_UNITY_GIT_REPOSITORY STREQUAL "")
            set(ARG_UNITY_REPO ${CMT_UNITY_GIT_REPOSITORY})
        else()
            set(ARG_UNITY_REPO ${CMT_UNITY_DEFAULT_REPO})
        endif()
    endif()
    if(NOT ARG_UNITY_TAG)
        if(DEFINED CMT_UNITY_GIT_TAG AND NOT CMT_UNITY_GIT_TAG STREQUAL "")
            set(ARG_UNITY_TAG ${CMT_UNITY_GIT_TAG})
        else()
            set(ARG_UNITY_TAG ${CMT_UNITY_DEFAULT_TAG})
        endif()
    endif()
    if(NOT ARG_CMOCK_REPO)
        if(DEFINED CMT_CMOCK_GIT_REPOSITORY AND NOT CMT_CMOCK_GIT_REPOSITORY STREQUAL "")
            set(ARG_CMOCK_REPO ${CMT_CMOCK_GIT_REPOSITORY})
        else()
            set(ARG_CMOCK_REPO ${CMT_CMOCK_DEFAULT_REPO})
        endif()
    endif()
    if(NOT ARG_CMOCK_TAG)
        if(DEFINED CMT_CMOCK_GIT_TAG AND NOT CMT_CMOCK_GIT_TAG STREQUAL "")
            set(ARG_CMOCK_TAG ${CMT_CMOCK_GIT_TAG})
        else()
            set(ARG_CMOCK_TAG ${CMT_CMOCK_DEFAULT_TAG})
        endif()
    endif()

    # Store configuration globally for internal use
    set(CMT_UNITY_REPO ${ARG_UNITY_REPO} CACHE INTERNAL "Unity repository URL")
    set(CMT_UNITY_TAG ${ARG_UNITY_TAG} CACHE INTERNAL "Unity version tag")
    set(CMT_CMOCK_REPO ${ARG_CMOCK_REPO} CACHE INTERNAL "CMock repository URL")
    set(CMT_CMOCK_TAG ${ARG_CMOCK_TAG} CACHE INTERNAL "CMock version tag")
    set(_CEEDLING_EXTRACT_FUNCTIONS
        ${ARG_ENABLE_CEEDLING}
        CACHE INTERNAL
        "Ceedling extract functions mode"
    )

    # Use FindUnity to locate or fetch Unity and CMock
    set(UNITY_FETCH ON)
    set(CMT_UNITY_GIT_REPOSITORY ${ARG_UNITY_REPO})
    set(CMT_UNITY_GIT_TAG ${ARG_UNITY_TAG})
    set(CMT_CMOCK_GIT_REPOSITORY ${ARG_CMOCK_REPO})
    set(CMT_CMOCK_GIT_TAG ${ARG_CMOCK_TAG})

    find_package(Unity REQUIRED)

    if(TARGET Unity::CMock)
        get_target_property(_cmt_unity_cmock_target Unity::CMock ALIASED_TARGET)
        if(NOT _cmt_unity_cmock_target OR _cmt_unity_cmock_target MATCHES "-NOTFOUND$")
            set(_cmt_unity_cmock_target Unity::CMock)
        endif()

        if(CMT_CMOCK_MEM_DYNAMIC)
            target_compile_definitions(${_cmt_unity_cmock_target} PUBLIC CMT_CMOCK_MEM_DYNAMIC)
        endif()
        if(DEFINED CMT_CMOCK_MEM_SIZE AND NOT CMT_CMOCK_MEM_SIZE STREQUAL "")
            set(_cmt_unity_cmock_mem_size "${CMT_CMOCK_MEM_SIZE}")
            string(STRIP "${_cmt_unity_cmock_mem_size}" _cmt_unity_cmock_mem_size)
            if(NOT _cmt_unity_cmock_mem_size STREQUAL "")
                if(NOT _cmt_unity_cmock_mem_size MATCHES "^[1-9][0-9]*$")
                    message(
                        FATAL_ERROR
                        "${CMAKE_CURRENT_FUNCTION}: CMT_CMOCK_MEM_SIZE must be a positive integer, "
                        "but is '${_cmt_unity_cmock_mem_size}'"
                    )
                endif()
                target_compile_definitions(
                    ${_cmt_unity_cmock_target}
                    PUBLIC
                        "CMT_CMOCK_MEM_SIZE=${_cmt_unity_cmock_mem_size}"
                )
            endif()
        endif()
    endif()

    # Find Ruby executable for CMock and runner generation
    find_program(Ruby_EXECUTABLE ruby REQUIRED)

    # Set up paths from FindUnity results
    if(CMT_CMOCK_EXECUTABLE)
        set(CMT_CMOCK_EXE ${CMT_CMOCK_EXECUTABLE} CACHE INTERNAL "CMock executable path")
    endif()

    if(Unity_RUNNER_GENERATOR)
        set(CMT_UNITY_RUNNER_EXE
            ${Unity_RUNNER_GENERATOR}
            CACHE INTERNAL
            "Unity runner generator path"
        )
    else()
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Unity runner generator not found")
    endif()

    # Set up template-based CMock configuration
    if(CMT_CMOCK_EXE)
        CMockSchema_SetDefaults()
        message(
            STATUS
            "${CMAKE_CURRENT_FUNCTION}: Using template-based CMock configuration (cmock.yml)"
        )
        message(
            STATUS
            "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE in Unity functions overrides the template"
        )
    else()
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: CMock not found - mocking features unavailable")
    endif()

    # Configure Ceedling extract functions mode if enabled
    if(ARG_ENABLE_CEEDLING AND TARGET Unity::Unity)
        target_compile_definitions(Unity::Unity PUBLIC UNITY_USE_COMMAND_LINE_ARGS)
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Ceedling extract functions mode enabled")
    endif()

    # Mark as initialized globally
    set(CMT_UNITY_INITIALIZED TRUE CACHE INTERNAL "Unity initialization status")
    message(STATUS "${CMAKE_CURRENT_FUNCTION}: Unity testing framework initialized")
endfunction()
# ==============================================================================
# PUBLIC API FUNCTIONS
# ==============================================================================

# ==============================================================================
# Unity_GenerateMock
# ==============================================================================
#
# Generate mock files from a header file using CMock
#
# Parameters:
#   HEADER            - Path to the header file to mock (required)
#   OUTPUT_DIR        - Directory where mock files will be generated (required)
#   MOCK_SOURCE_VAR   - Variable name to store the generated mock source file path (required)
#   MOCK_HEADER_VAR   - Variable name to store the generated mock header file path (required)
#   CONFIG_FILE       - Path to the CMock configuration file (optional, overrides template)
#   MOCK_PREFIX       - Prefix for mock files (optional, overrides CMT_CMOCK_MOCK_PREFIX)
#   MOCK_SUFFIX       - Suffix for mock files (optional, overrides CMT_CMOCK_MOCK_SUFFIX)
#   MOCK_SUBDIR       - Subdirectory name for mocks (optional, overrides CMT_CMOCK_MOCK_PATH)
#
function(Unity_GenerateMock)
    # Check if Unity is initialized
    if(NOT CMT_UNITY_INITIALIZED)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Unity_Initialize() must be called first")
    endif()

    set(options "")
    set(oneValueArgs
        HEADER
        OUTPUT_DIR
        CONFIG_FILE
        MOCK_SOURCE_VAR
        MOCK_HEADER_VAR
        MOCK_PREFIX
        MOCK_SUFFIX
        MOCK_SUBDIR
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate required parameters
    if(NOT ARG_HEADER)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: HEADER must be provided")
    endif()

    if(NOT ARG_OUTPUT_DIR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: OUTPUT_DIR must be provided")
    endif()

    if(NOT ARG_MOCK_SOURCE_VAR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: MOCK_SOURCE_VAR must be provided")
    endif()

    if(NOT ARG_MOCK_HEADER_VAR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: MOCK_HEADER_VAR must be provided")
    endif()

    # Validate files exist
    if(NOT EXISTS "${ARG_HEADER}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Header file does not exist: ${ARG_HEADER}")
    endif()

    # Generate configuration file (template or user-provided)
    set(GENERATED_CONFIG_FILE "${ARG_OUTPUT_DIR}/cmock.yml")
    if(ARG_CONFIG_FILE)
        if(NOT EXISTS "${ARG_CONFIG_FILE}")
            message(
                FATAL_ERROR
                "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}"
            )
        endif()
        CMockSchema_GenerateConfigFile(
            "${GENERATED_CONFIG_FILE}"
            TEMPLATE_FILE "${ARG_CONFIG_FILE}"
        )
    else()
        CMockSchema_GenerateConfigFile("${GENERATED_CONFIG_FILE}")
    endif()

    # Set defaults for optional parameters
    if(NOT ARG_MOCK_PREFIX)
        if(DEFINED CMT_CMOCK_MOCK_PREFIX)
            set(ARG_MOCK_PREFIX "${CMT_CMOCK_MOCK_PREFIX}")
        else()
            set(ARG_MOCK_PREFIX "mock_")
        endif()
    endif()

    if(NOT ARG_MOCK_SUFFIX)
        if(DEFINED CMT_CMOCK_MOCK_SUFFIX)
            set(ARG_MOCK_SUFFIX "${CMT_CMOCK_MOCK_SUFFIX}")
        else()
            set(ARG_MOCK_SUFFIX "")
        endif()
    endif()

    if(NOT ARG_MOCK_SUBDIR)
        if(DEFINED CMT_CMOCK_MOCK_SUBDIR AND NOT CMT_CMOCK_MOCK_SUBDIR STREQUAL "")
            set(ARG_MOCK_SUBDIR "${CMT_CMOCK_MOCK_SUBDIR}")
        elseif(DEFINED CMT_CMOCK_MOCK_PATH AND NOT CMT_CMOCK_MOCK_PATH STREQUAL "")
            set(ARG_MOCK_SUBDIR "${CMT_CMOCK_MOCK_PATH}")
        else()
            set(ARG_MOCK_SUBDIR "mocks")
        endif()
    endif()

    # Extract header filename without extension
    cmake_path(GET ARG_HEADER STEM header_name)

    # Create mock directory
    set(MOCK_DIR "${ARG_OUTPUT_DIR}/${ARG_MOCK_SUBDIR}")
    file(MAKE_DIRECTORY "${MOCK_DIR}")

    # Generate mock file paths
    set(MOCK_SOURCE "${MOCK_DIR}/${ARG_MOCK_PREFIX}${header_name}${ARG_MOCK_SUFFIX}.c")
    set(MOCK_HEADER "${MOCK_DIR}/${ARG_MOCK_PREFIX}${header_name}${ARG_MOCK_SUFFIX}.h")

    # Create custom command to generate mock files
    add_custom_command(
        OUTPUT
            ${MOCK_SOURCE}
            ${MOCK_HEADER}
        COMMAND
            ${Ruby_EXECUTABLE} ${CMT_CMOCK_EXE} ${ARG_HEADER} -o${GENERATED_CONFIG_FILE}
        WORKING_DIRECTORY ${ARG_OUTPUT_DIR}
        DEPENDS
            ${GENERATED_CONFIG_FILE}
            ${ARG_HEADER}
        COMMENT "Generating mock for ${ARG_HEADER}"
        VERBATIM
    )

    # Return generated file paths
    set(${ARG_MOCK_SOURCE_VAR} ${MOCK_SOURCE} PARENT_SCOPE)
    set(${ARG_MOCK_HEADER_VAR} ${MOCK_HEADER} PARENT_SCOPE)
endfunction()

# ==============================================================================
# Unity_GenerateRunner
# ==============================================================================
#
# Generate a test runner file for a Unity test source file
#
# Parameters:
#   TEST_SOURCE       - Path to the test source file (required)
#   OUTPUT_DIR        - Directory where runner file will be generated (required)
#   CONFIG_FILE       - Path to the CMock configuration file (optional, overrides template)
#   RUNNER_SOURCE_VAR - Variable name to store the generated runner source file path (required)
#
function(Unity_GenerateRunner)
    # Check if Unity is initialized
    if(NOT CMT_UNITY_INITIALIZED)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Unity_Initialize() must be called first")
    endif()

    set(options "")
    set(oneValueArgs
        TEST_SOURCE
        OUTPUT_DIR
        CONFIG_FILE
        RUNNER_SOURCE_VAR
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate required parameters
    if(NOT ARG_TEST_SOURCE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TEST_SOURCE must be provided")
    endif()

    if(NOT ARG_OUTPUT_DIR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: OUTPUT_DIR must be provided")
    endif()

    if(NOT ARG_RUNNER_SOURCE_VAR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: RUNNER_SOURCE_VAR must be provided")
    endif()

    # Validate files exist
    if(NOT EXISTS "${ARG_TEST_SOURCE}")
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: Test source file does not exist: ${ARG_TEST_SOURCE}"
        )
    endif()

    # Generate configuration file (template or user-provided)
    set(GENERATED_CONFIG_FILE "${ARG_OUTPUT_DIR}/cmock.yml")
    if(ARG_CONFIG_FILE)
        if(NOT EXISTS "${ARG_CONFIG_FILE}")
            message(
                FATAL_ERROR
                "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}"
            )
        endif()
        CMockSchema_GenerateConfigFile(
            "${GENERATED_CONFIG_FILE}"
            TEMPLATE_FILE "${ARG_CONFIG_FILE}"
        )
    else()
        CMockSchema_GenerateConfigFile("${GENERATED_CONFIG_FILE}")
    endif()

    # Extract test filename without extension
    cmake_path(GET ARG_TEST_SOURCE STEM test_name)

    # Create runner directory
    set(RUNNER_DIR "${ARG_OUTPUT_DIR}/runners")
    file(MAKE_DIRECTORY "${RUNNER_DIR}")

    # Generate runner file path
    set(RUNNER_SOURCE "${RUNNER_DIR}/${test_name}_runner.c")

    # Create custom command to generate runner file
    add_custom_command(
        OUTPUT
            ${RUNNER_SOURCE}
        COMMAND
            ${Ruby_EXECUTABLE} ${CMT_UNITY_RUNNER_EXE} ${GENERATED_CONFIG_FILE} ${ARG_TEST_SOURCE}
            ${RUNNER_SOURCE}
        DEPENDS
            ${ARG_TEST_SOURCE}
            ${GENERATED_CONFIG_FILE}
        COMMENT "Generating test runner for ${ARG_TEST_SOURCE}"
        VERBATIM
    )

    # Return generated file path
    set(${ARG_RUNNER_SOURCE_VAR} ${RUNNER_SOURCE} PARENT_SCOPE)
endfunction()

# ==============================================================================
# Unity_CreateTestTarget
# ==============================================================================
#
# Create a complete Unity test target with optional mocks and automatic runner generation
#
# Parameters:
#   TARGET_NAME       - Name of the test target to create (required)
#   TEST_SOURCE       - Path to the test source file (required)
#   CONFIG_FILE       - Path to the CMock configuration file (optional, overrides template)
#   OUTPUT_DIR        - Directory for generated files (optional, defaults to current binary dir)
#   MOCK_HEADERS      - List of header files to mock (optional)
#   SOURCES           - Additional source files to compile with the test (optional)
#   INCLUDE_DIRS      - Additional include directories (optional)
#   LINK_LIBRARIES    - Additional libraries to link (optional)
#   MOCK_PREFIX       - Prefix for mock files (optional, default: mock_)
#   MOCK_SUFFIX       - Suffix for mock files (optional, default: empty)
#   MOCK_SUBDIR       - Subdirectory name for mocks (optional, default: mocks)
#
function(Unity_CreateTestTarget)
    # Check if Unity is initialized
    if(NOT CMT_UNITY_INITIALIZED)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Unity_Initialize() must be called first")
    endif()

    set(options "")
    set(oneValueArgs
        TARGET_NAME
        TEST_SOURCE
        CONFIG_FILE
        OUTPUT_DIR
        MOCK_PREFIX
        MOCK_SUFFIX
        MOCK_SUBDIR
    )
    set(multiValueArgs
        MOCK_HEADERS
        SOURCES
        INCLUDE_DIRS
        LINK_LIBRARIES
    )
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate required parameters
    if(NOT ARG_TARGET_NAME)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET_NAME must be provided")
    endif()

    if(NOT ARG_TEST_SOURCE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TEST_SOURCE must be provided")
    endif()

    # Validate files exist
    if(NOT EXISTS "${ARG_TEST_SOURCE}")
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: Test source file does not exist: ${ARG_TEST_SOURCE}"
        )
    endif()

    # Validate configuration if provided
    if(ARG_CONFIG_FILE AND NOT EXISTS "${ARG_CONFIG_FILE}")
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}"
        )
    endif()

    # Set defaults
    if(NOT ARG_OUTPUT_DIR)
        set(ARG_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
    endif()

    if(NOT ARG_MOCK_PREFIX)
        if(DEFINED CMT_CMOCK_MOCK_PREFIX)
            set(ARG_MOCK_PREFIX "${CMT_CMOCK_MOCK_PREFIX}")
        else()
            set(ARG_MOCK_PREFIX "mock_")
        endif()
    endif()

    if(NOT ARG_MOCK_SUFFIX)
        if(DEFINED CMT_CMOCK_MOCK_SUFFIX)
            set(ARG_MOCK_SUFFIX "${CMT_CMOCK_MOCK_SUFFIX}")
        else()
            set(ARG_MOCK_SUFFIX "")
        endif()
    endif()

    if(NOT ARG_MOCK_SUBDIR)
        if(DEFINED CMT_CMOCK_MOCK_SUBDIR AND NOT CMT_CMOCK_MOCK_SUBDIR STREQUAL "")
            set(ARG_MOCK_SUBDIR "${CMT_CMOCK_MOCK_SUBDIR}")
        elseif(DEFINED CMT_CMOCK_MOCK_PATH AND NOT CMT_CMOCK_MOCK_PATH STREQUAL "")
            set(ARG_MOCK_SUBDIR "${CMT_CMOCK_MOCK_PATH}")
        else()
            set(ARG_MOCK_SUBDIR "mocks")
        endif()
    endif()

    # Set CONFIG_FILE argument if provided
    set(CONFIG_FILE_ARG "")
    if(ARG_CONFIG_FILE)
        set(CONFIG_FILE_ARG
            "CONFIG_FILE"
            "${ARG_CONFIG_FILE}"
        )
    endif()

    # Generate runner for the test
    Unity_GenerateRunner(
        TEST_SOURCE ${ARG_TEST_SOURCE}
        OUTPUT_DIR ${ARG_OUTPUT_DIR}
        ${CONFIG_FILE_ARG}
        RUNNER_SOURCE_VAR runner_source
    )

    # Collect all source files
    set(all_sources
        ${ARG_TEST_SOURCE}
        ${runner_source}
    )
    if(ARG_SOURCES)
        list(APPEND all_sources ${ARG_SOURCES})
    endif()

    # Generate mocks if requested
    set(mock_sources "")
    if(ARG_MOCK_HEADERS)
        foreach(header IN LISTS ARG_MOCK_HEADERS)
            Unity_GenerateMock(
                HEADER ${header}
                OUTPUT_DIR ${ARG_OUTPUT_DIR}
                ${CONFIG_FILE_ARG}
                MOCK_SOURCE_VAR mock_src
                MOCK_HEADER_VAR mock_hdr
                MOCK_PREFIX ${ARG_MOCK_PREFIX}
                MOCK_SUFFIX ${ARG_MOCK_SUFFIX}
                MOCK_SUBDIR ${ARG_MOCK_SUBDIR}
            )
            list(APPEND mock_sources ${mock_src})
            list(APPEND all_sources ${mock_src})
        endforeach()
    endif()

    # Create the test executable
    add_executable(${ARG_TARGET_NAME} ${all_sources})

    # Link required libraries
    if(TARGET Unity::Unity)
        target_link_libraries(${ARG_TARGET_NAME} PRIVATE Unity::Unity)
    endif()
    if(ARG_MOCK_HEADERS AND TARGET Unity::CMock)
        target_link_libraries(${ARG_TARGET_NAME} PRIVATE Unity::CMock)
    endif()
    if(ARG_LINK_LIBRARIES)
        target_link_libraries(${ARG_TARGET_NAME} PRIVATE ${ARG_LINK_LIBRARIES})
    endif()

    # Set include directories
    if(ARG_INCLUDE_DIRS)
        target_include_directories(${ARG_TARGET_NAME} PRIVATE ${ARG_INCLUDE_DIRS})
    endif()

    # Add mock directory to includes if mocks were generated
    if(ARG_MOCK_HEADERS)
        target_include_directories(${ARG_TARGET_NAME} PRIVATE ${ARG_OUTPUT_DIR}/${ARG_MOCK_SUBDIR})
    endif()

    # Disable linting for test targets
    set_target_properties(
        ${ARG_TARGET_NAME}
        PROPERTIES
            C_CLANG_TIDY
                ""
            SKIP_LINTING
                TRUE
    )

    message(STATUS "Unity: Created test target '${ARG_TARGET_NAME}'")
endfunction()
