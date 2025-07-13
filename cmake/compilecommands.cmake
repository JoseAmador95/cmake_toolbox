set(CMAKE_TOOLBOX_JQ_PATH "" CACHE FILEPATH "Path to jq")

find_program(JQ_EXECUTABLE NAMES "jq" PATHS "${CMAKE_TOOLBOX_JQ_PATH}")
# if(JQ_EXECUTABLE)
#     message(STATUS "jq found: ${JQ_EXECUTABLE}")
# else
#     message(WARNING "jq not found")
# endif()

function(compile_commands_trim)
    set(options "")
    set(oneValueArgs
        INPUT
        OUTPUT
    )
    set(multiValueArgs "")
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})

    if(NOT JQ_EXECUTABLE)
        message(WARNING "jq not found")
        return()
    endif()

    set(JQ_SCRIPT
        ${CMAKE_CURRENT_FUNCTION_LIST_DIR}/prune_compile_commands/prune_compile_commands.jq
    )

    cmake_path(GET ARG_OUTPUT PARENT_PATH OUTPUT_DIR)
    file(MAKE_DIRECTORY ${OUTPUT_DIR})

    add_custom_command(
        OUTPUT
            ${ARG_OUTPUT}
        COMMAND
            ${JQ_EXECUTABLE} -f ${JQ_SCRIPT} ${ARG_INPUT} > ${ARG_OUTPUT}
        DEPENDS
            ${ARG_INPUT}
            ${JQ_SCRIPT}
        COMMENT "Trimming Compile Commands file '${ARG_INPUT}' into '${ARG_OUTPUT}'"
    )
endfunction()
