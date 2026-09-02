# Unit test for Gcov.cmake module
# Validates that Gcov_AddToTarget applies the real coverage flags, per language,
# with the requested scope, and that the gcovr target is created.

cmake_minimum_required(VERSION 3.22)
project(GcovModuleTest)

# Add parent cmake directory to module path
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../cmake)

# Test helpers for mock tools
include(TestHelpers)

# Provide a mock gcovr if none is specified
if(NOT GCOVR_EXECUTABLE)
    set(_gcovr_mock_dir "${CMAKE_CURRENT_BINARY_DIR}/mock_gcovr")
    TestHelpers_CreateMockGcovr(_gcovr_mock OUTPUT_DIR "${_gcovr_mock_dir}")
    file(TO_CMAKE_PATH "${_gcovr_mock}" _gcovr_mock_path)
    set(GCOVR_EXECUTABLE "${_gcovr_mock_path}" CACHE FILEPATH "" FORCE)
endif()

# Load the module under test
include(Gcov)

# Create a dummy library to test coverage instrumentation
add_library(test_coverage_lib STATIC dummy.c)

# Apply coverage to the library with PUBLIC scope
Gcov_AddToTarget(test_coverage_lib PUBLIC)

# ==============================================================================
# Verify Properties
# ==============================================================================

get_target_property(COMPILE_OPTIONS test_coverage_lib COMPILE_OPTIONS)
get_target_property(INTERFACE_COMPILE_OPTIONS test_coverage_lib INTERFACE_COMPILE_OPTIONS)
get_target_property(LINK_OPTIONS test_coverage_lib LINK_OPTIONS)
get_target_property(INTERFACE_LINK_OPTIONS test_coverage_lib INTERFACE_LINK_OPTIONS)

message(STATUS "=== Gcov Module Test Results ===")
message(STATUS "Compiler C: ${CMAKE_C_COMPILER_ID}")
message(STATUS "Compiler CXX: ${CMAKE_CXX_COMPILER_ID}")
message(STATUS "GCOV_COMPILE_FLAGS (override): ${GCOV_COMPILE_FLAGS}")
message(STATUS "GCOV_LINK_FLAGS (override): ${GCOV_LINK_FLAGS}")
message(STATUS "COMPILE_OPTIONS (with genex): ${COMPILE_OPTIONS}")
message(STATUS "INTERFACE_COMPILE_OPTIONS: ${INTERFACE_COMPILE_OPTIONS}")
message(STATUS "LINK_OPTIONS (with genex): ${LINK_OPTIONS}")
message(STATUS "INTERFACE_LINK_OPTIONS: ${INTERFACE_LINK_OPTIONS}")
message(STATUS "CMT_GCOVR_COMMAND: ${CMT_GCOVR_COMMAND}")

# ==============================================================================
# Assertions
# ==============================================================================

set(TEST_FAILED FALSE)

# The expected instrumentation flag: the manual override when given, otherwise
# the automatic per-language default (--coverage for GNU/Clang/AppleClang).
set(EXPECTED_COMPILE_FLAG "--coverage")
if(GCOV_COMPILE_FLAGS)
    set(EXPECTED_COMPILE_FLAG "${GCOV_COMPILE_FLAGS}")
endif()
set(EXPECTED_LINK_FLAG "--coverage")
if(GCOV_LINK_FLAGS)
    set(EXPECTED_LINK_FLAG "${GCOV_LINK_FLAGS}")
endif()

# The core promise of the module: the instrumentation flag really lands on the
# target, both privately and on the PUBLIC interface.
foreach(prop COMPILE_OPTIONS INTERFACE_COMPILE_OPTIONS)
    if(NOT "${${prop}}" MATCHES "${EXPECTED_COMPILE_FLAG}")
        message(SEND_ERROR "${prop} must contain '${EXPECTED_COMPILE_FLAG}': ${${prop}}")
        set(TEST_FAILED TRUE)
    endif()
endforeach()

foreach(prop LINK_OPTIONS INTERFACE_LINK_OPTIONS)
    if(NOT "${${prop}}" MATCHES "${EXPECTED_LINK_FLAG}")
        message(SEND_ERROR "${prop} must contain '${EXPECTED_LINK_FLAG}': ${${prop}}")
        set(TEST_FAILED TRUE)
    endif()
endforeach()

if(NOT GCOV_COMPILE_FLAGS)
    # Automatic detection must be language-gated so that mixed toolchains only
    # get --coverage for the languages that support it.
    if(NOT COMPILE_OPTIONS MATCHES "\\$<\\$<COMPILE_LANGUAGE:C>:--coverage>")
        message(
            SEND_ERROR
            "Expected a $<COMPILE_LANGUAGE:C> guarded --coverage: ${COMPILE_OPTIONS}"
        )
        set(TEST_FAILED TRUE)
    endif()

    # Link options are not language-gated (they apply to the whole target).
    if(LINK_OPTIONS MATCHES "COMPILE_LANGUAGE")
        message(SEND_ERROR "LINK_OPTIONS must not be language-gated: ${LINK_OPTIONS}")
        set(TEST_FAILED TRUE)
    endif()
endif()

# The Ceedling module binds to a target literally named 'gcovr'.
if(NOT TARGET gcovr)
    message(SEND_ERROR "Expected the 'gcovr' report target to be created")
    set(TEST_FAILED TRUE)
endif()

# Without CMT_GCOVR_CONFIG_FILE the module generates a gcovr.cfg.
if(NOT EXISTS "${CMAKE_BINARY_DIR}/coverage/gcovr_generated.cfg")
    message(SEND_ERROR "Expected a generated gcovr.cfg in ${CMAKE_BINARY_DIR}/coverage")
    set(TEST_FAILED TRUE)
endif()

# Final result
if(TEST_FAILED)
    message(FATAL_ERROR "Gcov module test FAILED")
else()
    message(STATUS "All Gcov module tests PASSED")
endif()
