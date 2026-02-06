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
#   - Version-aware CMock configuration via cached variables
#   - Mock generation from header files
#   - Test runner generation for Unity tests
#   - Configurable output directories and naming conventions
#   - Support for Ceedling extract functions mode
#   - Backward compatibility with CONFIG_FILE parameter
#
# CONFIGURATION VARIABLES:
#   Set these cached variables to configure CMock behavior:
#   - CMOCK_MOCK_PREFIX     - Prefix for mock files (default: "mock_")
#   - CMOCK_MOCK_SUFFIX     - Suffix for mock files (default: "")
#   - CMOCK_MOCK_PATH       - Mock subdirectory (default: "mocks")
#   - CMOCK_INCLUDES        - Semicolon list of includes (default: "unity.h")
#   - CMOCK_PLUGINS         - Semicolon list of plugins (default: "ignore;callback")
#   - CMOCK_TREAT_AS        - Type mappings: "TYPE:TREATMENT;..." (default: "")
#   - CMOCK_WHEN_NO_PROTOTYPES - Action for missing prototypes (default: "warn")
#   - CMOCK_ENFORCE_STRICT_ORDERING - Strict call ordering (default: OFF)
#
# USAGE EXAMPLE:
#   # Configure CMock (optional - sensible defaults provided)
#   set(CMOCK_MOCK_PREFIX "Mock")
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

# Default repository and version configuration (can be overridden before calling Unity_Initialize)
set(_UNITY_DEFAULT_REPO "https://github.com/ThrowTheSwitch/Unity.git")
set(_UNITY_DEFAULT_TAG "v2.6.1")
set(_CMOCK_DEFAULT_REPO "https://github.com/ThrowTheSwitch/CMock.git")
set(_CMOCK_DEFAULT_TAG "v2.6.0")

