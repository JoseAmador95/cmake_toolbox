set(SANITIZER_FLAGS -fsanitize=address,undefined,leak CACHE STRING "Sanitizer flags to use")
set(SANITIZER_ENV_VARS "ASAN_OPTIONS=detect_leaks=1:abort_on_error=1;UBSAN_OPTIONS=print_stacktrace=1" CACHE STRING "Sanitizer environment variables to use")

function(target_add_sanitizer _target _scope)
    target_compile_options(${_target} ${_scope} ${SANITIZER_FLAGS})
    target_link_libraries(${_target} ${_scope} ${SANITIZER_FLAGS})
    set_target_properties(${_target} PROPERTIES ENVIRONMENT "${SANITIZER_ENV_VARS}")
endfunction(target_add_sanitizer _target _scope)
