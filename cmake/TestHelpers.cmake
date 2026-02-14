# SPDX-License-Identifier: MIT

include_guard(GLOBAL)

#[=======================================================================[.rst:
TestHelpers
-----------

Utility functions for integration tests that spawn sub-cmake processes.

When the top-level build passes ``CMAKE_TOOLBOX_TEST_GENERATOR``,
``CMAKE_TOOLBOX_TEST_C_COMPILER``, ``CMAKE_TOOLBOX_TEST_CXX_COMPILER``,
and ``CMAKE_TOOLBOX_TEST_BUILD_TYPE`` into a ``cmake -P`` test script
via ``-D`` flags, the helper below turns them into the correct
``-G`` / ``-DCMAKE_C_COMPILER=`` / ``-DCMAKE_BUILD_TYPE=`` arguments
for any ``execute_process(COMMAND ${CMAKE_COMMAND} -S ... -B ...)`` call
inside that test script.

Example
^^^^^^^

.. code-block:: cmake

  include(TestHelpers)
  TestHelpers_GetConfigureArgs(extra_args)
  execute_process(
      COMMAND ${CMAKE_COMMAND} -S src -B build ${extra_args}
      ...
  )

#]=======================================================================]

function(TestHelpers_GetConfigureArgs OUT_VAR)
    set(args "")
    if(DEFINED CMAKE_TOOLBOX_TEST_GENERATOR AND NOT CMAKE_TOOLBOX_TEST_GENERATOR STREQUAL "")
        list(APPEND args -G "${CMAKE_TOOLBOX_TEST_GENERATOR}")
    endif()
    if(DEFINED CMAKE_TOOLBOX_TEST_C_COMPILER AND NOT CMAKE_TOOLBOX_TEST_C_COMPILER STREQUAL "")
        list(APPEND args "-DCMAKE_C_COMPILER=${CMAKE_TOOLBOX_TEST_C_COMPILER}")
    endif()
    if(DEFINED CMAKE_TOOLBOX_TEST_CXX_COMPILER AND NOT CMAKE_TOOLBOX_TEST_CXX_COMPILER STREQUAL "")
        list(APPEND args "-DCMAKE_CXX_COMPILER=${CMAKE_TOOLBOX_TEST_CXX_COMPILER}")
    endif()
    if(DEFINED CMAKE_TOOLBOX_TEST_BUILD_TYPE AND NOT CMAKE_TOOLBOX_TEST_BUILD_TYPE STREQUAL "")
        list(APPEND args "-DCMAKE_BUILD_TYPE=${CMAKE_TOOLBOX_TEST_BUILD_TYPE}")
    endif()
    set(${OUT_VAR} ${args} PARENT_SCOPE)
endfunction()

set(_TOOLBOX_GCOVR_HELP_TEXT
    "gcovr mock help\n"
    "  --help\n"
    "  --version\n"
    "  --config\n"
    "  --search-path\n"
    "  --filter\n"
    "  --exclude\n"
    "  --exclude-directories\n"
    "  --exclude-unreachable-branches\n"
    "  --exclude-throw-branches\n"
    "  --exclude-function-lines\n"
    "  --fail-under-line\n"
    "  --fail-under-branch\n"
    "  --fail-under-function\n"
    "  --fail-under-decision\n"
    "  --html\n"
    "  --html-details\n"
    "  --html-nested\n"
    "  --html-title\n"
    "  --html-self-contained\n"
    "  --html-high-threshold\n"
    "  --html-medium-threshold\n"
    "  --xml\n"
    "  --cobertura\n"
    "  --json\n"
    "  --lcov\n"
    "  --csv\n"
    "  --coveralls\n"
    "  --txt\n"
    "  --sort\n"
    "  --gcov-executable\n"
    "  --decisions\n"
    "  --calls\n"
    "  --print-summary\n"
)

function(TestHelpers_CreateMockGcovr OUT_VAR)
    set(options "")
    set(oneValueArgs OUTPUT_DIR HELP_TEXT VERSION_TEXT)
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT ARG_OUTPUT_DIR)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: OUTPUT_DIR must be specified")
    endif()

    if(NOT ARG_VERSION_TEXT)
        set(ARG_VERSION_TEXT "gcovr 9.0")
    endif()

    if(NOT ARG_HELP_TEXT)
        set(ARG_HELP_TEXT "${_TOOLBOX_GCOVR_HELP_TEXT}")
    endif()

    file(MAKE_DIRECTORY "${ARG_OUTPUT_DIR}")

    set(help_file "${ARG_OUTPUT_DIR}/mock_gcovr_help.txt")
    file(WRITE "${help_file}" "${ARG_HELP_TEXT}")

    set(script_path "${ARG_OUTPUT_DIR}/mock_gcovr")
    if(WIN32)
        file(TO_NATIVE_PATH "${help_file}" help_file_native)
        set(script_path "${script_path}.bat")
        file(
            WRITE
            "${script_path}"
            "@echo off\r\n"
            "if \"%1\"==\"--help\" (\r\n"
            "  type \"${help_file_native}\"\r\n"
            "  exit /b 0\r\n"
            ")\r\n"
            "if \"%1\"==\"--version\" (\r\n"
            "  echo ${ARG_VERSION_TEXT}\r\n"
            "  exit /b 0\r\n"
            ")\r\n"
            "exit /b 0\r\n"
        )
    else()
        file(
            WRITE
            "${script_path}"
            "#!/bin/sh\n"
            "if [ \"$1\" = \"--help\" ]; then\n"
            "  cat \"${help_file}\"\n"
            "  exit 0\n"
            "fi\n"
            "if [ \"$1\" = \"--version\" ]; then\n"
            "  echo \"${ARG_VERSION_TEXT}\"\n"
            "  exit 0\n"
            "fi\n"
            "exit 0\n"
        )
        file(
            CHMOD
            "${script_path}"
            PERMISSIONS
                OWNER_EXECUTE
                OWNER_READ
                OWNER_WRITE
        )
    endif()

    set(${OUT_VAR} "${script_path}" PARENT_SCOPE)
endfunction()