# Internal state tracking
set(_UNITY_INITIALIZED FALSE CACHE INTERNAL "Unity initialization status")
set(_CMOCK_SCHEMA_VERSION "" CACHE INTERNAL "Detected CMock schema version")
set(_CMOCK_CONFIG_MODE "" CACHE INTERNAL "CMock configuration mode: SCHEMA or CONFIG_FILE")

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
#   UNITY_REPO        - Unity repository URL (optional, default: ThrowTheSwitch/Unity)
#   UNITY_TAG         - Unity version tag (optional, default: v2.6.0)
#   CMOCK_REPO        - CMock repository URL (optional, default: ThrowTheSwitch/CMock)
#   CMOCK_TAG         - CMock version tag (optional, default: v2.5.3)
#   ENABLE_CEEDLING   - Enable Ceedling extract functions mode (optional, default: OFF)
#
function(Unity_Initialize)
    # Prevent double initialization
    if(_UNITY_INITIALIZED)
        return()
    endif()

    set(options ENABLE_CEEDLING)
    set(oneValueArgs
        UNITY_REPO
        UNITY_TAG
        CMOCK_REPO
        CMOCK_TAG
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Set defaults if not provided
    if(NOT ARG_UNITY_REPO)
        set(ARG_UNITY_REPO ${_UNITY_DEFAULT_REPO})
    endif()
    if(NOT ARG_UNITY_TAG)
        set(ARG_UNITY_TAG ${_UNITY_DEFAULT_TAG})
    endif()
    if(NOT ARG_CMOCK_REPO)
        set(ARG_CMOCK_REPO ${_CMOCK_DEFAULT_REPO})
    endif()
    if(NOT ARG_CMOCK_TAG)
        set(ARG_CMOCK_TAG ${_CMOCK_DEFAULT_TAG})
    endif()

    # Store configuration globally for internal use
    set(_UNITY_REPO ${ARG_UNITY_REPO} CACHE INTERNAL "Unity repository URL")
    set(_UNITY_TAG ${ARG_UNITY_TAG} CACHE INTERNAL "Unity version tag")
    set(_CMOCK_REPO ${ARG_CMOCK_REPO} CACHE INTERNAL "CMock repository URL")
    set(_CMOCK_TAG ${ARG_CMOCK_TAG} CACHE INTERNAL "CMock version tag")
    set(_CEEDLING_EXTRACT_FUNCTIONS ${ARG_ENABLE_CEEDLING} CACHE INTERNAL "Ceedling extract functions mode")

    # Use FindUnity to locate or fetch Unity and CMock
    set(UNITY_FETCH ON)
    set(UNITY_GIT_REPOSITORY ${ARG_UNITY_REPO})
    set(UNITY_GIT_TAG ${ARG_UNITY_TAG})
    set(CMOCK_GIT_REPOSITORY ${ARG_CMOCK_REPO})
    set(CMOCK_GIT_TAG ${ARG_CMOCK_TAG})
    
    find_package(Unity REQUIRED)

    # Find Ruby executable for CMock and runner generation
    find_program(Ruby_EXECUTABLE ruby REQUIRED)

    # Set up paths from FindUnity results
    if(CMock_EXECUTABLE)
        set(_CMOCK_EXE ${CMock_EXECUTABLE} CACHE INTERNAL "CMock executable path")
    endif()
    
    if(Unity_RUNNER_GENERATOR)
        set(_RUNNER_EXE ${Unity_RUNNER_GENERATOR} CACHE INTERNAL "Unity runner generator path")
    else()
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Unity runner generator not found")
    endif()

    # Detect CMock version and set up configuration mode
    if(_CMOCK_EXE)
        CMockSchema_DetectVersion("${_CMOCK_EXE}" "${ARG_CMOCK_TAG}" DETECTED_SCHEMA_VERSION)
        if(DETECTED_SCHEMA_VERSION)
            # Use schema-based configuration
            set(_CMOCK_SCHEMA_VERSION "${DETECTED_SCHEMA_VERSION}" CACHE INTERNAL "Detected CMock schema version")
            set(_CMOCK_CONFIG_MODE "SCHEMA" CACHE INTERNAL "CMock configuration mode")
            
            # Set version-specific defaults
            CMockSchema_SetDefaults("${DETECTED_SCHEMA_VERSION}")
            
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Using CMock schema version ${DETECTED_SCHEMA_VERSION}")
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Configure via CMOCK_* cached variables (see module documentation)")
        else()
            # Fall back to CONFIG_FILE mode
            set(_CMOCK_SCHEMA_VERSION "" CACHE INTERNAL "Detected CMock schema version")
            set(_CMOCK_CONFIG_MODE "CONFIG_FILE" CACHE INTERNAL "CMock configuration mode")
            
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: CMock version ${ARG_CMOCK_TAG} not supported by schema system")
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Please use CONFIG_FILE parameter in Unity functions")
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: Configuration experience may vary for unsupported versions")
        endif()
    else()
        # No CMock available
        set(_CMOCK_SCHEMA_VERSION "" CACHE INTERNAL "Detected CMock schema version")
        set(_CMOCK_CONFIG_MODE "" CACHE INTERNAL "CMock configuration mode")
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: CMock not found - mocking features unavailable")
    endif()

    # Configure Ceedling extract functions mode if enabled
    if(ARG_ENABLE_CEEDLING AND TARGET Unity::Unity)
        target_compile_definitions(Unity::Unity PUBLIC UNITY_USE_COMMAND_LINE_ARGS)
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Ceedling extract functions mode enabled")
    endif()

    # Mark as initialized globally
    set(_UNITY_INITIALIZED TRUE CACHE INTERNAL "Unity initialization status")
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
#   CONFIG_FILE       - Path to the CMock configuration file (optional, for unsupported versions)
#   MOCK_PREFIX       - Prefix for mock files (optional, overrides CMOCK_MOCK_PREFIX)
#   MOCK_SUFFIX       - Suffix for mock files (optional, overrides CMOCK_MOCK_SUFFIX)
#   MOCK_SUBDIR       - Subdirectory name for mocks (optional, overrides CMOCK_MOCK_PATH)
#
function(Unity_GenerateMock)
    # Check if Unity is initialized
    if(NOT _UNITY_INITIALIZED)
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

    # Determine configuration mode and generate config file accordingly
    if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
        # Using schema-based configuration - CONFIG_FILE is optional/ignored
        if(ARG_CONFIG_FILE)
            message(STATUS "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE ignored - using CMock schema ${_CMOCK_SCHEMA_VERSION}")
        endif()
        
        # Generate configuration using schema
        set(GENERATED_CONFIG_FILE ${ARG_OUTPUT_DIR}/cmock.yml)
        CMockSchema_GenerateConfigFile(${GENERATED_CONFIG_FILE})
        
    else()
        # Using CONFIG_FILE mode for unsupported versions
        if(NOT ARG_CONFIG_FILE)
            message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE must be provided for CMock version ${_CMOCK_TAG} (unsupported by schema system)")
        endif()
        
        if(NOT EXISTS "${ARG_CONFIG_FILE}")
            message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}")
        endif()
        
        # Use configure_file for template processing
        set(GENERATED_CONFIG_FILE ${ARG_OUTPUT_DIR}/cmock.yml)
        configure_file(${ARG_CONFIG_FILE} ${GENERATED_CONFIG_FILE} @ONLY)
    endif()

    # Set defaults for optional parameters (with schema fallback)
    if(NOT ARG_MOCK_PREFIX)
        if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
            set(ARG_MOCK_PREFIX "${CMOCK_MOCK_PREFIX}")
        else()
            set(ARG_MOCK_PREFIX "mock_")
        endif()
    endif()
    
    if(NOT ARG_MOCK_SUFFIX)
        if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
            set(ARG_MOCK_SUFFIX "${CMOCK_MOCK_SUFFIX}")
        else()
            set(ARG_MOCK_SUFFIX "")
        endif()
    endif()
    
    if(NOT ARG_MOCK_SUBDIR)
        if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
            set(ARG_MOCK_SUBDIR "${CMOCK_MOCK_PATH}")
        else()
            set(ARG_MOCK_SUBDIR "mocks")
        endif()
    endif()

    # Extract header filename without extension
    cmake_path(GET ARG_HEADER STEM header_name)
    
    # Create mock directory
    set(MOCK_DIR ${ARG_OUTPUT_DIR}/${ARG_MOCK_SUBDIR})
    file(MAKE_DIRECTORY ${MOCK_DIR})
    
    # Generate mock file paths
    set(MOCK_SOURCE ${MOCK_DIR}/${ARG_MOCK_PREFIX}${header_name}${ARG_MOCK_SUFFIX}.c)
    set(MOCK_HEADER ${MOCK_DIR}/${ARG_MOCK_PREFIX}${header_name}${ARG_MOCK_SUFFIX}.h)
    
    # Create custom command to generate mock files
    add_custom_command(
        OUTPUT
            ${MOCK_SOURCE}
            ${MOCK_HEADER}
        COMMAND
            ${Ruby_EXECUTABLE} ${_CMOCK_EXE} ${ARG_HEADER} -o${GENERATED_CONFIG_FILE}
        WORKING_DIRECTORY ${ARG_OUTPUT_DIR}
        DEPENDS
            ${GENERATED_CONFIG_FILE}
            ${ARG_HEADER}
            ${Ruby_EXECUTABLE}
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
#   CONFIG_FILE       - Path to the CMock configuration file (required)
#   RUNNER_SOURCE_VAR - Variable name to store the generated runner source file path (required)
#
function(Unity_GenerateRunner)
    # Check if Unity is initialized
    if(NOT _UNITY_INITIALIZED)
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
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Test source file does not exist: ${ARG_TEST_SOURCE}")
    endif()
    
    # Determine configuration mode and generate config file accordingly
    if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
        # Schema mode - no CONFIG_FILE needed
        if(ARG_CONFIG_FILE)
            message(WARNING "CONFIG_FILE ignored in schema mode (CMock ${_CMOCK_SCHEMA_VERSION} detected) - ${CMAKE_CURRENT_FUNCTION}")
        endif()
        
        # Generate CMock configuration file
        set(GENERATED_CONFIG_FILE ${ARG_OUTPUT_DIR}/cmock.yml)
        CMockSchema_GenerateConfigFile(${GENERATED_CONFIG_FILE})
        
    else()
        # CONFIG_FILE mode - validate CONFIG_FILE parameter and file existence
        if(NOT ARG_CONFIG_FILE)
            message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE must be provided (CMock version ${_CMOCK_VERSION} not supported by schema system)")
        endif()
        
        if(NOT EXISTS "${ARG_CONFIG_FILE}")
            message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}")
        endif()
        
        # Configure the config file
        set(GENERATED_CONFIG_FILE ${ARG_OUTPUT_DIR}/cmock.yml)
        configure_file(${ARG_CONFIG_FILE} ${GENERATED_CONFIG_FILE} @ONLY)
    endif()

    # Extract test filename without extension
    cmake_path(GET ARG_TEST_SOURCE STEM test_name)
    
    # Create runner directory
    set(RUNNER_DIR ${ARG_OUTPUT_DIR}/runners)
    file(MAKE_DIRECTORY ${RUNNER_DIR})
    
    # Generate runner file path
    set(RUNNER_SOURCE ${RUNNER_DIR}/${test_name}_runner.c)
    
    # Create custom command to generate runner file
    add_custom_command(
        OUTPUT
            ${RUNNER_SOURCE}
        COMMAND
            ${Ruby_EXECUTABLE} ${_RUNNER_EXE} ${GENERATED_CONFIG_FILE} ${ARG_TEST_SOURCE} ${RUNNER_SOURCE}
        DEPENDS
            ${ARG_TEST_SOURCE}
            ${GENERATED_CONFIG_FILE}
            ${Ruby_EXECUTABLE}
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
#   CONFIG_FILE       - Path to the CMock configuration file (required)
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
    if(NOT _UNITY_INITIALIZED)
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
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Test source file does not exist: ${ARG_TEST_SOURCE}")
    endif()
    
    # Validate configuration based on mode
    if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
        # Schema mode - no CONFIG_FILE needed
        if(ARG_CONFIG_FILE)
            message(WARNING "CONFIG_FILE ignored in schema mode (CMock ${_CMOCK_VERSION} detected) - ${CMAKE_CURRENT_FUNCTION}")
        endif()
        
    else()
        # CONFIG_FILE mode - validate CONFIG_FILE parameter and file existence
        if(NOT ARG_CONFIG_FILE)
            message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE must be provided (CMock version ${_CMOCK_VERSION} not supported by schema system)")
        endif()
        
        if(NOT EXISTS "${ARG_CONFIG_FILE}")
            message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}")
        endif()
    endif()

    # Set defaults (with schema fallback)
    if(NOT ARG_OUTPUT_DIR)
        set(ARG_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    
    if(NOT ARG_MOCK_PREFIX)
        if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
            set(ARG_MOCK_PREFIX "${CMOCK_MOCK_PREFIX}")
        else()
            set(ARG_MOCK_PREFIX "mock_")
        endif()
    endif()
    
    if(NOT ARG_MOCK_SUFFIX)
        if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
            set(ARG_MOCK_SUFFIX "${CMOCK_MOCK_SUFFIX}")
        else()
            set(ARG_MOCK_SUFFIX "")
        endif()
    endif()
    
    if(NOT ARG_MOCK_SUBDIR)
        if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
            set(ARG_MOCK_SUBDIR "${CMOCK_MOCK_PATH}")
        else()
            set(ARG_MOCK_SUBDIR "mocks")
        endif()
    endif()

    # Set CONFIG_FILE argument based on configuration mode
    if(_CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
        set(CONFIG_FILE_ARG "")  # No CONFIG_FILE needed for schema mode
    else()
        set(CONFIG_FILE_ARG "CONFIG_FILE" "${ARG_CONFIG_FILE}")  # Pass CONFIG_FILE for legacy mode
    endif()

    # Generate runner for the test
    Unity_GenerateRunner(
        TEST_SOURCE ${ARG_TEST_SOURCE}
        OUTPUT_DIR ${ARG_OUTPUT_DIR}
        ${CONFIG_FILE_ARG}
        RUNNER_SOURCE_VAR runner_source
    )

    # Collect all source files
    set(all_sources ${ARG_TEST_SOURCE} ${runner_source})
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
    set_target_properties(${ARG_TARGET_NAME} PROPERTIES
        C_CLANG_TIDY ""
        SKIP_LINTING TRUE
    )

    message(STATUS "Unity: Created test target '${ARG_TARGET_NAME}'")
endfunction()
