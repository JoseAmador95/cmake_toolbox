# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
Internal CMake script helper for verifying trimmed compile_commands.json
with clang-tidy.

This script is executed via ``cmake -P`` at build time to verify that
the trimmed compile_commands.json is accepted by clang-tidy.

Expected variables (passed via -D flags):
  ClangTidy_EXECUTABLE - Path to clang-tidy executable
  DB_PATH - Path to the trimmed compile_commands.json
  CMAKE_BINARY_DIR - Build directory for test file
#]=======================================================================]

if(NOT DEFINED ClangTidy_EXECUTABLE)
    message(FATAL_ERROR "VerifyCompileCommandsHelper: ClangTidy_EXECUTABLE is not defined")
endif()

if(NOT DEFINED DB_PATH)
    message(FATAL_ERROR "VerifyCompileCommandsHelper: DB_PATH is not defined")
endif()

if(NOT DEFINED CMAKE_BINARY_DIR)
    message(FATAL_ERROR "VerifyCompileCommandsHelper: CMAKE_BINARY_DIR is not defined")
endif()

if(NOT EXISTS "${DB_PATH}")
    message(FATAL_ERROR "VerifyCompileCommandsHelper: Database does not exist: ${DB_PATH}")
endif()

set(_test_file "${CMAKE_BINARY_DIR}/.clang_tidy_verify_test.cpp")
file(WRITE "${_test_file}" "int main() { return 0; }\n")

execute_process(
    COMMAND "${ClangTidy_EXECUTABLE}" -p "${DB_PATH}" -- "${_test_file}"
    RESULT_VARIABLE _result
    ERROR_VARIABLE _error
    OUTPUT_VARIABLE _output
    TIMEOUT 60
)

if(NOT _result EQUAL 0)
    string(FIND "${_error}" "error:" _has_error)
    string(FIND "${_error}" "unknown argument" _has_unknown_arg)

    if(_has_error GREATER -1 OR _has_unknown_arg GREATER -1)
        message(FATAL_ERROR
            "ClangTidy: Trimmed compile_commands.json contains incompatible flags!\n"
            "Error: ${_error}\n"
            "\n"
            "Suggestions:\n"
            "1. Add problematic flags to COMPILE_COMMANDS_TRIM_BLACKLIST\n"
            "2. Set CLANG_TIDY_VERIFY_TRIMMED_DB=OFF to skip verification\n"
        )
    else()
        message(WARNING
            "ClangTidy: Verification returned non-zero exit code: ${_result}\n"
            "Output: ${_output}\n"
            "Error: ${_error}"
        )
    endif()
endif()

message(STATUS "ClangTidy: Trimmed compile_commands.json verification passed")
