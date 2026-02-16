# Test: GcovrSchema with real gcovr executable

if(NOT DEFINED CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT)
    if(DEFINED CMAKE_BINARY_DIR AND NOT CMAKE_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_BINARY_DIR}/test_artifacts")
    elseif(DEFINED CMAKE_CURRENT_BINARY_DIR AND NOT CMAKE_CURRENT_BINARY_DIR STREQUAL "")
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_BINARY_DIR}/test_artifacts")
    else()
        set(CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT "${CMAKE_CURRENT_LIST_DIR}/test_artifacts")
    endif()
endif()

get_filename_component(REPO_ROOT "${CMAKE_CURRENT_LIST_DIR}/../.." ABSOLUTE)
set(CMAKE_MODULE_PATH
    "${REPO_ROOT}/cmake"
    ${CMAKE_MODULE_PATH}
)

include(GcovrSchema)

if(NOT DEFINED GCOVR_EXECUTABLE OR GCOVR_EXECUTABLE STREQUAL "")
    message(STATUS "Skipping gcovr real test: GCOVR_EXECUTABLE not set")
    return()
endif()
if(NOT EXISTS "${GCOVR_EXECUTABLE}")
    message(FATAL_ERROR "gcovr executable not found: ${GCOVR_EXECUTABLE}")
endif()

set(TEST_ROOT "${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/gcovrschema_real_gcovr")
file(REMOVE_RECURSE "${TEST_ROOT}")
file(MAKE_DIRECTORY "${TEST_ROOT}")

message(STATUS "=== GcovrSchema Real gcovr Test ===")
message(STATUS "Using gcovr: ${GCOVR_EXECUTABLE}")

GcovrSchema_SetDefaults()
GcovrSchema_DetectVersion("${GCOVR_EXECUTABLE}" detected_version)
if(NOT detected_version STREQUAL "")
    message(STATUS "Detected gcovr version: ${detected_version}")
endif()

GcovrSchema_DetectCapabilities("${GCOVR_EXECUTABLE}" detected_flags)
list(LENGTH detected_flags flag_count)
if(flag_count EQUAL 0)
    message(FATAL_ERROR "No gcovr capabilities detected from ${GCOVR_EXECUTABLE}")
endif()

list(FIND detected_flags "--fail-under-line" has_fail_under_line)
if(has_fail_under_line EQUAL -1)
    message(FATAL_ERROR "Expected --fail-under-line flag not detected")
endif()

list(FIND detected_flags "--html" has_html)
if(has_html EQUAL -1)
    message(FATAL_ERROR "Expected --html flag not detected")
endif()

set(GCOVR_ENFORCE_THRESHOLDS ON)
set(GCOVR_FAIL_UNDER_LINE "50")

set(config_file "${TEST_ROOT}/gcovr_real.cfg")
GcovrSchema_GenerateConfigFile("${config_file}")

if(NOT EXISTS "${config_file}")
    message(FATAL_ERROR "Config file was not created: ${config_file}")
endif()

file(READ "${config_file}" config_content)
string(FIND "${config_content}" "fail-under-line" has_fail_under_key)
if(has_fail_under_key EQUAL -1)
    message(FATAL_ERROR "Config file missing fail-under-line entry")
endif()

message(STATUS "GcovrSchema real gcovr test PASSED")
