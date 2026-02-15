# SPDX-License-Identifier: MIT

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

``CEEDLING_GCOVR_POST_RUN``
  Run the gcovr target after unit tests via CTest fixtures.
  Default: ON when ``CEEDLING_ENABLE_GCOV=ON``; otherwise OFF.
  Set OFF to disable.

``CEEDLING_ENABLE_SANITIZER``
  Enable sanitizer instrumentation.
  Default: OFF

``CEEDLING_SANITIZER_DEFAULT``
  Enable sanitizer by default for all tests.
  Default: ON

``CEEDLING_EXTRACT_FUNCTIONS``
  Extract individual test functions as separate CTest tests.
  Default: OFF

``CEEDLING_TEST_LABELS``
  Default labels applied to Ceedling tests.
  Default: unit

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
      [LABELS <label>...]
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

  ``LABELS``
    Additional CTest labels applied to the test.

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
set(CEEDLING_TEST_LABELS "unit" CACHE STRING "Default labels for Ceedling tests")

set(_ceedling_gcovr_post_run_default OFF)
if(CEEDLING_ENABLE_GCOV)
    set(_ceedling_gcovr_post_run_default ON)
endif()
if(NOT DEFINED CEEDLING_GCOVR_POST_RUN)
    set(CEEDLING_GCOVR_POST_RUN ${_ceedling_gcovr_post_run_default})
endif()
set(CEEDLING_GCOVR_POST_RUN
    "${CEEDLING_GCOVR_POST_RUN}"
    CACHE BOOL
    "Run gcovr after unit tests when coverage is enabled"
)
unset(_ceedling_gcovr_post_run_default)

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

if(CEEDLING_EXTRACT_FUNCTIONS AND TARGET Unity::Unity)
    get_target_property(_tb_unity_target Unity::Unity ALIASED_TARGET)
    if(_tb_unity_target AND TARGET ${_tb_unity_target})
        target_compile_definitions(${_tb_unity_target} PUBLIC UNITY_USE_COMMAND_LINE_ARGS)
    else()
        target_compile_definitions(Unity::Unity PUBLIC UNITY_USE_COMMAND_LINE_ARGS)
    endif()
