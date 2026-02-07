# Unit test for Gcov.cmake module
# This test validates that Gcov_AddToTarget correctly applies
# compile options and link options to targets with appropriate scope.

cmake_minimum_required(VERSION 3.22)
project(GcovModuleTest)

# Add parent cmake directory to module path
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../cmake)

# Load the module under test
include(Gcov)

# Create a dummy library to test coverage instrumentation
add_library(test_coverage_lib STATIC dummy.c)

# Apply coverage to the library with PUBLIC scope
Gcov_AddToTarget(test_coverage_lib PUBLIC)

# ==============================================================================
# Verify Properties
# ==============================================================================

# Get compile options
get_target_property(COMPILE_OPTIONS test_coverage_lib COMPILE_OPTIONS)
get_target_property(INTERFACE_COMPILE_OPTIONS test_coverage_lib INTERFACE_COMPILE_OPTIONS)

# Get link options
get_target_property(LINK_OPTIONS test_coverage_lib LINK_OPTIONS)
get_target_property(INTERFACE_LINK_OPTIONS test_coverage_lib INTERFACE_LINK_OPTIONS)

message(STATUS "=== Gcov Module Test Results ===")
message(STATUS "Compiler C: ${CMAKE_C_COMPILER_ID}")
message(STATUS "Compiler CXX: ${CMAKE_CXX_COMPILER_ID}")
message(STATUS "GCOV_COMPILE_FLAGS (override): ${GCOV_COMPILE_FLAGS}")
message(STATUS "GCOV_LINKER_FLAGS (override): ${GCOV_LINKER_FLAGS}")
message(STATUS "COMPILE_OPTIONS (with genex): ${COMPILE_OPTIONS}")
message(STATUS "INTERFACE_COMPILE_OPTIONS: ${INTERFACE_COMPILE_OPTIONS}")
message(STATUS "LINK_OPTIONS (with genex): ${LINK_OPTIONS}")
message(STATUS "INTERFACE_LINK_OPTIONS: ${INTERFACE_LINK_OPTIONS}")

# ==============================================================================
# Assertions
# ==============================================================================

set(TEST_FAILED FALSE)

# Check properties are set (they will contain generator expressions if using auto-detection)
if(NOT GCOV_COMPILE_FLAGS AND NOT GCOV_LINKER_FLAGS)
    # Using automatic detection via generator expressions
    if(NOT COMPILE_OPTIONS)
        message(SEND_ERROR "COMPILE_OPTIONS should be set with generator expressions")
        set(TEST_FAILED TRUE)
    endif()
    
    if(NOT LINK_OPTIONS)
        message(SEND_ERROR "LINK_OPTIONS should be set with generator expressions")
        set(TEST_FAILED TRUE)
    endif()
    
    # Validate that generator expressions are present for per-language detection
    string(FIND "${COMPILE_OPTIONS}" "COMPILE_LANGUAGE" HAS_GENEX)
    if(HAS_GENEX EQUAL -1)
        message(SEND_ERROR "Expected generator expressions in COMPILE_OPTIONS for language detection")
        set(TEST_FAILED TRUE)
    else()
        message(STATUS "✓ Generator expressions (per-language) detected in compile options")
        # Verify structure: should have $<$<COMPILE_LANGUAGE:C>:...> or $<$<COMPILE_LANGUAGE:CXX>:...>
        if(COMPILE_OPTIONS MATCHES "COMPILE_LANGUAGE:C")
            message(STATUS "✓ C language-specific flags detected")
        endif()
        if(COMPILE_OPTIONS MATCHES "COMPILE_LANGUAGE:CXX")
            message(STATUS "✓ C++ language-specific flags detected")
        endif()
    endif()
    
    message(STATUS "✓ Using automatic per-language coverage detection (no manual overrides)")
else()
    # User provided manual override
    message(STATUS "✓ Using manual GCOV_COMPILE_FLAGS/GCOV_LINKER_FLAGS override")
endif()

# Final result
if(TEST_FAILED)
    message(FATAL_ERROR "Gcov module test FAILED")
else()
    message(STATUS "✓ All Gcov module tests PASSED")
endif()
