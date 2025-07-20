# ClangFormat check script
# This script checks if files need formatting using clang-format
#
# Required variables:
#   CLANG_FORMAT_EXECUTABLE - path to clang-format executable
#   CLANG_FORMAT_STYLE_ARG  - style argument for clang-format (optional)
#   CLANG_FORMAT_FILES      - semicolon-separated list of files to check
#   CLANG_FORMAT_ADDITIONAL_ARGS - additional arguments (optional)

# Ensure this file is only executed as a script
if(NOT CMAKE_SCRIPT_MODE_FILE)
    message(
        FATAL_ERROR
        "This file must be executed as a script using 'cmake -P'. "
        "It cannot be included in a CMakeLists.txt file."
    )
endif()

message(STATUS "Checking code formatting...")
set(FAILED FALSE)

foreach(FILE IN LISTS CLANG_FORMAT_FILES)
    # Get relative path from CMAKE_SOURCE_DIR
    file(RELATIVE_PATH REL_FILE "${CMAKE_SOURCE_DIR}" "${FILE}")
    message(STATUS "Checking: ${REL_FILE}")

    # Create temporary file (use simple naming to avoid path issues)
    string(REPLACE "/" "_" SAFE_NAME "${REL_FILE}")
    file(MAKE_DIRECTORY "${CMAKE_BINARY_DIR}/temp")
    set(TEMP_FILE "${CMAKE_BINARY_DIR}/temp/${SAFE_NAME}.formatted")

    # Build clang-format command
    set(FORMAT_COMMAND "${CLANG_FORMAT_EXECUTABLE}")
    if(CLANG_FORMAT_STYLE_ARG)
        list(APPEND FORMAT_COMMAND "${CLANG_FORMAT_STYLE_ARG}")
    endif()
    if(CLANG_FORMAT_ADDITIONAL_ARGS)
        list(APPEND FORMAT_COMMAND ${CLANG_FORMAT_ADDITIONAL_ARGS})
    endif()
    list(APPEND FORMAT_COMMAND "${FILE}")

    # Format file to temporary location
    execute_process(
        COMMAND
            ${FORMAT_COMMAND}
        OUTPUT_FILE "${TEMP_FILE}"
        RESULT_VARIABLE FORMAT_RESULT
    )

    # Check if files are different using CMake
    file(READ "${FILE}" ORIGINAL_CONTENT)
    file(READ "${TEMP_FILE}" FORMATTED_CONTENT)
    if(NOT "${ORIGINAL_CONTENT}" STREQUAL "${FORMATTED_CONTENT}")
        message(STATUS "=== File needs formatting: ${REL_FILE} ===")

        # Try to show diff using available tools
        find_program(
            DIFF_TOOL
            NAMES
                diff
                fc
        )
        if(DIFF_TOOL)
            execute_process(
                COMMAND
                    "${DIFF_TOOL}" "-u" "${FILE}" "${TEMP_FILE}"
                OUTPUT_VARIABLE DIFF_OUTPUT
                ERROR_QUIET
            )
            if(DIFF_OUTPUT)
                # Replace absolute paths with relative paths in diff output
                string(REPLACE "${FILE}" "a/${REL_FILE}" DIFF_OUTPUT "${DIFF_OUTPUT}")
                string(REPLACE "${TEMP_FILE}" "b/${REL_FILE}" DIFF_OUTPUT "${DIFF_OUTPUT}")
                message("${DIFF_OUTPUT}")
            else()
                message("  File content differs but diff output not available")
            endif()
        else()
            message("  File content differs (no diff tool available)")
        endif()

        set(FAILED TRUE)
    endif()

    # Clean up temp file
    file(REMOVE "${TEMP_FILE}")
endforeach()

if(FAILED)
    message(FATAL_ERROR "Some files need formatting. Run the format target to fix them.")
else()
    message(STATUS "All files are properly formatted.")
endif()
