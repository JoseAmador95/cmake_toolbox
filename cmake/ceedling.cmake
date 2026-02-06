include_guard(GLOBAL)

option(CEEDLING_ENABLE_GCOV "Enable coverage" OFF)
option(CEEDLING_ENABLE_SANITIZER "Enable sanitizer" OFF)
option(CEEDLING_SANITIZER_DEFAULT "Enable sanitizer by default" ON)
option(CEEDLING_EXTRACT_FUNCTIONS "Extract test functions as separate ctest test" OFF)

if(CEEDLING_ENABLE_GCOV)
    include(${CMAKE_CURRENT_LIST_DIR}/gcov.cmake)
endif()

if(CEEDLING_ENABLE_SANITIZER)
    include(${CMAKE_CURRENT_LIST_DIR}/sanitizer.cmake)
endif()

include(${CMAKE_CURRENT_LIST_DIR}/Unity.cmake)

# Initialize Unity once for ceedling
Unity_Initialize()

function(add_unit_test)
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

    if(UT_DISABLE_SANITIZER AND UT_ENABLE_SANITIZER)
        message(FATAL_ERROR "Cannot enable and disable sanitizer at the same time")
    endif()

    add_executable(${UT_NAME} ${UT_UNIT_TEST})
    target_link_libraries(
        ${UT_NAME}
        PRIVATE
            ${UT_TARGET}
            Unity::CMock
            Unity::Unity
    )

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
                "add_unit_test: No cmock.yml configuration file found in expected locations"
            )
        endif()
    endif()

    # Build optional CONFIG_FILE argument
    set(config_file_arg "")
    if(default_config)
        set(config_file_arg CONFIG_FILE ${default_config})
    endif()

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
        OUTPUT
            ${TEST_RUNNER}
        DEPENDS
            ${RUNNER_SOURCE}
        COMMAND
            ${CMAKE_COMMAND} -E rename ${RUNNER_SOURCE} ${TEST_RUNNER}
        COMMENT "Move ${RUNNER_STEM} to ${TEST_BINARY_DIR}"
    )
    target_sources(${UT_NAME} PRIVATE ${TEST_RUNNER})
    target_include_directories(${UT_NAME} PRIVATE ${TEST_BINARY_DIR}/${CMOCK_MOCK_SUBDIR})

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

    if(CEEDLING_ENABLE_GCOV)
        target_add_gcov(${UT_TARGET} PUBLIC)
    endif()

    if(
        CEEDLING_ENABLE_SANITIZER
        AND (
            (
                CEEDLING_SANITIZER_DEFAULT
                AND NOT UT_DISABLE_SANITIZER
            )
            OR (
                NOT CEEDLING_SANITIZER_DEFAULT
                AND UT_ENABLE_SANITIZER
            )
        )
    )
        target_add_sanitizer(${UT_TARGET} PUBLIC)
    endif()

    set_target_properties(
        ${UT_NAME}
        PROPERTIES
            C_CLANG_TIDY
                ""
            CXX_CLANG_TIDY
                ""
            SKIP_LINTING
                TRUE
    )

    if(CEEDLING_EXTRACT_FUNCTIONS)
        # When CEEDLING_EXTRACT_FUNCTIONS is set this script will call each unit test
        # application after being build (POST_BUILD) with the '-l' argument. The output
        # is then parsed and each test reported is added as a new test using the name
        # <UT_NAME>/<TEST>.
        # This is loosely based on how gtest and boost test integration with cmake
        # is done.

        # Define name for the file generated for this test that will contain
        # the name for each test case in the test file
        set(TB_UNITY_TEST_FILE "${CMAKE_CURRENT_BINARY_DIR}/${UT_NAME}_tests.cmake")

        # Discover and add tests for the given file once it is built
        add_custom_command(
            TARGET ${UT_NAME}
            POST_BUILD
            BYPRODUCTS
                "${TB_UNITY_TEST_FILE}"
            COMMAND
                "${CMAKE_COMMAND}" #
                -D "TEST_EXECUTABLE=$<TARGET_FILE:${UT_NAME}>" #
                -D "TEST_WORKING_DIR=${CMAKE_CURRENT_BINARY_DIR}" #
                -D "TEST_SUITE=$<TARGET_FILE_NAME:${UT_NAME}>" #
                -D "TEST_FILE=${TB_UNITY_TEST_FILE}" #
                -P "${CMAKE_CURRENT_FUNCTION_LIST_DIR}/discovertests.cmake"
            VERBATIM
        )

        # Mechanism to add the unit tests after building and discovering
        #   - Can't call include(...) here since at the time that this function
        #     is called the file is not yet generated.
        set_property(
            DIRECTORY
            APPEND
            PROPERTY
                TEST_INCLUDE_FILES
                    "${TB_UNITY_TEST_FILE}"
        )
    else()
        # Add the whole file as a single test
        add_test(NAME ${UT_NAME} COMMAND ${UT_NAME})
    endif()
endfunction()
