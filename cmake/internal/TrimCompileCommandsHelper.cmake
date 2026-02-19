# SPDX-License-Identifier: MIT

#[=======================================================================[.rst:
Internal CMake script helper for CompileCommands_Trim function.

This script is executed via ``cmake -P`` to trim a compile_commands.json file
using built-in CMake JSON processing. It is designed to work portably across
different CMake generators (Ninja, Make, MSBuild, etc.) and platforms without
shell redirection or external tools.

Expected variables (passed via -D flags):
  INPUT_FILE - Path to the source compile_commands.json
  OUTPUT_FILE - Path where the trimmed output will be written
#]=======================================================================]

function(_CompileCommands_TokenHasArgFlag token result_var)
    if(token STREQUAL "-I"
       OR token STREQUAL "-isystem"
       OR token STREQUAL "-iquote"
       OR token STREQUAL "-idirafter"
       OR token STREQUAL "-iframework"
       OR token STREQUAL "-isysroot"
       OR token STREQUAL "-include"
       OR token STREQUAL "-include-pch"
       OR token STREQUAL "-imacros"
       OR token STREQUAL "-o"
       OR token STREQUAL "-imsvc"
       OR token STREQUAL "-resource-dir")
        set(${result_var} TRUE PARENT_SCOPE)
    else()
        set(${result_var} FALSE PARENT_SCOPE)
    endif()
endfunction()

function(_CompileCommands_JsonEscape input output_var)
    set(escaped "${input}")
    string(REPLACE "\\" "\\\\" escaped "${escaped}")
    string(REPLACE "\"" "\\\"" escaped "${escaped}")
    string(REPLACE "\n" "\\n" escaped "${escaped}")
    string(REPLACE "\r" "\\r" escaped "${escaped}")
    string(REPLACE "\t" "\\t" escaped "${escaped}")
    string(REPLACE "\b" "\\b" escaped "${escaped}")
    string(REPLACE "\f" "\\f" escaped "${escaped}")
    set(${output_var} "${escaped}" PARENT_SCOPE)
endfunction()

function(_CompileCommands_TrimCommand input_command_var output_var)
    set(input_command "${${input_command_var}}")
    separate_arguments(tokens UNIX_COMMAND "${input_command}")

    list(LENGTH tokens token_count)
    if(token_count EQUAL 0)
        set(${output_var} "" PARENT_SCOPE)
        return()
    endif()

    math(EXPR last_idx "${token_count} - 1")
    set(trimmed_tokens "")

    foreach(idx RANGE 0 ${last_idx})
        list(GET tokens ${idx} tok)
        set(keep FALSE)

        if(idx EQUAL 0 OR idx EQUAL last_idx)
            set(keep TRUE)
        elseif(tok MATCHES "^-D")
            set(keep TRUE)
        elseif(tok MATCHES "^-std=")
            set(keep TRUE)
        elseif(tok MATCHES "^-I[^ ]+")
            set(keep TRUE)
        endif()

        if(NOT keep)
            _CompileCommands_TokenHasArgFlag("${tok}" tok_has_arg)
            if(tok_has_arg)
                set(keep TRUE)
            endif()
        endif()

        if(NOT keep AND idx GREATER 0)
            math(EXPR prev_idx "${idx} - 1")
            list(GET tokens ${prev_idx} prev_tok)
            _CompileCommands_TokenHasArgFlag("${prev_tok}" prev_has_arg)
            if(prev_has_arg)
                set(keep TRUE)
            endif()
        endif()

        if(keep)
            list(APPEND trimmed_tokens "${tok}")
        endif()
    endforeach()

    set(trimmed_command "")
    set(first TRUE)
    foreach(tok IN LISTS trimmed_tokens)
        if(first)
            set(first FALSE)
        else()
            string(APPEND trimmed_command " ")
        endif()
        if(tok MATCHES " ")
            string(APPEND trimmed_command "\"${tok}\"")
        else()
            string(APPEND trimmed_command "${tok}")
        endif()
    endforeach()
    set(${output_var} "${trimmed_command}" PARENT_SCOPE)
endfunction()

if(NOT DEFINED INPUT_FILE)
    message(FATAL_ERROR "TrimCompileCommandsHelper: INPUT_FILE is not defined")
endif()

if(NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "TrimCompileCommandsHelper: OUTPUT_FILE is not defined")
endif()

if(NOT EXISTS "${INPUT_FILE}")
    message(FATAL_ERROR "TrimCompileCommandsHelper: INPUT_FILE does not exist: ${INPUT_FILE}")
endif()

get_filename_component(output_dir "${OUTPUT_FILE}" DIRECTORY)
if(NOT EXISTS "${output_dir}")
    file(MAKE_DIRECTORY "${output_dir}")
endif()

file(READ "${INPUT_FILE}" input_json)

string(JSON entry_count ERROR_VARIABLE json_error LENGTH "${input_json}")
if(json_error)
    message(FATAL_ERROR "TrimCompileCommandsHelper: Failed to parse JSON: ${json_error}")
endif()

set(output_json "${input_json}")

if(entry_count GREATER 0)
    math(EXPR last_entry "${entry_count} - 1")
    foreach(index RANGE 0 ${last_entry})
        string(JSON command ERROR_VARIABLE command_error GET "${input_json}" ${index} command)
        if(command_error)
            message(
                FATAL_ERROR
                "TrimCompileCommandsHelper: Failed to read command at index ${index}: ${command_error}"
            )
        endif()

        set(trim_command_input "${command}")
        _CompileCommands_TrimCommand(trim_command_input trimmed_command)
        _CompileCommands_JsonEscape("${trimmed_command}" command_json)

        string(JSON updated_json ERROR_VARIABLE set_error SET "${output_json}" ${index} command "\"${command_json}\"")
        if(set_error)
            message(
                FATAL_ERROR
                "TrimCompileCommandsHelper: Failed to update command at index ${index}: ${set_error}"
            )
        endif()
        set(output_json "${updated_json}")
    endforeach()
endif()

file(WRITE "${OUTPUT_FILE}" "${output_json}")

if(NOT EXISTS "${OUTPUT_FILE}")
    message(FATAL_ERROR "TrimCompileCommandsHelper: Failed to create output file: ${OUTPUT_FILE}")
endif()

message(STATUS "Successfully trimmed compile commands: ${OUTPUT_FILE}")
