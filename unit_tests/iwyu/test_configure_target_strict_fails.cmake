# Test: IWYU_ConfigureTarget in strict mode without tool causes configure error
# Purpose: Verify that STRICT flag on ConfigureTarget causes fatal error when IWYU unavailable
# Expected: PASS (STRICT mode enforced correctly, with or without IWYU installed)
# Executable: cmake -P test_configure_target_strict_fails.cmake

cmake_minimum_required(VERSION 3.22)

get_filename_component(abs_cmake_module_path "${CMAKE_CURRENT_LIST_DIR}/../../cmake" ABSOLUTE)

set(CMAKE_MODULE_PATH "${CMAKE_CURRENT_LIST_DIR}/../../cmake")
include(IWYU)

find_package(IWYU QUIET)

if(IWYU_FOUND)
    message(STATUS "PASS: IWYU found - STRICT mode on target will succeed (skipping failure test)")
else()
    get_filename_component(test_script_name "${CMAKE_CURRENT_LIST_FILE}" NAME_WE)
    string(TIMESTAMP test_timestamp "%Y%m%d%H%M%S")
    set(test_dir "${CMAKE_CURRENT_LIST_DIR}/test_artifacts_${test_script_name}_${test_timestamp}")
    set(build_dir "${test_dir}/build")
    file(MAKE_DIRECTORY "${build_dir}/src")
    file(WRITE "${build_dir}/src/dummy.cpp" "int add(int a, int b) { return a + b; }\n")

    file(
        WRITE "${build_dir}/CMakeLists.txt"
        "
cmake_minimum_required(VERSION 3.22)
project(IWYUStrictTarget LANGUAGES CXX)

set(CMAKE_MODULE_PATH \"${abs_cmake_module_path}\")
include(IWYU)

add_library(testlib STATIC src/dummy.cpp)
IWYU_ConfigureTarget(TARGET testlib STATUS ON STRICT)
"
    )

    execute_process(
        COMMAND
            ${CMAKE_COMMAND} -S "${build_dir}" -B "${build_dir}/cmake_build"
        RESULT_VARIABLE result
        OUTPUT_VARIABLE output
        ERROR_VARIABLE error
    )

    file(REMOVE_RECURSE "${test_dir}")

    if(NOT result EQUAL 0)
        message(
            STATUS
            "PASS: STRICT mode on target correctly enforced - configure failed as expected"
        )
        message(STATUS "  Error: ${error}")
    else()
        message(
            FATAL_ERROR
            "FAIL: STRICT mode on target did not produce fatal error when IWYU unavailable"
        )
    endif()
endif()
