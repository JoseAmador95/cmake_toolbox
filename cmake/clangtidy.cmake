set(CLANG_TIDY_NAME "clang-tidy" CACHE STRING "Name of the clang-tidy executable")
set(CLANG_TIDY_DIR "" CACHE STRING "Path to the directory containing the clang-tidy executable")

find_program(CLANG_TIDY_EXECUTABLE NAMES "${CLANG_TIDY_NAME}" PATHS "${CLANG_TIDY_PATH}") 
if(CLANG_TIDY_EXECUTABLE)
    message(VERBOSE "Clang-Tidy found: ${CLANG_TIDY_EXECUTABLE}")
else()
    message(VERBOSE "Clang-Tidy not found")
endif()

function(set_clang_tidy _status)
    if(CLANG_TIDY_EXECUTABLE AND _status)
        set(CMAKE_CXX_CLANG_TIDY "${CLANG_TIDY_EXECUTABLE}" CACHE INTERNAL "" FORCE)
        set(CMAKE_C_CLANG_TIDY "${CLANG_TIDY_EXECUTABLE}" CACHE INTERNAL "" FORCE)
    else()
        set(CMAKE_CXX_CLANG_TIDY "" CACHE INTERNAL "" FORCE)
        set(CMAKE_C_CLANG_TIDY "" CACHE INTERNAL "" FORCE)
    endif()
endfunction()

function(target_set_clang_tidy _target _status)
    if(CLANG_TIDY_EXECUTABLE AND _status)
        set(exe "${CLANG_TIDY_EXECUTABLE}")
    else()
        set(exe "")
    endif()

    set_target_properties(
        ${_target}
        PROPERTIES
        C_CLANG_TIDY "${exe}"
        CXX_CLANG_TIDY "${exe}"
    )
endfunction()