# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
Internal CMake script wrapper for clang-tidy that detects unknown compiler flags.

This script wraps clang-tidy execution to detect and report unknown compiler
flags, providing actionable suggestions for the user.

Expected variables (passed via -D flags):
  ClangTidy_EXECUTABLE - Path to clang-tidy executable

Arguments after ``--`` are passed directly to clang-tidy.

Exit code:
  Propagates clang-tidy's exit code.
#]=======================================================================]

if(NOT DEFINED ClangTidy_EXECUTABLE)
    message(FATAL_ERROR "ClangTidyWrapper: ClangTidy_EXECUTABLE is not defined")
endif()

set(_clang_tidy_args "")
set(_found_separator FALSE)

math(EXPR _argc "${CMAKE_ARGC} - 1")
foreach(_i RANGE 0 ${_argc})
    if(CMAKE_ARGV${_i} STREQUAL "--")
        set(_found_separator TRUE)
    elseif(_found_separator)
        string(APPEND _clang_tidy_args " \"${CMAKE_ARGV${_i}}\"")
    endif()
endforeach()

if(NOT _found_separator OR _clang_tidy_args STREQUAL "")
    message(FATAL_ERROR "ClangTidyWrapper: No arguments provided after '--'")
endif()

separate_arguments(_args UNIX_COMMAND "${_clang_tidy_args}")

execute_process(
    COMMAND "${ClangTidy_EXECUTABLE}" ${_args}
    RESULT_VARIABLE _exit_code
    OUTPUT_VARIABLE _stdout
    ERROR_VARIABLE _stderr
)

if(NOT _stdout STREQUAL "")
    message(STATUS "${_stdout}")
endif()

if(_stderr MATCHES "unknown argument:")
    set(_unknown_flags "")
    string(REPLACE "\n" ";" _stderr_lines "${_stderr}")

    foreach(_line IN LISTS _stderr_lines)
        if(_line MATCHES "error: unknown argument: '([^']+)'")
            list(APPEND _unknown_flags "${CMAKE_MATCH_1}")
        endif()
    endforeach()

    list(REMOVE_DUPLICATES _unknown_flags)
    list(LENGTH _unknown_flags _flag_count)

    if(_flag_count GREATER 0)
        message("")
        message("ClangTidy: clang-tidy reported ${_flag_count} unknown compiler flag(s):")
        foreach(_flag IN LISTS _unknown_flags)
            message("  - '${_flag}'")
        endforeach()
        message("")

        set(_blacklist_suggestion "")
        foreach(_flag IN LISTS _unknown_flags)
            string(REGEX REPLACE "([.+*?^$\\[\\]{}|()])" "\\\\\\1" _escaped_flag "${_flag}")

            if(_flag MATCHES "^-W")
                string(REGEX REPLACE "^-W" "" _warn_name "${_flag}")
                set(_blacklist_pattern "^-W${_warn_name}$")
            elseif(_flag MATCHES "^-f")
                set(_blacklist_pattern "^${_escaped_flag}$")
            elseif(_flag MATCHES "^-m")
                if(_flag MATCHES "=")
                    string(REGEX REPLACE "=.*" "=.*" _blacklist_pattern "${_flag}")
                    set(_blacklist_pattern "^${_blacklist_pattern}")
                else()
                    set(_blacklist_pattern "^${_escaped_flag}$")
                endif()
            else()
                set(_blacklist_pattern "^${_escaped_flag}$")
            endif()

            if(_blacklist_suggestion STREQUAL "")
                set(_blacklist_suggestion "${_blacklist_pattern}")
            else()
                string(APPEND _blacklist_suggestion ";${_blacklist_pattern}")
            endif()
        endforeach()

        message("Consider adding to COMPILE_COMMANDS_TRIM_BLACKLIST:")
        message("  set(COMPILE_COMMANDS_TRIM_BLACKLIST \"${_blacklist_suggestion}\")")
        message("")
        message("Original clang-tidy output:")
    endif()
endif()

if(NOT _stderr STREQUAL "")
    message(STATUS "${_stderr}")
endif()

if(NOT _exit_code EQUAL 0)
    message(FATAL_ERROR "ClangTidy: clang-tidy exited with code ${_exit_code}")
endif()
