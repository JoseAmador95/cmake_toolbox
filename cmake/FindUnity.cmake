# ============================================================================
# FindUnity
# ============================================================================
#
# CMake find module for the Unity C test framework with CMock support.
#
# This module locates existing Unity/CMock source distributions and provides
# imported targets for convenient linking. Can also fetch via FetchContent.
#
# Usage:
#   find_package(Unity REQUIRED)               # Basic usage
#   find_package(Unity QUIET)                  # Suppress status output
#
# User Cache / Environment Hints:
#   - Unity_ROOT / UNITY_ROOT (cache or normal variable)
#   - ENV{UNITY_ROOT}
#   - UNITY_FETCH (BOOL, OFF by default)  If ON and Unity not found, the
#       repositories will be fetched via FetchContent.
#   - UNITY_GIT_REPOSITORY (override Unity repo URL)
#   - UNITY_GIT_TAG (override Unity tag)
#   - CMOCK_GIT_REPOSITORY (override CMock repo URL) 
#   - CMOCK_GIT_TAG (override CMock tag)
#
# Result Variables:
#   Unity_FOUND            - TRUE if Unity located (or fetched when UNITY_FETCH=ON)
#   Unity_INCLUDE_DIR      - Directory containing unity.h
#   Unity_SOURCE           - Path to unity.c (required)
#   Unity_RUNNER_GENERATOR - Path to generate_test_runner.rb
#   Unity_VERSION          - Parsed version (major.minor[.patch]) if detected
#   Unity_VERSION_MAJOR    - Major version
#   Unity_VERSION_MINOR    - Minor version
#   Unity_VERSION_PATCH    - Patch version (if available)
#   CMock_FOUND            - TRUE if CMock located
#   CMock_INCLUDE_DIR      - Directory containing cmock.h
#   CMock_SOURCE           - Path to cmock.c (required if CMock found)
#   CMock_EXECUTABLE       - Path to cmock.rb
#
# Imported Targets:
#   Unity::Unity  - Static library target for Unity (requires unity.c)
#   Unity::CMock  - Static library target for CMock (if found)
#
# Notes:
#   - Both unity.h AND unity.c are required (no header-only mode)
#   - Version detection uses try_run with unity.h definitions for accuracy
#   - CMock integration similar to Unity.cmake module
#
# ============================================================================

include_guard(GLOBAL)

# ----------------------------------------------------------------------------
# Handle user overrides / hints
# ----------------------------------------------------------------------------
set(_Unity_HINT_DIRS)
foreach(var IN ITEMS Unity_ROOT UNITY_ROOT)
    if(${var})
        list(APPEND _Unity_HINT_DIRS "${${var}}")
    endif()
endforeach()
if(DEFINED ENV{UNITY_ROOT})
    list(APPEND _Unity_HINT_DIRS "$ENV{UNITY_ROOT}")
endif()

# Common relative subdirs to search inside each hint root
set(_Unity_SUBDIRS "" "src" "source" "unity" "unity/src" "Unity" "Unity/src" "include" "unity/include")

# ----------------------------------------------------------------------------
# Locate unity.h
# ----------------------------------------------------------------------------
unset(Unity_INCLUDE_DIR CACHE)
find_path(
    Unity_INCLUDE_DIR
    NAMES unity.h
    HINTS ${_Unity_HINT_DIRS}
    PATH_SUFFIXES ${_Unity_SUBDIRS}
)

# ----------------------------------------------------------------------------
# Locate unity.c (required)
# ----------------------------------------------------------------------------
unset(Unity_SOURCE CACHE)
# Prefer same hierarchy as header
find_file(
    Unity_SOURCE
    NAMES unity.c
    HINTS ${Unity_INCLUDE_DIR} ${_Unity_HINT_DIRS}
    PATH_SUFFIXES . src source unity unity/src
)

# ----------------------------------------------------------------------------
# Locate CMock files (optional)
# ----------------------------------------------------------------------------
unset(CMock_INCLUDE_DIR CACHE)
unset(CMock_SOURCE CACHE) 
unset(CMock_EXECUTABLE CACHE)

find_path(
    CMock_INCLUDE_DIR
    NAMES cmock.h
    HINTS ${_Unity_HINT_DIRS}
    PATH_SUFFIXES ${_Unity_SUBDIRS}
)