endif()

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
function(_Ceedling_ParseMockIncludes)
    set(options "")
    set(oneValueArgs
        TEST_SOURCE
        OUTPUT_VAR
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_TEST_SOURCE)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TEST_SOURCE must be specified")
    endif()

    if(NOT ARG_OUTPUT_VAR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: OUTPUT_VAR must be specified")
    endif()

    if(NOT EXISTS "${ARG_TEST_SOURCE}")
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: Test source file not found: ${ARG_TEST_SOURCE}"
        )
    endif()

    # Read the test file content
    file(READ "${ARG_TEST_SOURCE}" file_content)

    # Get the mock prefix (default: "mock_")
    if(NOT DEFINED CMOCK_MOCK_PREFIX)
        set(CMOCK_MOCK_PREFIX "mock_")
    endif()

    # Escape special regex characters in the prefix
    string(
        REGEX REPLACE
        "([.^$*+?()\\[\\]{}|\\\\])"
        "\\\\\\1"
        prefix_escaped
        "${CMOCK_MOCK_PREFIX}"
    )

    # Find all #include directives matching the mock prefix pattern
    # Pattern matches: #include "mock_name.h" or #include <mock_name.h> or .hpp
    set(detected_mocks "")
    string(
        REGEX MATCHALL
        "#include[ \t]*[<\"]${prefix_escaped}([a-zA-Z0-9_]+)\\.(h|hpp)[>\"]"
        matches
        "${file_content}"
    )

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

    set(${ARG_OUTPUT_VAR} "${detected_mocks}" PARENT_SCOPE)
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
function(_Ceedling_GetTargetIncludeDirs)
    set(options "")
    set(oneValueArgs
        TARGET
        OUTPUT_VAR
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_TARGET)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET must be specified")
    endif()

    if(NOT ARG_OUTPUT_VAR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: OUTPUT_VAR must be specified")
    endif()

    set(all_include_dirs "")
    set(processed_targets "")

    # Internal recursive function using a worklist
    set(worklist "${ARG_TARGET}")

    while(worklist)
        # Pop first item from worklist
        list(POP_FRONT worklist current_target)

        # Skip if already processed or not a target
        list(
            FIND processed_targets
            "${current_target}"
            _processed_target_idx
        )
        if(NOT _processed_target_idx EQUAL -1)
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
                list(
                    FIND processed_targets
                    "${lib}"
                    _processed_lib_idx
                )
                if(TARGET ${lib} AND _processed_lib_idx EQUAL -1)
                    list(APPEND worklist ${lib})
                endif()
            endforeach()
        endif()

        get_target_property(iface_link_libs ${current_target} INTERFACE_LINK_LIBRARIES)
        if(iface_link_libs)
            foreach(lib IN LISTS iface_link_libs)
                list(
                    FIND processed_targets
                    "${lib}"
                    _processed_iface_lib_idx
                )
                if(TARGET ${lib} AND _processed_iface_lib_idx EQUAL -1)
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

    set(${ARG_OUTPUT_VAR} "${clean_dirs}" PARENT_SCOPE)
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
function(_Ceedling_ResolveHeader)
    set(options "")
    set(oneValueArgs
        HEADER_BASE_NAME
        OUTPUT_VAR
    )
    set(multiValueArgs INCLUDE_DIRS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_HEADER_BASE_NAME)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: HEADER_BASE_NAME must be specified")
    endif()

    if(NOT ARG_INCLUDE_DIRS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: INCLUDE_DIRS must be specified")
    endif()

    if(NOT ARG_OUTPUT_VAR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: OUTPUT_VAR must be specified")
    endif()

    set(extensions
        ".h"
        ".hpp"
    )

    foreach(dir IN LISTS ARG_INCLUDE_DIRS)
        foreach(ext IN LISTS extensions)
            set(candidate "${dir}/${ARG_HEADER_BASE_NAME}${ext}")
            if(EXISTS "${candidate}")
                set(${ARG_OUTPUT_VAR} "${candidate}" PARENT_SCOPE)
                return()
            endif()
        endforeach()
    endforeach()

    # Not found - fatal error
    message(
        FATAL_ERROR
        "${CMAKE_CURRENT_FUNCTION}: Could not find header '${ARG_HEADER_BASE_NAME}.h' or '${ARG_HEADER_BASE_NAME}.hpp'\n"
        "Searched in directories:\n  ${ARG_INCLUDE_DIRS}\n"
        "This header was detected from a mock include (${CMOCK_MOCK_PREFIX}${ARG_HEADER_BASE_NAME}.h) in the test file.\n"
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
    set(multiValueArgs LABELS)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    # Validate arguments
    if(NOT ARG_NAME)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: NAME must be specified")
    endif()
    if(NOT ARG_UNIT_TEST)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: UNIT_TEST must be specified")
    endif()
    if(NOT ARG_TARGET)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: TARGET must be specified")
    endif()
    if(ARG_DISABLE_SANITIZER AND ARG_ENABLE_SANITIZER)
        message(
            FATAL_ERROR
            "${CMAKE_CURRENT_FUNCTION}: Cannot enable and disable sanitizer at the same time"
        )
    endif()

    # Create test executable
    add_executable(${ARG_NAME} ${ARG_UNIT_TEST})
    target_link_libraries(
        ${ARG_NAME}
        PRIVATE
            ${ARG_TARGET}
            Unity::CMock
            Unity::Unity
    )

    # Setup build directory
    set(TEST_BINARY_DIR "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}.dir")
    file(MAKE_DIRECTORY "${TEST_BINARY_DIR}")

    # Set default mock subdirectory if not defined
    if(NOT DEFINED CMOCK_MOCK_SUBDIR)
        set(CMOCK_MOCK_SUBDIR "mocks")
    endif()

    # Look for optional config file
    set(default_config "")
    set(config_locations
        "${CMAKE_SOURCE_DIR}/cmock.yml"
        "${CMAKE_CURRENT_SOURCE_DIR}/cmock.yml"
        "${CMAKE_CURRENT_BINARY_DIR}/cmock.yml"
    )

    foreach(config_path IN LISTS config_locations)
        if(EXISTS "${config_path}")
            set(default_config "${config_path}")
            break()
        endif()
    endforeach()

    # Build optional CONFIG_FILE argument
    set(config_file_arg "")
    if(default_config)
        set(config_file_arg
            CONFIG_FILE
            "${default_config}"
        )
    else()
        message(
            STATUS
            "${CMAKE_CURRENT_FUNCTION}: No cmock.yml found; using generated defaults"
        )
    endif()

    # Generate test runner
    unset(RUNNER_SOURCE)
    Unity_GenerateRunner(
        TEST_SOURCE ${ARG_UNIT_TEST}
        OUTPUT_DIR ${TEST_BINARY_DIR}
        ${config_file_arg}
        RUNNER_SOURCE_VAR RUNNER_SOURCE
    )
    cmake_path(GET RUNNER_SOURCE STEM RUNNER_STEM)
    set(TEST_RUNNER ${TEST_BINARY_DIR}/${RUNNER_STEM}.c)
    add_custom_command(
        OUTPUT
            ${TEST_RUNNER}
        DEPENDS
            ${RUNNER_SOURCE}
        COMMAND
            ${CMAKE_COMMAND} -E rename ${RUNNER_SOURCE} ${TEST_RUNNER}
        COMMENT "Move ${RUNNER_STEM} to ${TEST_BINARY_DIR}"
    )
    target_sources(${ARG_NAME} PRIVATE ${TEST_RUNNER})
    target_include_directories(${ARG_NAME} PRIVATE ${TEST_BINARY_DIR}/${CMOCK_MOCK_SUBDIR})

    # =========================================================================
    # Auto-detect mocks from test file includes
    # =========================================================================
    # Parse test file to find #include "mock_*.h" directives
    _Ceedling_ParseMockIncludes(TEST_SOURCE "${ARG_UNIT_TEST}" OUTPUT_VAR DETECTED_MOCK_NAMES)

    # Resolve detected mock names to actual header paths
    set(DETECTED_MOCK_HEADERS "")
    if(DETECTED_MOCK_NAMES)
        # Get include directories from target and its dependencies
        _Ceedling_GetTargetIncludeDirs(TARGET ${ARG_TARGET} OUTPUT_VAR TARGET_INCLUDE_DIRS)

        # Also add common locations
        list(
            APPEND TARGET_INCLUDE_DIRS
            "${CMAKE_CURRENT_SOURCE_DIR}"
            "${CMAKE_CURRENT_SOURCE_DIR}/include"
            "${CMAKE_SOURCE_DIR}"
            "${CMAKE_SOURCE_DIR}/include"
        )

        foreach(mock_name IN LISTS DETECTED_MOCK_NAMES)
            _Ceedling_ResolveHeader(
                HEADER_BASE_NAME "${mock_name}"
                INCLUDE_DIRS
                    ${TARGET_INCLUDE_DIRS}
                OUTPUT_VAR RESOLVED_HEADER
            )
            list(APPEND DETECTED_MOCK_HEADERS "${RESOLVED_HEADER}")
        endforeach()

        message(
            STATUS
            "${CMAKE_CURRENT_FUNCTION}: Auto-detected mocks from ${ARG_NAME}: ${DETECTED_MOCK_NAMES}"
        )
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
        target_sources(${ARG_NAME} PRIVATE ${MOCK_SOURCE})
    endforeach()

    # Add coverage instrumentation
    if(CEEDLING_ENABLE_GCOV)
        Gcov_AddToTarget(${ARG_TARGET} PUBLIC)
        Gcov_AddToTarget(${ARG_NAME} PRIVATE)
    endif()

    set(_tb_enable_sanitizer_for_test OFF)
    if(
        CEEDLING_ENABLE_SANITIZER
        AND (
            (
                CEEDLING_SANITIZER_DEFAULT
                AND NOT ARG_DISABLE_SANITIZER
            )
            OR (
                NOT CEEDLING_SANITIZER_DEFAULT
                AND ARG_ENABLE_SANITIZER
            )
        )
    )
        set(_tb_enable_sanitizer_for_test ON)
    endif()

    # Add sanitizer instrumentation
    if(_tb_enable_sanitizer_for_test)
        Sanitizer_AddToTarget(TARGET ${ARG_NAME} SCOPE PRIVATE)
        Sanitizer_AddToTarget(TARGET ${ARG_TARGET} SCOPE PUBLIC)
    endif()

    set(_tb_sanitizer_test_environment "")
    if(_tb_enable_sanitizer_for_test)
        set(_tb_sanitizer_test_environment "${SANITIZER_ENV_VARS}")
    endif()

    set(_tb_test_labels "")
    if(DEFINED CEEDLING_TEST_LABELS AND NOT CEEDLING_TEST_LABELS STREQUAL "")
        list(APPEND _tb_test_labels ${CEEDLING_TEST_LABELS})
    endif()
    if(ARG_LABELS)
        list(APPEND _tb_test_labels ${ARG_LABELS})
    endif()
    if(_tb_test_labels)
        list(REMOVE_DUPLICATES _tb_test_labels)
        set(_tb_test_labels_string "${_tb_test_labels}")
        string(REPLACE ";" "\\;" _tb_test_labels_escaped "${_tb_test_labels_string}")
    endif()

    set(_tb_enable_gcovr_post_run OFF)
    set(_tb_gcovr_fixture_required "")
    if(CEEDLING_ENABLE_GCOV AND CEEDLING_GCOVR_POST_RUN AND TARGET gcovr)
        set(_tb_enable_gcovr_post_run ON)
        set(_tb_gcovr_fixture_required "gcovr_unit")

        get_property(
            _tb_gcovr_post_run_added
            GLOBAL
            PROPERTY
                CEEDLING_GCOVR_POST_RUN_ADDED
        )
        if(NOT _tb_gcovr_post_run_added)
            set(
                _tb_gcovr_build_cmd
                ${CMAKE_COMMAND}
                --build
                "${CMAKE_BINARY_DIR}"
                --target
                gcovr
            )
            get_property(_tb_multi_config GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
            if(_tb_multi_config)
                list(APPEND _tb_gcovr_build_cmd --config $<CONFIG>)
            endif()

            add_test(NAME gcovr_unit COMMAND ${_tb_gcovr_build_cmd})
            set_property(TEST gcovr_unit PROPERTY FIXTURES_CLEANUP "gcovr_unit")

            set(_tb_gcovr_labels "")
            if(DEFINED CEEDLING_TEST_LABELS AND NOT CEEDLING_TEST_LABELS STREQUAL "")
                list(APPEND _tb_gcovr_labels ${CEEDLING_TEST_LABELS})
            endif()
            list(APPEND _tb_gcovr_labels gcovr)
            if(_tb_gcovr_labels)
                list(REMOVE_DUPLICATES _tb_gcovr_labels)
                set_tests_properties(gcovr_unit PROPERTIES LABELS "${_tb_gcovr_labels}")
            endif()

            set_property(GLOBAL PROPERTY CEEDLING_GCOVR_POST_RUN_ADDED TRUE)
        endif()
    endif()

    # Disable linting for test targets
    set_target_properties(
        ${ARG_NAME}
        PROPERTIES
            C_CLANG_TIDY
                ""
            CXX_CLANG_TIDY
                ""
            SKIP_LINTING
                TRUE
    )

    # Test discovery or single test
    if(CEEDLING_EXTRACT_FUNCTIONS)
        # Discover individual test functions and add as separate CTest tests
        set(TB_UNITY_TEST_FILE "${CMAKE_CURRENT_BINARY_DIR}/${ARG_NAME}_tests.cmake")

        set(_tb_test_labels_arg "")
        if(_tb_test_labels_escaped)
            set(_tb_test_labels_arg -D "TEST_LABELS=${_tb_test_labels_escaped}")
        endif()

        set(_tb_test_fixtures_arg "")
        if(_tb_gcovr_fixture_required)
            string(
                REPLACE
                ";"
                "\\;"
                _tb_gcovr_fixture_required_escaped
                "${_tb_gcovr_fixture_required}"
            )
            set(
                _tb_test_fixtures_arg
                -D
                "TEST_FIXTURES_REQUIRED=${_tb_gcovr_fixture_required_escaped}"
            )
        endif()

        add_custom_command(
            TARGET ${ARG_NAME}
            POST_BUILD
            BYPRODUCTS
                "${TB_UNITY_TEST_FILE}"
            COMMAND
                "${CMAKE_COMMAND}" -D "TEST_EXECUTABLE=$<TARGET_FILE:${ARG_NAME}>" -D
                "TEST_WORKING_DIR=${CMAKE_CURRENT_BINARY_DIR}" -D
                "TEST_SUITE=$<TARGET_FILE_NAME:${ARG_NAME}>" -D "TEST_FILE=${TB_UNITY_TEST_FILE}" -D
                "TEST_ENVIRONMENT=${_tb_sanitizer_test_environment}" ${_tb_test_labels_arg}
                ${_tb_test_fixtures_arg} -P
                "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/DiscoverTests.cmake"
            VERBATIM
        )

        set_property(
            DIRECTORY
            APPEND
            PROPERTY
                TEST_INCLUDE_FILES
                    "${TB_UNITY_TEST_FILE}"
        )
    else()
        # Add the whole file as a single test
        add_test(NAME ${ARG_NAME} COMMAND ${ARG_NAME})
        if(_tb_test_labels_string)
            set_tests_properties(${ARG_NAME} PROPERTIES LABELS "${_tb_test_labels_string}")
        endif()
        if(_tb_gcovr_fixture_required)
            set_property(
                TEST
                    ${ARG_NAME}
                APPEND
                PROPERTY
                    FIXTURES_REQUIRED
                        "${_tb_gcovr_fixture_required}"
            )
        endif()
        if(_tb_sanitizer_test_environment)
            Sanitizer_ApplyEnvironmentToTests(TESTS ${ARG_NAME})
        endif()
    endif()
endfunction()
