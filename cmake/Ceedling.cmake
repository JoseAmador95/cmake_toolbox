# Distributed under the OSI-approved BSD 3-Clause License.
# See accompanying file LICENSE.txt for details.

#[=======================================================================[.rst:
Ceedling
--------

CMake module for Unity/CMock-based unit testing.

This module provides functions to create unit test executables with automatic
mock generation using the Unity testing framework and CMock mocking framework.

Dependencies
^^^^^^^^^^^^

This module automatically initializes the Unity framework and optionally
includes coverage (Gcov) and sanitizer (Sanitizer) support.

Cache Variables
^^^^^^^^^^^^^^^

``CEEDLING_ENABLE_GCOV``
  Enable code coverage instrumentation.
  Default: OFF

``CEEDLING_ENABLE_SANITIZER``
  Enable sanitizer instrumentation.
  Default: OFF

``CEEDLING_SANITIZER_DEFAULT``
  Enable sanitizer by default for all tests.
  Default: ON

``CEEDLING_EXTRACT_FUNCTIONS``
  Extract individual test functions as separate CTest tests.
  Default: OFF

Functions
^^^^^^^^^

.. command:: Ceedling_AddUnitTest

  Add a unit test executable with mock generation::

    Ceedling_AddUnitTest(
      NAME <test_name>
      UNIT_TEST <test_source>
      TARGET <target_under_test>
      [ENABLE_SANITIZER]
      [DISABLE_SANITIZER]
    )

  ``NAME``
    Name for the test executable and CTest test.

  ``UNIT_TEST``
    Path to the test source file.
    Mock dependencies are automatically detected by parsing ``#include``
    directives matching ``#include "mock_*.h"`` (or the configured
    ``CMOCK_MOCK_PREFIX``). The original header is resolved from the
    include directories of TARGET and its dependencies.

  ``TARGET``
    CMake target being tested (will be linked to the test).
    Its include directories (and those of its dependencies) are used
    to resolve mock headers.

  ``ENABLE_SANITIZER``
    Force enable sanitizer for this test (when CEEDLING_SANITIZER_DEFAULT is OFF).

  ``DISABLE_SANITIZER``
    Force disable sanitizer for this test (when CEEDLING_SANITIZER_DEFAULT is ON).

Example
^^^^^^^

.. code-block:: cmake

  include(Ceedling)
  
  add_library(mylib src/mylib.c)
  target_include_directories(mylib PUBLIC include)
  
  # If test_mylib.c contains #include "mock_dependency.h",
  # the module will automatically find include/dependency.h and mock it.
  Ceedling_AddUnitTest(
    NAME mylib_test
    UNIT_TEST test/test_mylib.c
    TARGET mylib
  )

#]=======================================================================]

include_guard(GLOBAL)

# ==============================================================================
# Options
# ==============================================================================

option(CEEDLING_ENABLE_GCOV "Enable coverage" OFF)
option(CEEDLING_ENABLE_SANITIZER "Enable sanitizer" OFF)
option(CEEDLING_SANITIZER_DEFAULT "Enable sanitizer by default" ON)
option(CEEDLING_EXTRACT_FUNCTIONS "Extract test functions as separate ctest test" OFF)

# ==============================================================================
# Include Dependencies
# ==============================================================================

if(CEEDLING_ENABLE_GCOV)
    include(${CMAKE_CURRENT_LIST_DIR}/Gcov.cmake)
endif()

if(CEEDLING_ENABLE_SANITIZER)
    include(${CMAKE_CURRENT_LIST_DIR}/Sanitizer.cmake)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/Unity.cmake)

# Initialize Unity once for Ceedling
Unity_Initialize()