find_file(
    CMock_SOURCE
    NAMES cmock.c
    HINTS ${CMock_INCLUDE_DIR} ${_Unity_HINT_DIRS}
    PATH_SUFFIXES . src source cmock cmock/src
)

find_file(
    CMock_EXECUTABLE
    NAMES cmock.rb
    HINTS ${_Unity_HINT_DIRS}
    PATH_SUFFIXES . lib scripts cmock/lib cmock/scripts
)

find_file(
    Unity_RUNNER_GENERATOR
    NAMES generate_test_runner.rb
    HINTS ${Unity_INCLUDE_DIR}/.. ${_Unity_HINT_DIRS}
    PATH_SUFFIXES . auto scripts unity/auto
)

# ----------------------------------------------------------------------------
# Optional: Fetch if not found and user requested UNITY_FETCH
# ----------------------------------------------------------------------------
if((NOT Unity_INCLUDE_DIR OR NOT Unity_SOURCE) AND UNITY_FETCH)
    # Unity defaults
    set(_Unity_repo "https://github.com/ThrowTheSwitch/Unity.git")
    if(UNITY_GIT_REPOSITORY)
        set(_Unity_repo "${UNITY_GIT_REPOSITORY}")
    endif()
    set(_Unity_tag "v2.6.1")
    if(UNITY_GIT_TAG)
        set(_Unity_tag "${UNITY_GIT_TAG}")
    endif()
    
    # CMock defaults
    set(_CMock_repo "https://github.com/ThrowTheSwitch/CMock.git")
    if(CMOCK_GIT_REPOSITORY)
        set(_CMock_repo "${CMOCK_GIT_REPOSITORY}")
    endif()
    set(_CMock_tag "v2.6.0")
    if(CMOCK_GIT_TAG)
        set(_CMock_tag "${CMOCK_GIT_TAG}")
    endif()
    
    include(FetchContent)
    
    # Fetch Unity
    FetchContent_Declare(unity_repo GIT_REPOSITORY "${_Unity_repo}" GIT_TAG "${_Unity_tag}")
    # Fetch CMock
    FetchContent_Declare(cmock_repo GIT_REPOSITORY "${_CMock_repo}" GIT_TAG "${_CMock_tag}")
    
    FetchContent_MakeAvailable(unity_repo cmock_repo)
    
    if(unity_repo_SOURCE_DIR AND EXISTS "${unity_repo_SOURCE_DIR}/src/unity.c")
        set(Unity_INCLUDE_DIR "${unity_repo_SOURCE_DIR}/src")
        set(Unity_SOURCE "${unity_repo_SOURCE_DIR}/src/unity.c")
    endif()
    
    if(cmock_repo_SOURCE_DIR AND EXISTS "${cmock_repo_SOURCE_DIR}/src/cmock.c")
        set(CMock_INCLUDE_DIR "${cmock_repo_SOURCE_DIR}/src")
        set(CMock_SOURCE "${cmock_repo_SOURCE_DIR}/src/cmock.c")
        set(CMock_EXECUTABLE "${cmock_repo_SOURCE_DIR}/lib/cmock.rb")
    endif()
    
    if(unity_repo_SOURCE_DIR AND EXISTS "${unity_repo_SOURCE_DIR}/auto/generate_test_runner.rb")
        set(Unity_RUNNER_GENERATOR "${unity_repo_SOURCE_DIR}/auto/generate_test_runner.rb")
    endif()
endif()

