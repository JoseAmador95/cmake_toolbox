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
