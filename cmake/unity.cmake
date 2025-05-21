include_guard(GLOBAL)

set(UNITY_REPO https://github.com/ThrowTheSwitch/Unity.git CACHE STRING "Unity repository")
set(UNITY_TAG v2.6.0 CACHE STRING "Unity tag")
set(CMOCK_REPO https://github.com/ThrowTheSwitch/CMock.git CACHE STRING "CMock repository")
set(CMOCK_TAG v2.5.3 CACHE STRING "CMock tag")

include(FetchContent)

FetchContent_Declare(
    cmock_repo
    GIT_REPOSITORY ${CMOCK_REPO}
    GIT_TAG        ${CMOCK_TAG}
)

FetchContent_Declare(
    unity_repo
    GIT_REPOSITORY ${UNITY_REPO}
    GIT_TAG        ${UNITY_TAG}
)
FetchContent_MakeAvailable(unity_repo cmock_repo)

find_package(Ruby REQUIRED)

set(CMOCK_OUTPUT_DIR ${CMAKE_CURRENT_BINARY_DIR} CACHE STRING "Output directory for mock files")
set(CMOCK_MOCK_PREFIX mock_ CACHE STRING "Prefix for mock files")
set(CMOCK_MOCK_SUFFIX "" CACHE STRING "Suffix for mock files")
set(CMOCK_CONFIG_FILE ${CMAKE_SOURCE_DIR}/cmock.yml CACHE STRING "Configuration file for CMock")

set(CMOCK_GENERATED_CONFIG_FILE ${CMAKE_CURRENT_BINARY_DIR}/cmock.yml)
set(CMOCK_MOCK_SUBDIR mocks)
set(CMOCK_MOCK_DIR ${CMOCK_OUTPUT_DIR}/${CMOCK_MOCK_SUBDIR})
set(RUNNER_OUTPUT_DIR ${CMOCK_OUTPUT_DIR}/runners)
set(CMOCK_EXE ${cmock_repo_SOURCE_DIR}/lib/cmock.rb)
set(RUNNER_EXE ${unity_SOURCE_DIR}/auto/generate_test_runner.rb)

configure_file(${CMOCK_CONFIG_FILE} ${CMOCK_GENERATED_CONFIG_FILE} @ONLY)
file(MAKE_DIRECTORY ${CMOCK_OUTPUT_DIR})
file(MAKE_DIRECTORY ${RUNNER_OUTPUT_DIR})

add_library(cmock STATIC ${cmock_repo_SOURCE_DIR}/src/cmock.c)
target_include_directories(cmock PUBLIC ${cmock_repo_SOURCE_DIR}/src)
target_link_libraries(cmock PUBLIC unity)
set_target_properties(cmock PROPERTIES C_CLANG_TIDY "" SKIP_LINTING TRUE)
set_target_properties(unity PROPERTIES C_CLANG_TIDY "" SKIP_LINTING TRUE)

# When .. is specified, ensure that :cmdline_args: true is found under unity option
# If not fail and warn the user (or reconsider this to add it)
if(CEEDLING_EXTRACT_FUNCTIONS)
    # Need to set 'UNITY_USE_COMMAND_LINE_ARGS' when building unity to allow the -l command to work
    target_compile_definitions(unity PUBLIC UNITY_USE_COMMAND_LINE_ARGS)

    message(STATUS "[toolbox] Checking if 'cmdline_args' is set to true")
    # Read the content of the file
    file(READ "${CMOCK_GENERATED_CONFIG_FILE}" CONFIG_CONTENT)
    # Define the regex pattern to match ':cmdline_args: true' nested under ':unity:'
    # This regex is not a cath call, it will at most handle commented out option but
    # not incorrect nesting etc
    set(REGEX_PATTERN "[ \\t]+:cmdline_args:[ \\t]*true")

    # Check if the pattern exists in the file content
    string(REGEX MATCH "${REGEX_PATTERN}" MATCH_RESULT "${CONFIG_CONTENT}")

    if(MATCH_RESULT)
        message(STATUS "[toolbox] ':cmdline_args: true' found, assuming it is correct")
    else()
        message(FATAL_ERROR "[toolbox] ':cmdline_args: true' not found in ${CMOCK_CONFIG_FILE}")
    endif()
endif()


function(mock_header _header _mock_source _mock_header _output_dir)
    cmake_path(GET _header STEM _header_name)
    set(MOCK_DIR ${_output_dir}/${CMOCK_MOCK_SUBDIR})
    file(MAKE_DIRECTORY ${MOCK_DIR})
    set(MOCK_SOURCE ${MOCK_DIR}/${CMOCK_MOCK_PREFIX}${_header_name}.c)
    set(MOCK_HEADER ${MOCK_DIR}/${CMOCK_MOCK_PREFIX}${_header_name}.h)
    add_custom_command(
        OUTPUT ${MOCK_SOURCE} ${MOCK_HEADER}
        COMMAND ${Ruby_EXECUTABLE} ${CMOCK_EXE} ${_header} -o${CMOCK_GENERATED_CONFIG_FILE}
        WORKING_DIRECTORY ${_output_dir}
        DEPENDS ${CMOCK_GENERATED_CONFIG_FILE}
                ${_header}
                ${Ruby_EXECUTABLE}
        COMMENT "Generate a mock for ${_header}"
    )
    set(${_mock_source} ${MOCK_SOURCE} PARENT_SCOPE)
    set(${_mock_header} ${MOCK_HEADER} PARENT_SCOPE)
endfunction()

function(generate_runner _test_source _runner_source)
    cmake_path(GET _test_source STEM _test_name)
    set(RUNNER_SOURCE ${RUNNER_OUTPUT_DIR}/${_test_name}_runner.c)
    add_custom_command(
        OUTPUT ${RUNNER_SOURCE}
        COMMAND ${Ruby_EXECUTABLE} ${RUNNER_EXE} ${CMOCK_GENERATED_CONFIG_FILE} ${_test_source} ${RUNNER_SOURCE}
        DEPENDS ${_test_source}
                ${CMOCK_GENERATED_CONFIG_FILE}
                ${Ruby_EXECUTABLE}
        COMMENT "Generate a test runner for ${_test_source}"
    )
    set(${_runner_source} ${RUNNER_SOURCE} PARENT_SCOPE)
endfunction()