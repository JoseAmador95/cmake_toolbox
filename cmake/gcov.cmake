set(GCOV_CFG_CONFIG_FILE
    ${CMAKE_SOURCE_DIR}/gcovr.cfg
    CACHE FILEPATH
    "Path to gcovr configuration file"
)
set(GCOV_CFG_OUTPUT_FILE
    ${CMAKE_CURRENT_BINARY_DIR}/coverage/results.html
    CACHE FILEPATH
    "Path to coverage output file"
)
set(GCOV_CFG_ROOT_DIR ${CMAKE_SOURCE_DIR} CACHE PATH "Path to the root directory of the project")
set(GCOV_CFG_COMPILE_FLAGS --coverage CACHE STRING "Flags to add to the compiler for coverage")
set(GCOV_CFG_LINKER_FLAGS --coverage CACHE STRING "Flags to add to the linker for coverage")

cmake_path(GET GCOV_CFG_OUTPUT_FILE PARENT_PATH OUTPUT_DIR)
file(MAKE_DIRECTORY ${OUTPUT_DIR})

find_program(GCOVR_EXECUTABLE gcovr)
if(NOT GCOVR_EXECUTABLE)
    message(FATAL_ERROR "gcovr not found")
endif()

function(target_add_gcov _target _scope)
    target_compile_options(
        ${_target}
        ${_scope}
        ${GCOV_CFG_COMPILE_FLAGS}
    )
    target_link_libraries(
        ${_target}
        ${_scope}
        ${GCOV_CFG_LINKER_FLAGS}
    )
endfunction(
    target_add_gcov
    _target
    _scope
)

add_custom_target(
    gcovr_html
    COMMAND
        ${GCOVR_EXECUTABLE} --config ${GCOV_CFG_CONFIG_FILE} --root ${GCOV_CFG_ROOT_DIR}
        --print-summary --html-details ${GCOV_CFG_OUTPUT_FILE}
    WORKING_DIRECTORY ${GCOV_CFG_ROOT_DIR}
    COMMENT "Generate coverage HTML report"
)
