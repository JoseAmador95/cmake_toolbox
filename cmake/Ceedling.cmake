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
      [MOCK_HEADERS <headers...>]
      [ENABLE_SANITIZER]
      [DISABLE_SANITIZER]
    )

  ``NAME``
    Name for the test executable and CTest test.

  ``UNIT_TEST``
    Path to the test source file.

  ``TARGET``
    CMake target being tested (will be linked to the test).

  ``MOCK_HEADERS``
    List of header files to generate mocks for.

  ``ENABLE_SANITIZER``
    Force enable sanitizer for this test (when CEEDLING_SANITIZER_DEFAULT is OFF).

  ``DISABLE_SANITIZER``
    Force disable sanitizer for this test (when CEEDLING_SANITIZER_DEFAULT is ON).

Example
^^^^^^^

.. code-block:: cmake

  include(Ceedling)
  
  add_library(mylib src/mylib.c)
  
  Ceedling_AddUnitTest(
    NAME mylib_test
    UNIT_TEST test/test_mylib.c
    TARGET mylib
    MOCK_HEADERS
      include/dependency.h
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
    set(multiValueArgs MOCK_HEADERS)
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

    # Generate mocks
    foreach(HEADER IN LISTS UT_MOCK_HEADERS)
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
