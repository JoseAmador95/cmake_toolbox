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
#   - Mock generation from header files
#   - Test runner generation for Unity tests
#   - Configurable output directories and naming conventions
#   - Support for Ceedling extract functions mode
#
# USAGE EXAMPLE:
#   # Initialize Unity (call once per project)
#   Unity_Initialize()
#   
#   # Generate mock for a header file
#   Unity_GenerateMock(
#       HEADER path/to/interface.h
#       OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR}
#       MOCK_SOURCE_VAR mock_src
#       MOCK_HEADER_VAR mock_hdr
#       CONFIG_FILE ${CMAKE_SOURCE_DIR}/cmock.yml
#       MOCK_PREFIX mock_
#   )
#   
#   # Generate test runner
#   Unity_GenerateRunner(
#       TEST_SOURCE test_example.c
#       RUNNER_SOURCE_VAR runner_src
#       CONFIG_FILE ${CMAKE_SOURCE_DIR}/cmock.yml
#   )
#   
#   # Create complete test target
#   Unity_CreateTestTarget(
#       TARGET_NAME test_my_module
#       TEST_SOURCE test_my_module.c
#       MOCK_HEADERS interface.h protocol.h
#       CONFIG_FILE ${CMAKE_SOURCE_DIR}/cmock.yml
#   )
#
# ==============================================================================

include_guard(GLOBAL)

# Default repository and version configuration (can be overridden before calling Unity_Initialize)
set(_UNITY_DEFAULT_REPO "https://github.com/ThrowTheSwitch/Unity.git")
set(_UNITY_DEFAULT_TAG "v2.6.1")
set(_CMOCK_DEFAULT_REPO "https://github.com/ThrowTheSwitch/CMock.git")
set(_CMOCK_DEFAULT_TAG "v2.6.0")