# ----------------------------------------------------------------------------
# Parse version from unity.h using try_run for accuracy
# ----------------------------------------------------------------------------
unset(Unity_VERSION)
if(Unity_INCLUDE_DIR AND EXISTS "${Unity_INCLUDE_DIR}/unity.h")
    # Create a small test program to extract version at compile time
    set(_version_test_code "
#include <stdio.h>
#include <unity.h>

int main(void) {
#ifdef UNITY_VERSION_MAJOR
    printf(\"%d\", UNITY_VERSION_MAJOR);
#else
    printf(\"0\");
#endif
    printf(\".\");
#ifdef UNITY_VERSION_MINOR  
    printf(\"%d\", UNITY_VERSION_MINOR);
#else
    printf(\"0\");
#endif
#ifdef UNITY_VERSION_BUILD
    printf(\".%d\", UNITY_VERSION_BUILD);
#endif
    return 0;
}
")
    
    file(WRITE "${CMAKE_BINARY_DIR}/unity_version_test.c" "${_version_test_code}")
    
    try_run(
        _version_run_result
        _version_compile_result
        "${CMAKE_BINARY_DIR}"
        "${CMAKE_BINARY_DIR}/unity_version_test.c"
        CMAKE_FLAGS "-DINCLUDE_DIRECTORIES=${Unity_INCLUDE_DIR}"
        RUN_OUTPUT_VARIABLE _version_output
    )
    
    if(_version_compile_result AND _version_run_result EQUAL 0 AND _version_output)
        set(Unity_VERSION "${_version_output}")
        # Parse components
        if(Unity_VERSION MATCHES "^([0-9]+)\\.([0-9]+)(\\.([0-9]+))?")
            set(Unity_VERSION_MAJOR "${CMAKE_MATCH_1}")
            set(Unity_VERSION_MINOR "${CMAKE_MATCH_2}")
            if(CMAKE_MATCH_4)
                set(Unity_VERSION_PATCH "${CMAKE_MATCH_4}")
            endif()
        endif()
    endif()
    
    # Cleanup
    file(REMOVE "${CMAKE_BINARY_DIR}/unity_version_test.c")
endif()

# ----------------------------------------------------------------------------
# Create imported targets
# ----------------------------------------------------------------------------
# Unity requires both header and source
if(Unity_INCLUDE_DIR AND Unity_SOURCE)
    if(NOT TARGET Unity::Unity)
        add_library(unity_unity STATIC "${Unity_SOURCE}")
        target_include_directories(unity_unity
            PUBLIC
                "${Unity_INCLUDE_DIR}"
        )
        # Disable linting for external dependencies
        set_target_properties(unity_unity PROPERTIES
            C_CLANG_TIDY ""
            SKIP_LINTING TRUE
        )
        # Create namespaced alias
        add_library(Unity::Unity ALIAS unity_unity)
    endif()
endif()

# CMock target if found
set(CMock_FOUND FALSE)
if(CMock_INCLUDE_DIR AND CMock_SOURCE)
    set(CMock_FOUND TRUE)
    if(NOT TARGET Unity::CMock)
        add_library(unity_cmock STATIC "${CMock_SOURCE}")
        target_include_directories(unity_cmock
            PUBLIC
                "${CMock_INCLUDE_DIR}"
        )
        # CMock depends on Unity
        if(TARGET unity_unity)
            target_link_libraries(unity_cmock PUBLIC unity_unity)
        endif()
        # Disable linting for external dependencies
        set_target_properties(unity_cmock PROPERTIES
            C_CLANG_TIDY ""
            SKIP_LINTING TRUE
        )
        # Create namespaced alias
        add_library(Unity::CMock ALIAS unity_cmock)
    endif()
endif()

# ----------------------------------------------------------------------------
# Set required standard find_package variables
# ----------------------------------------------------------------------------
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
    Unity
    REQUIRED_VARS Unity_INCLUDE_DIR Unity_SOURCE
    VERSION_VAR Unity_VERSION
)

mark_as_advanced(Unity_INCLUDE_DIR Unity_SOURCE Unity_RUNNER_GENERATOR CMock_INCLUDE_DIR CMock_SOURCE CMock_EXECUTABLE)

# Backward compatibility convenience variables
set(Unity_INCLUDE_DIRS "${Unity_INCLUDE_DIR}" CACHE INTERNAL "Unity include dirs")
if(TARGET Unity::Unity)
    set(Unity_LIBRARIES Unity::Unity CACHE INTERNAL "Unity libraries")
endif()

if(Unity_FOUND)
    message(STATUS "${CMAKE_CURRENT_FUNCTION}: Found Unity ${Unity_VERSION}")
    message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Include: ${Unity_INCLUDE_DIR}")
    message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Source: ${Unity_SOURCE}")
    if(Unity_RUNNER_GENERATOR)
        message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Runner: ${Unity_RUNNER_GENERATOR}")
    endif()
    if(CMock_FOUND)
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Found CMock")
        message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Include: ${CMock_INCLUDE_DIR}")
        message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Source: ${CMock_SOURCE}")
        if(CMock_EXECUTABLE)
            message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Executable: ${CMock_EXECUTABLE}")
        endif()
    endif()
endif()
