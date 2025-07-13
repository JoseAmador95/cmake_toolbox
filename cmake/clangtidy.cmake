include_guard(GLOBAL)

set(CLANG_TIDY_NAME "clang-tidy" CACHE STRING "Name of the clang-tidy executable")
set(CLANG_TIDY_DIR "" CACHE STRING "Path to the directory containing the clang-tidy executable")
set(CLANG_TIDY_COMPILE_COMMANDS
    ${CMAKE_BINARY_DIR}/compile_commands.json
    CACHE FILEPATH
    "Path to compile_commands.json"
)

find_program(CLANG_TIDY_EXECUTABLE NAMES "${CLANG_TIDY_NAME}" PATHS "${CLANG_TIDY_PATH}")
if(CLANG_TIDY_EXECUTABLE)
    message(VERBOSE "Clang-Tidy found: ${CLANG_TIDY_EXECUTABLE}")
else()
    message(VERBOSE "Clang-Tidy not found")
endif()

include(${CMAKE_CURRENT_LIST_DIR}/compilecommands.cmake)

function(_get_clang_tidy_command _trim _retcmd _retcompilecommands)
    set(OUTPUT_FILE ${CLANG_TIDY_COMPILE_COMMANDS})
    if(_trim AND JQ_EXECUTABLE)
        set(OUTPUT_FILE ${CMAKE_CURRENT_BINARY_DIR}/compile_commands_trimmed/compile_commands.json)
        compile_commands_trim(INPUT ${CLANG_TIDY_COMPILE_COMMANDS} OUTPUT ${OUTPUT_FILE})
    endif()
    message(VERBOSE "Using Compile Commands: ${OUTPUT_FILE}")
    set(${_retcmd} "${CLANG_TIDY_EXECUTABLE};-p;${OUTPUT_FILE}" PARENT_SCOPE)
    set(${_retcompilecommands} "${OUTPUT_FILE}" PARENT_SCOPE)
endfunction()

function(set_clang_tidy)
    set(options TRIM_COMPILE_COMMANDS)
    set(oneValueArgs STATUS)
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(CLANG_TIDY_EXECUTABLE AND ARG_STATUS)
        _get_clang_tidy_command(${ARG_TRIM_COMPILE_COMMANDS} cmd compilecommands)
        set(CMAKE_CXX_CLANG_TIDY "${cmd}" CACHE INTERNAL "" FORCE)
        set(CMAKE_C_CLANG_TIDY "${cmd}" CACHE INTERNAL "" FORCE)
    else()
        set(CMAKE_CXX_CLANG_TIDY "" CACHE INTERNAL "" FORCE)
        set(CMAKE_C_CLANG_TIDY "" CACHE INTERNAL "" FORCE)
    endif()
endfunction()

function(target_set_clang_tidy)
    set(options TRIM_COMPILE_COMMANDS)
    set(oneValueArgs
        TARGET
        STATUS
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(CLANG_TIDY_EXECUTABLE AND ARG_STATUS)
        _get_clang_tidy_command(${ARG_TRIM_COMPILE_COMMANDS} exe compilecommands)
    else()
        set(exe "")
    endif()

    set_target_properties(
        ${ARG_TARGET}
        PROPERTIES
            C_CLANG_TIDY
                "${exe}"
            CXX_CLANG_TIDY
                "${exe}"
    )

    target_sources(${ARG_TARGET} PRIVATE ${compilecommands})
endfunction()