# Internal state tracking
set(_UNITY_INITIALIZED FALSE CACHE INTERNAL "Unity initialization status")

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

    # Fetch Unity and CMock repositories
    include(FetchContent)
    FetchContent_Declare(cmock_repo GIT_REPOSITORY ${ARG_CMOCK_REPO} GIT_TAG ${ARG_CMOCK_TAG})
    FetchContent_Declare(unity_repo GIT_REPOSITORY ${ARG_UNITY_REPO} GIT_TAG ${ARG_UNITY_TAG})
    FetchContent_MakeAvailable(unity_repo cmock_repo)

    # Find Ruby executable for CMock and runner generation
    find_program(Ruby_EXECUTABLE ruby REQUIRED)

    # Store paths globally for internal use
    set(_CMOCK_EXE ${cmock_repo_SOURCE_DIR}/lib/cmock.rb CACHE INTERNAL "CMock executable path")
    set(_RUNNER_EXE ${unity_repo_SOURCE_DIR}/auto/generate_test_runner.rb CACHE INTERNAL "Unity runner generator path")

    # Create and configure CMock library
    add_library(cmock STATIC ${cmock_repo_SOURCE_DIR}/src/cmock.c)
    target_include_directories(cmock PUBLIC ${cmock_repo_SOURCE_DIR}/src)
    target_link_libraries(cmock PUBLIC unity)
    
    # Disable linting for external dependencies
    set_target_properties(cmock PROPERTIES
        C_CLANG_TIDY ""
        SKIP_LINTING TRUE
    )

    # Configure Ceedling extract functions mode if enabled
    if(ARG_ENABLE_CEEDLING)
        target_compile_definitions(unity PUBLIC UNITY_USE_COMMAND_LINE_ARGS)
        message(STATUS "[Unity] Ceedling extract functions mode enabled")
    endif()
    
    # Disable linting for external dependencies
    set_target_properties(unity PROPERTIES
        C_CLANG_TIDY ""
        SKIP_LINTING TRUE
    )

    # Mark as initialized globally
    set(_UNITY_INITIALIZED TRUE CACHE INTERNAL "Unity initialization status")
    message(STATUS "[Unity] Unity testing framework initialized")
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
#   CONFIG_FILE       - Path to the CMock configuration file (required)
#   MOCK_SOURCE_VAR   - Variable name to store the generated mock source file path (required)  
#   MOCK_HEADER_VAR   - Variable name to store the generated mock header file path (required)
#   MOCK_PREFIX       - Prefix for mock files (optional, default: mock_)
#   MOCK_SUFFIX       - Suffix for mock files (optional, default: empty)
#   MOCK_SUBDIR       - Subdirectory name for mocks (optional, default: mocks)
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
    
    if(NOT ARG_CONFIG_FILE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE must be provided")
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
    
    if(NOT EXISTS "${ARG_CONFIG_FILE}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}")
    endif()

    # Set defaults for optional parameters
    if(NOT ARG_MOCK_PREFIX)
        set(ARG_MOCK_PREFIX "mock_")
    endif()
    if(NOT ARG_MOCK_SUFFIX)
        set(ARG_MOCK_SUFFIX "")
    endif()
    if(NOT ARG_MOCK_SUBDIR)
        set(ARG_MOCK_SUBDIR "mocks")
    endif()

    # Extract header filename without extension
    cmake_path(GET ARG_HEADER STEM header_name)
    
    # Create mock directory
    set(MOCK_DIR ${ARG_OUTPUT_DIR}/${ARG_MOCK_SUBDIR})
    file(MAKE_DIRECTORY ${MOCK_DIR})
    
    # Generate mock file paths
    set(MOCK_SOURCE ${MOCK_DIR}/${ARG_MOCK_PREFIX}${header_name}${ARG_MOCK_SUFFIX}.c)
    set(MOCK_HEADER ${MOCK_DIR}/${ARG_MOCK_PREFIX}${header_name}${ARG_MOCK_SUFFIX}.h)
    
    # Configure the config file
    set(GENERATED_CONFIG_FILE ${ARG_OUTPUT_DIR}/cmock.yml)
    configure_file(${ARG_CONFIG_FILE} ${GENERATED_CONFIG_FILE} @ONLY)
    
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
    
    if(NOT ARG_CONFIG_FILE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE must be provided")
    endif()
    
    if(NOT ARG_RUNNER_SOURCE_VAR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: RUNNER_SOURCE_VAR must be provided")
    endif()

    # Validate files exist
    if(NOT EXISTS "${ARG_TEST_SOURCE}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Test source file does not exist: ${ARG_TEST_SOURCE}")
    endif()
    
    if(NOT EXISTS "${ARG_CONFIG_FILE}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}")
    endif()

    # Extract test filename without extension
    cmake_path(GET ARG_TEST_SOURCE STEM test_name)
    
    # Create runner directory
    set(RUNNER_DIR ${ARG_OUTPUT_DIR}/runners)
    file(MAKE_DIRECTORY ${RUNNER_DIR})
    
    # Generate runner file path
    set(RUNNER_SOURCE ${RUNNER_DIR}/${test_name}_runner.c)
    
    # Configure the config file
    set(GENERATED_CONFIG_FILE ${ARG_OUTPUT_DIR}/cmock.yml)
    configure_file(${ARG_CONFIG_FILE} ${GENERATED_CONFIG_FILE} @ONLY)
    
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
    
    if(NOT ARG_CONFIG_FILE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: CONFIG_FILE must be provided")
    endif()

    # Validate files exist
    if(NOT EXISTS "${ARG_TEST_SOURCE}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Test source file does not exist: ${ARG_TEST_SOURCE}")
    endif()
    
    if(NOT EXISTS "${ARG_CONFIG_FILE}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Config file does not exist: ${ARG_CONFIG_FILE}")
    endif()

    # Set defaults
    if(NOT ARG_OUTPUT_DIR)
        set(ARG_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR})
    endif()
    if(NOT ARG_MOCK_PREFIX)
        set(ARG_MOCK_PREFIX "mock_")
    endif()
    if(NOT ARG_MOCK_SUFFIX)
        set(ARG_MOCK_SUFFIX "")
    endif()
    if(NOT ARG_MOCK_SUBDIR)
        set(ARG_MOCK_SUBDIR "mocks")
    endif()

    # Generate runner for the test
    Unity_GenerateRunner(
        TEST_SOURCE ${ARG_TEST_SOURCE}
        OUTPUT_DIR ${ARG_OUTPUT_DIR}
        CONFIG_FILE ${ARG_CONFIG_FILE}
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
                CONFIG_FILE ${ARG_CONFIG_FILE}
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
    target_link_libraries(${ARG_TARGET_NAME} PRIVATE unity)
    if(ARG_MOCK_HEADERS)
        target_link_libraries(${ARG_TARGET_NAME} PRIVATE cmock)
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