# ==============================================================================
# _Ceedling_ParseMockIncludes (Internal)
# ==============================================================================
#
# Parse a test source file to find mock includes based on CMOCK_MOCK_PREFIX.
# Returns list of header base names (without prefix and extension).
#
# Parameters:
#   TEST_SOURCE - Path to the test source file
#   OUTPUT_VAR  - Variable name to store the list of detected mock base names
#
function(_Ceedling_ParseMockIncludes TEST_SOURCE OUTPUT_VAR)
    if(NOT EXISTS "${TEST_SOURCE}")
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Test source file not found: ${TEST_SOURCE}")
    endif()

    # Read the test file content
    file(READ "${TEST_SOURCE}" file_content)

    # Get the mock prefix (default: "mock_")
    if(NOT DEFINED CMOCK_MOCK_PREFIX)
        set(CMOCK_MOCK_PREFIX "mock_")
    endif()

    # Escape special regex characters in the prefix
    string(REGEX REPLACE "([.^$*+?()\\[\\]{}|\\\\])" "\\\\\\1" prefix_escaped "${CMOCK_MOCK_PREFIX}")

    # Find all #include directives matching the mock prefix pattern
    # Pattern matches: #include "mock_name.h" or #include <mock_name.h> or .hpp
    set(detected_mocks "")
    string(REGEX MATCHALL "#include[ \t]*[<\"]${prefix_escaped}([a-zA-Z0-9_]+)\\.(h|hpp)[>\"]" matches "${file_content}")

    foreach(match IN LISTS matches)
        # Extract the base name (without prefix and extension)
        if(match MATCHES "#include[ \t]*[<\"]${prefix_escaped}([a-zA-Z0-9_]+)\\.(h|hpp)[>\"]")
            list(APPEND detected_mocks "${CMAKE_MATCH_1}")
        endif()
    endforeach()

    # Remove duplicates
    if(detected_mocks)
        list(REMOVE_DUPLICATES detected_mocks)
    endif()

    set(${OUTPUT_VAR} "${detected_mocks}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# _Ceedling_GetTargetIncludeDirs (Internal)
# ==============================================================================
#
# Get all include directories from a target and its dependencies (recursive).
#
# Parameters:
#   TARGET     - The target to get include directories from
#   OUTPUT_VAR - Variable name to store the list of include directories
#
function(_Ceedling_GetTargetIncludeDirs TARGET OUTPUT_VAR)
    set(all_include_dirs "")
    set(processed_targets "")

    # Internal recursive function using a worklist
    set(worklist "${TARGET}")

    while(worklist)
        # Pop first item from worklist
        list(POP_FRONT worklist current_target)

        # Skip if already processed or not a target
        if(current_target IN_LIST processed_targets)
            continue()
        endif()
        if(NOT TARGET ${current_target})
            continue()
        endif()
        list(APPEND processed_targets "${current_target}")

        # Get include directories from this target
        get_target_property(inc_dirs ${current_target} INCLUDE_DIRECTORIES)
        if(inc_dirs)
            list(APPEND all_include_dirs ${inc_dirs})
        endif()

        get_target_property(iface_inc_dirs ${current_target} INTERFACE_INCLUDE_DIRECTORIES)
        if(iface_inc_dirs)
            list(APPEND all_include_dirs ${iface_inc_dirs})
        endif()

        # Get linked libraries to process recursively
        get_target_property(link_libs ${current_target} LINK_LIBRARIES)
        if(link_libs)
            foreach(lib IN LISTS link_libs)
                if(TARGET ${lib} AND NOT lib IN_LIST processed_targets)
                    list(APPEND worklist ${lib})
                endif()
            endforeach()
        endif()

        get_target_property(iface_link_libs ${current_target} INTERFACE_LINK_LIBRARIES)
        if(iface_link_libs)
            foreach(lib IN LISTS iface_link_libs)
                if(TARGET ${lib} AND NOT lib IN_LIST processed_targets)
                    list(APPEND worklist ${lib})
                endif()
            endforeach()
        endif()
    endwhile()

    # Remove duplicates and generator expressions (we can't resolve those at configure time)
    set(clean_dirs "")
    foreach(dir IN LISTS all_include_dirs)
        # Skip generator expressions
        if(NOT dir MATCHES "^\\$<")
            list(APPEND clean_dirs "${dir}")
        endif()
    endforeach()

    if(clean_dirs)
        list(REMOVE_DUPLICATES clean_dirs)
    endif()

    set(${OUTPUT_VAR} "${clean_dirs}" PARENT_SCOPE)
endfunction()

# ==============================================================================
# _Ceedling_ResolveHeader (Internal)
# ==============================================================================
#
# Find a header file by base name in a list of include directories.
#
# Parameters:
#   HEADER_BASE_NAME - Base name of the header (without extension)
#   INCLUDE_DIRS     - List of directories to search in
#   OUTPUT_VAR       - Variable name to store the full path to the header
#
function(_Ceedling_ResolveHeader HEADER_BASE_NAME INCLUDE_DIRS OUTPUT_VAR)
    set(extensions ".h" ".hpp")

    foreach(dir IN LISTS INCLUDE_DIRS)
        foreach(ext IN LISTS extensions)
            set(candidate "${dir}/${HEADER_BASE_NAME}${ext}")
            if(EXISTS "${candidate}")
                set(${OUTPUT_VAR} "${candidate}" PARENT_SCOPE)
                return()
            endif()
        endforeach()
    endforeach()

    # Not found - fatal error
    message(FATAL_ERROR 
        "${CMAKE_CURRENT_FUNCTION}: Could not find header '${HEADER_BASE_NAME}.h' or '${HEADER_BASE_NAME}.hpp'\n"
        "Searched in directories:\n  ${INCLUDE_DIRS}\n"
        "This header was detected from a mock include (${CMOCK_MOCK_PREFIX}${HEADER_BASE_NAME}.h) in the test file.\n"
        "Make sure the header exists and the target's include directories are set correctly."
    )
endfunction()

# ==============================================================================
# Ceedling_AddUnitTest
# ==============================================================================
#
# Add a unit test executable with mock generation.
#
function(Ceedling_AddUnitTest)
    set(options
        DISABLE_SANITIZER
        ENABLE_SANITIZER
    )
    set(oneValueArgs
        NAME
        UNIT_TEST
        TARGET
    )
    set(multiValueArgs "")
    cmake_parse_arguments(UT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate arguments
    if(NOT UT_NAME)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: NAME must be specified")
    endif()
    if(NOT UT_UNIT_TEST)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: UNIT_TEST must be specified")
    endif()
    if(NOT UT_TARGET)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET must be specified")
    endif()
    if(UT_DISABLE_SANITIZER AND UT_ENABLE_SANITIZER)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: Cannot enable and disable sanitizer at the same time")
    endif()

    # Create test executable
    add_executable(${UT_NAME} ${UT_UNIT_TEST})
    target_link_libraries(
        ${UT_NAME}
        PRIVATE
            ${UT_TARGET}
            Unity::CMock
            Unity::Unity
    )

    # Setup build directory
    set(TEST_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/${UT_NAME}.dir)
    file(MAKE_DIRECTORY ${TEST_BINARY_DIR})

    # Set default mock subdirectory if not defined
    if(NOT DEFINED CMOCK_MOCK_SUBDIR)
        set(CMOCK_MOCK_SUBDIR "mocks")
    endif()

    # Only look for config file when NOT in schema mode
    set(default_config "")
    if(NOT _CMOCK_CONFIG_MODE STREQUAL "SCHEMA")
        set(config_locations
            ${CMAKE_SOURCE_DIR}/cmock.yml
            ${CMAKE_CURRENT_SOURCE_DIR}/cmock.yml
            ${CMAKE_CURRENT_BINARY_DIR}/cmock.yml
        )

        foreach(config_path ${config_locations})
            if(EXISTS ${config_path})
                set(default_config ${config_path})
                break()
            endif()
        endforeach()

        if(NOT default_config)
            message(
                FATAL_ERROR
                "${CMAKE_CURRENT_FUNCTION}: No cmock.yml configuration file found in expected locations"
            )
        endif()
    endif()

    # Build optional CONFIG_FILE argument
    set(config_file_arg "")
    if(default_config)
        set(config_file_arg CONFIG_FILE ${default_config})
    endif()

    # Generate test runner
    unset(RUNNER_SOURCE)
    Unity_GenerateRunner(
        TEST_SOURCE ${UT_UNIT_TEST}
        OUTPUT_DIR ${TEST_BINARY_DIR}
        ${config_file_arg}
        RUNNER_SOURCE_VAR RUNNER_SOURCE
    )
    cmake_path(GET RUNNER_SOURCE STEM RUNNER_STEM)
    set(TEST_RUNNER ${TEST_BINARY_DIR}/${RUNNER_STEM}.c)
    add_custom_command(
        OUTPUT ${TEST_RUNNER}
        DEPENDS ${RUNNER_SOURCE}
        COMMAND ${CMAKE_COMMAND} -E rename ${RUNNER_SOURCE} ${TEST_RUNNER}
        COMMENT "Move ${RUNNER_STEM} to ${TEST_BINARY_DIR}"
    )
    target_sources(${UT_NAME} PRIVATE ${TEST_RUNNER})
    target_include_directories(${UT_NAME} PRIVATE ${TEST_BINARY_DIR}/${CMOCK_MOCK_SUBDIR})

    # =========================================================================
    # Auto-detect mocks from test file includes
    # =========================================================================
    # Parse test file to find #include "mock_*.h" directives
    _Ceedling_ParseMockIncludes("${UT_UNIT_TEST}" DETECTED_MOCK_NAMES)

    # Resolve detected mock names to actual header paths
    set(DETECTED_MOCK_HEADERS "")
    if(DETECTED_MOCK_NAMES)
        # Get include directories from target and its dependencies
        _Ceedling_GetTargetIncludeDirs(${UT_TARGET} TARGET_INCLUDE_DIRS)

        # Also add common locations
        list(APPEND TARGET_INCLUDE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}"
            "${CMAKE_CURRENT_SOURCE_DIR}/include"
            "${CMAKE_SOURCE_DIR}"
            "${CMAKE_SOURCE_DIR}/include"
        )

        foreach(mock_name IN LISTS DETECTED_MOCK_NAMES)
            _Ceedling_ResolveHeader("${mock_name}" "${TARGET_INCLUDE_DIRS}" RESOLVED_HEADER)
            list(APPEND DETECTED_MOCK_HEADERS "${RESOLVED_HEADER}")
        endforeach()

        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Auto-detected mocks from ${UT_NAME}: ${DETECTED_MOCK_NAMES}")
    endif()

    # Generate mocks for all auto-detected headers
    foreach(HEADER IN LISTS DETECTED_MOCK_HEADERS)
        unset(MOCK_SOURCE)
        Unity_GenerateMock(
            HEADER ${HEADER}
            OUTPUT_DIR ${TEST_BINARY_DIR}
            ${config_file_arg}
            MOCK_SOURCE_VAR MOCK_SOURCE
            MOCK_HEADER_VAR MOCK_HEADER
        )
        target_sources(${UT_NAME} PRIVATE ${MOCK_SOURCE})
    endforeach()

    # Add coverage instrumentation
    if(CEEDLING_ENABLE_GCOV)
        Gcov_AddToTarget(${UT_TARGET} PUBLIC)
    endif()

    # Add sanitizer instrumentation
    if(
        CEEDLING_ENABLE_SANITIZER
        AND (
            (CEEDLING_SANITIZER_DEFAULT AND NOT UT_DISABLE_SANITIZER)
            OR (NOT CEEDLING_SANITIZER_DEFAULT AND UT_ENABLE_SANITIZER)
        )
    )
        Sanitizer_AddToTarget(${UT_TARGET} PUBLIC)
    endif()

    # Disable linting for test targets
    set_target_properties(
        ${UT_NAME}
        PROPERTIES
            C_CLANG_TIDY ""
            CXX_CLANG_TIDY ""
            SKIP_LINTING TRUE
    )

    # Test discovery or single test
    if(CEEDLING_EXTRACT_FUNCTIONS)
        # Discover individual test functions and add as separate CTest tests
        set(TB_UNITY_TEST_FILE "${CMAKE_CURRENT_BINARY_DIR}/${UT_NAME}_tests.cmake")

        add_custom_command(
            TARGET ${UT_NAME}
            POST_BUILD
            BYPRODUCTS "${TB_UNITY_TEST_FILE}"
            COMMAND
                "${CMAKE_COMMAND}"
                -D "TEST_EXECUTABLE=$<TARGET_FILE:${UT_NAME}>"
                -D "TEST_WORKING_DIR=${CMAKE_CURRENT_BINARY_DIR}"
                -D "TEST_SUITE=$<TARGET_FILE_NAME:${UT_NAME}>"
                -D "TEST_FILE=${TB_UNITY_TEST_FILE}"
                -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DiscoverTests.cmake"
            VERBATIM
        )

        set_property(
            DIRECTORY
            APPEND
            PROPERTY TEST_INCLUDE_FILES "${TB_UNITY_TEST_FILE}"
        )
    else()
        # Add the whole file as a single test
        add_test(NAME ${UT_NAME} COMMAND ${UT_NAME})
    endif()
endfunction()

# ==============================================================================
# Backward Compatibility Alias
# ==============================================================================

function(add_unit_test)
    message(DEPRECATION "add_unit_test() is deprecated, use Ceedling_AddUnitTest() instead")
    Ceedling_AddUnitTest(${ARGN})
endfunction()
