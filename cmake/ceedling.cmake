include_guard(GLOBAL)

option(CEEDLING_ENABLE_GCOV "Enable coverage" OFF)
option(CEEDLING_ENABLE_SANITIZER "Enable sanitizer" OFF)
option(CEEDLING_SANITIZER_DEFAULT "Enable sanitizer by default" ON)

if(CEEDLING_ENABLE_GCOV)
    include(${CMAKE_CURRENT_LIST_DIR}/gcov.cmake)
endif()

if(CEEDLING_ENABLE_SANITIZER)
    include(${CMAKE_CURRENT_LIST_DIR}/sanitizer.cmake)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/unity.cmake)

function(add_unit_test)
    set(options DISABLE_SANITIZER ENABLE_SANITIZER)
    set(oneValueArgs NAME UNIT_TEST TARGET)
    set(multiValueArgs MOCK_HEADERS)
    cmake_parse_arguments(UT "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(UT_DISABLE_SANITIZER AND UT_ENABLE_SANITIZER)
        message(FATAL_ERROR "Cannot enable and disable sanitizer at the same time")
    endif()

    add_executable(${UT_NAME} ${UT_UNIT_TEST})
    target_link_libraries(${UT_NAME} PRIVATE ${UT_TARGET} cmock unity)

    set(TEST_BINARY_DIR ${CMAKE_CURRENT_BINARY_DIR}/${UT_NAME}.dir)
    file(MAKE_DIRECTORY ${TEST_BINARY_DIR})

    unset(RUNNER_SOURCE)
    generate_runner(${UT_UNIT_TEST} RUNNER_SOURCE)
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

    foreach(HEADER IN LISTS UT_MOCK_HEADERS)
        unset(MOCK_SOURCE)
        mock_header(${HEADER} MOCK_SOURCE MOCK_HEADER ${TEST_BINARY_DIR})
        target_sources(${UT_NAME} PRIVATE ${MOCK_SOURCE})
    endforeach()

    if(CEEDLING_ENABLE_GCOV)
        target_add_gcov(${UT_TARGET} PUBLIC)
    endif()

    if(CEEDLING_ENABLE_SANITIZER AND
       ((CEEDLING_SANITIZER_DEFAULT AND NOT UT_DISABLE_SANITIZER) OR
        (NOT CEEDLING_SANITIZER_DEFAULT AND UT_ENABLE_SANITIZER)))
        target_add_sanitizer(${UT_TARGET} PUBLIC)
    endif()

    set_target_properties(
        ${UT_NAME}
        PROPERTIES
            C_CLANG_TIDY ""
            CXX_CLANG_TIDY ""
            SKIP_LINTING TRUE
    )

    # Set some variables for use down below
    set(ctest_file_base "${CMAKE_CURRENT_BINARY_DIR}/${UT_NAME}")
    set(ctest_include_file "${ctest_file_base}_include.cmake")
    set(ctest_tests_file "${ctest_file_base}_tests.cmake")

    # Discover and add tests for the given file once it is built
    add_custom_command(
      TARGET ${UT_NAME} POST_BUILD
      BYPRODUCTS "${ctest_tests_file}"
      COMMAND "${CMAKE_COMMAND}"
              -D "TEST_EXECUTABLE=$<TARGET_FILE:${UT_NAME}>"
              -D "TEST_WORKING_DIR=${CMAKE_CURRENT_BINARY_DIR}"
              -D "TEST_SUITE=$<TARGET_FILE_NAME:${UT_NAME}>"
              -D "TEST_FILE=${ctest_tests_file}"
              -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/ceedlingDiscoverTests.cmake"
      VERBATIM
    )

    # Mechanism to add the unit tests after building and discovering
    #   - Can't call include(...) here since at the time that this function
    #     is called the file is not yet generated.
    file(WRITE "${ctest_include_file}" "include(\"${ctest_tests_file}\")" )
    set_property(DIRECTORY
        APPEND PROPERTY TEST_INCLUDE_FILES "${ctest_include_file}"
    )

    # add_test(NAME ${UT_NAME} COMMAND ${UT_NAME})
endfunction()
