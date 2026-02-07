# Unit test for Sanitizer.cmake module
# This test validates that Sanitizer_AddToTarget correctly applies
# compile options and link options to targets with appropriate scope.

cmake_minimum_required(VERSION 3.22)
project(SanitizerModuleTest)

# Add parent cmake directory to module path
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_SOURCE_DIR}/../../cmake)

# Load the module under test
include(Sanitizer)

# Create a dummy library to test sanitizer instrumentation
add_library(test_dummy_lib STATIC dummy.c)

# Apply sanitizer to the library with PUBLIC scope
Sanitizer_AddToTarget(TARGET test_dummy_lib SCOPE PUBLIC)

# ==============================================================================
# Verify Properties
# ==============================================================================

# Get compile options
get_target_property(COMPILE_OPTIONS test_dummy_lib COMPILE_OPTIONS)
get_target_property(INTERFACE_COMPILE_OPTIONS test_dummy_lib INTERFACE_COMPILE_OPTIONS)

# Get link options
get_target_property(LINK_OPTIONS test_dummy_lib LINK_OPTIONS)
get_target_property(INTERFACE_LINK_OPTIONS test_dummy_lib INTERFACE_LINK_OPTIONS)

# Get environment property
get_target_property(ENVIRONMENT test_dummy_lib ENVIRONMENT)

message(STATUS "=== Sanitizer Module Test Results ===")
message(STATUS "Compiler C: ${CMAKE_C_COMPILER_ID}")
message(STATUS "Compiler CXX: ${CMAKE_CXX_COMPILER_ID}")
message(STATUS "SANITIZER_FLAGS (override): ${SANITIZER_FLAGS}")
message(STATUS "COMPILE_OPTIONS (with genex): ${COMPILE_OPTIONS}")
message(STATUS "INTERFACE_COMPILE_OPTIONS: ${INTERFACE_COMPILE_OPTIONS}")
message(STATUS "LINK_OPTIONS (with genex): ${LINK_OPTIONS}")
message(STATUS "INTERFACE_LINK_OPTIONS: ${INTERFACE_LINK_OPTIONS}")
message(STATUS "ENVIRONMENT: ${ENVIRONMENT}")

# ==============================================================================
# Assertions
# ==============================================================================

set(TEST_FAILED FALSE)

# Check compile options are set (they will contain generator expressions)
if(NOT COMPILE_OPTIONS)
    message(SEND_ERROR "COMPILE_OPTIONS is not set")
    set(TEST_FAILED TRUE)
endif()

if(NOT INTERFACE_COMPILE_OPTIONS)
    message(SEND_ERROR "INTERFACE_COMPILE_OPTIONS is not set")
    set(TEST_FAILED TRUE)
endif()

# Check link options are set (they will contain generator expressions)
if(NOT LINK_OPTIONS)
    message(SEND_ERROR "LINK_OPTIONS is not set")
    set(TEST_FAILED TRUE)
endif()

if(NOT INTERFACE_LINK_OPTIONS)
    message(SEND_ERROR "INTERFACE_LINK_OPTIONS is not set")
    set(TEST_FAILED TRUE)
endif()

# Check environment is set
if(NOT ENVIRONMENT)
    message(SEND_ERROR "ENVIRONMENT property not set")
    set(TEST_FAILED TRUE)
endif()

# Validate that generator expressions are present for per-language detection
# The options should contain $<$<COMPILE_LANGUAGE:C>:...> patterns
if(NOT SANITIZER_FLAGS)
    # Using automatic detection via generator expressions
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
endif()

# Final result
if(TEST_FAILED)
    message(FATAL_ERROR "Sanitizer module test FAILED")
else()
    message(STATUS "✓ All Sanitizer module tests PASSED")
endif()
