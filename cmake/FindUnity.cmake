# SPDX-License-Identifier: MIT
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
#   - CMT_UNITY_GIT_REPOSITORY (override Unity repo URL)
#   - CMT_UNITY_GIT_TAG (override Unity tag)
#   - CMT_CMOCK_GIT_REPOSITORY (override CMock repo URL)
#   - CMT_CMOCK_GIT_TAG (override CMock tag)
#
# Result Variables:
#   Unity_FOUND            - TRUE if Unity located (or fetched when UNITY_FETCH=ON)
#   CMT_UNITY_INCLUDE_DIR      - Directory containing unity.h
#   CMT_UNITY_SOURCE           - Path to unity.c (required)
#   Unity_RUNNER_GENERATOR - Path to generate_test_runner.rb
#   Unity_VERSION          - Parsed version (major.minor[.patch]) if detected
#   Unity_VERSION_MAJOR    - Major version
#   Unity_VERSION_MINOR    - Minor version
#   Unity_VERSION_PATCH    - Patch version (if available)
#   CMock_FOUND            - TRUE if CMock located
#   CMT_CMOCK_INCLUDE_DIR      - Directory containing cmock.h
#   CMT_CMOCK_SOURCE           - Path to cmock.c (required if CMock found)
#   CMT_CMOCK_EXECUTABLE       - Path to cmock.rb
#
# Imported Targets:
#   Unity::Unity  - Static library target for Unity (requires unity.c)
#   Unity::CMock  - Static library target for CMock (if found)
#
# Notes:
#   - Both unity.h AND unity.c are required (no header-only mode)
#   - Version detection parses unity.h preprocessor macros (cross-compile safe)
#   - CMock integration similar to Unity.cmake module
#
# ============================================================================

include_guard(GLOBAL)

# ----------------------------------------------------------------------------
# Handle user overrides / hints
# ----------------------------------------------------------------------------
set(_Unity_HINT_DIRS)
foreach(var IN ITEMS Unity_ROOT UNITY_ROOT)
    if(DEFINED ${var})
        list(APPEND _Unity_HINT_DIRS "${${var}}")
    endif()
endforeach()
if(DEFINED ENV{UNITY_ROOT})
    list(APPEND _Unity_HINT_DIRS "$ENV{UNITY_ROOT}")
endif()

# Common relative subdirs to search inside each hint root
set(_Unity_SUBDIRS
    ""
    "src"
    "source"
    "unity"
    "unity/src"
    "Unity"
    "Unity/src"
    "include"
    "unity/include"
)

# ----------------------------------------------------------------------------
# Locate unity.h
# ----------------------------------------------------------------------------
unset(CMT_UNITY_INCLUDE_DIR CACHE)
find_path(
    CMT_UNITY_INCLUDE_DIR
    NAMES
        unity.h
    HINTS
        ${_Unity_HINT_DIRS}
    PATH_SUFFIXES
        ${_Unity_SUBDIRS}
)

# ----------------------------------------------------------------------------
# Locate unity.c (required)
# ----------------------------------------------------------------------------
unset(CMT_UNITY_SOURCE CACHE)
# Prefer same hierarchy as header
find_file(
    CMT_UNITY_SOURCE
    NAMES
        unity.c
    HINTS
        ${CMT_UNITY_INCLUDE_DIR}
        ${_Unity_HINT_DIRS}
    PATH_SUFFIXES
        .
        src
        source
        unity
        unity/src
)

# ----------------------------------------------------------------------------
# Locate CMock files (optional)
# ----------------------------------------------------------------------------
unset(CMT_CMOCK_INCLUDE_DIR CACHE)
unset(CMT_CMOCK_SOURCE CACHE)
unset(CMT_CMOCK_EXECUTABLE CACHE)

find_path(
    CMT_CMOCK_INCLUDE_DIR
    NAMES
        cmock.h
    HINTS
        ${_Unity_HINT_DIRS}
    PATH_SUFFIXES
        ${_Unity_SUBDIRS}
)

find_file(
    CMT_CMOCK_SOURCE
    NAMES
        cmock.c
    HINTS
        ${CMT_CMOCK_INCLUDE_DIR}
        ${_Unity_HINT_DIRS}
    PATH_SUFFIXES
        .
        src
        source
        cmock
        cmock/src
)

find_file(
    CMT_CMOCK_EXECUTABLE
    NAMES
        cmock.rb
    HINTS
        ${_Unity_HINT_DIRS}
    PATH_SUFFIXES
        .
        lib
        scripts
        cmock/lib
        cmock/scripts
)

find_file(
    Unity_RUNNER_GENERATOR
    NAMES
        generate_test_runner.rb
    HINTS
        ${CMT_UNITY_INCLUDE_DIR}/..
        ${_Unity_HINT_DIRS}
    PATH_SUFFIXES
        .
        auto
        scripts
        unity/auto
)

# ----------------------------------------------------------------------------
# Optional: Fetch if not found and user requested UNITY_FETCH
# ----------------------------------------------------------------------------
if((NOT CMT_UNITY_INCLUDE_DIR OR NOT CMT_UNITY_SOURCE) AND UNITY_FETCH)
    # Unity defaults
    set(_Unity_repo "https://github.com/ThrowTheSwitch/Unity.git")
    if(CMT_UNITY_GIT_REPOSITORY)
        set(_Unity_repo "${CMT_UNITY_GIT_REPOSITORY}")
    endif()
    set(_Unity_tag "v2.6.1")
    if(CMT_UNITY_GIT_TAG)
        set(_Unity_tag "${CMT_UNITY_GIT_TAG}")
    endif()

    # CMock defaults
    set(_CMock_repo "https://github.com/ThrowTheSwitch/CMock.git")
    if(CMT_CMOCK_GIT_REPOSITORY)
        set(_CMock_repo "${CMT_CMOCK_GIT_REPOSITORY}")
    endif()
    set(_CMock_tag "v2.6.0")
    if(CMT_CMOCK_GIT_TAG)
        set(_CMock_tag "${CMT_CMOCK_GIT_TAG}")
    endif()

    include(FetchContent)

    # Fetch Unity
    FetchContent_Declare(unity_repo GIT_REPOSITORY "${_Unity_repo}" GIT_TAG "${_Unity_tag}")
    # Fetch CMock
    FetchContent_Declare(cmock_repo GIT_REPOSITORY "${_CMock_repo}" GIT_TAG "${_CMock_tag}")

    FetchContent_MakeAvailable(
        unity_repo
        cmock_repo
    )

    if(unity_repo_SOURCE_DIR AND EXISTS "${unity_repo_SOURCE_DIR}/src/unity.c")
        set(CMT_UNITY_INCLUDE_DIR "${unity_repo_SOURCE_DIR}/src")
        set(CMT_UNITY_SOURCE "${unity_repo_SOURCE_DIR}/src/unity.c")
    endif()

    if(cmock_repo_SOURCE_DIR AND EXISTS "${cmock_repo_SOURCE_DIR}/src/cmock.c")
        set(CMT_CMOCK_INCLUDE_DIR "${cmock_repo_SOURCE_DIR}/src")
        set(CMT_CMOCK_SOURCE "${cmock_repo_SOURCE_DIR}/src/cmock.c")
        set(CMT_CMOCK_EXECUTABLE "${cmock_repo_SOURCE_DIR}/lib/cmock.rb")
    endif()

    if(unity_repo_SOURCE_DIR AND EXISTS "${unity_repo_SOURCE_DIR}/auto/generate_test_runner.rb")
        set(Unity_RUNNER_GENERATOR "${unity_repo_SOURCE_DIR}/auto/generate_test_runner.rb")
    endif()
endif()

# ----------------------------------------------------------------------------
# Parse version from unity.h macros (cross-compile safe)
# ----------------------------------------------------------------------------
unset(Unity_VERSION)
unset(Unity_VERSION_MAJOR)
unset(Unity_VERSION_MINOR)
unset(Unity_VERSION_PATCH)
if(CMT_UNITY_INCLUDE_DIR AND EXISTS "${CMT_UNITY_INCLUDE_DIR}/unity.h")
    set(_unity_header "${CMT_UNITY_INCLUDE_DIR}/unity.h")
    file(
        STRINGS "${_unity_header}"
        _unity_version_macro_lines
        REGEX "^#[ \t]*define[ \t]+UNITY_VERSION_(MAJOR|MINOR|BUILD)[ \t]+[0-9]+"
    )

    unset(_unity_major)
    unset(_unity_minor)
    unset(_unity_patch)
    foreach(_unity_line IN LISTS _unity_version_macro_lines)
        if(_unity_line MATCHES "^#[ \t]*define[ \t]+UNITY_VERSION_MAJOR[ \t]+([0-9]+)")
            set(_unity_major "${CMAKE_MATCH_1}")
        elseif(_unity_line MATCHES "^#[ \t]*define[ \t]+UNITY_VERSION_MINOR[ \t]+([0-9]+)")
            set(_unity_minor "${CMAKE_MATCH_1}")
        elseif(_unity_line MATCHES "^#[ \t]*define[ \t]+UNITY_VERSION_BUILD[ \t]+([0-9]+)")
            set(_unity_patch "${CMAKE_MATCH_1}")
        endif()
    endforeach()

    if(DEFINED _unity_major AND DEFINED _unity_minor)
        set(Unity_VERSION_MAJOR "${_unity_major}")
        set(Unity_VERSION_MINOR "${_unity_minor}")
        set(Unity_VERSION "${Unity_VERSION_MAJOR}.${Unity_VERSION_MINOR}")
        if(DEFINED _unity_patch)
            set(Unity_VERSION_PATCH "${_unity_patch}")
            string(APPEND Unity_VERSION ".${Unity_VERSION_PATCH}")
        endif()
    else()
        file(
            STRINGS "${_unity_header}"
            _unity_version_string_line
            REGEX "^#[ \t]*define[ \t]+UNITY_VERSION[ \t]+\"[0-9]+\\.[0-9]+(\\.[0-9]+)?\""
        )
        if(_unity_version_string_line)
            list(GET _unity_version_string_line 0 _unity_version_line)
            string(
                REGEX REPLACE
                "^#[ \t]*define[ \t]+UNITY_VERSION[ \t]+\"([0-9]+\\.[0-9]+(\\.[0-9]+)?)\".*$"
                "\\1"
                Unity_VERSION
                "${_unity_version_line}"
            )
            if(Unity_VERSION MATCHES "^([0-9]+)\\.([0-9]+)(\\.([0-9]+))?")
                set(Unity_VERSION_MAJOR "${CMAKE_MATCH_1}")
                set(Unity_VERSION_MINOR "${CMAKE_MATCH_2}")
                if(CMAKE_MATCH_4)
                    set(Unity_VERSION_PATCH "${CMAKE_MATCH_4}")
                endif()
            endif()
        endif()
    endif()

    unset(_unity_header)
    unset(_unity_version_macro_lines)
    unset(_unity_version_string_line)
    unset(_unity_version_line)
    unset(_unity_major)
    unset(_unity_minor)
    unset(_unity_patch)
    unset(_unity_line)
endif()

# ----------------------------------------------------------------------------
# Create imported targets
# ----------------------------------------------------------------------------
# Unity requires both header and source
if(CMT_UNITY_INCLUDE_DIR AND CMT_UNITY_SOURCE)
    if(NOT TARGET Unity::Unity)
        add_library(unity_unity STATIC "${CMT_UNITY_SOURCE}")
        target_include_directories(unity_unity PUBLIC "${CMT_UNITY_INCLUDE_DIR}")
        # Disable linting for external dependencies
        set_target_properties(
            unity_unity
            PROPERTIES
                C_CLANG_TIDY
                    ""
                SKIP_LINTING
                    TRUE
        )
        # Create namespaced alias
        add_library(Unity::Unity ALIAS unity_unity)
    endif()
endif()

# CMock target if found
set(CMock_FOUND FALSE)
if(CMT_CMOCK_INCLUDE_DIR AND CMT_CMOCK_SOURCE)
    set(CMock_FOUND TRUE)
    if(NOT TARGET Unity::CMock)
        add_library(unity_cmock STATIC "${CMT_CMOCK_SOURCE}")
        target_include_directories(unity_cmock PUBLIC "${CMT_CMOCK_INCLUDE_DIR}")
        # CMock depends on Unity
        if(TARGET unity_unity)
            target_link_libraries(unity_cmock PUBLIC unity_unity)
        endif()
        # Disable linting for external dependencies
        set_target_properties(
            unity_cmock
            PROPERTIES
                C_CLANG_TIDY
                    ""
                SKIP_LINTING
                    TRUE
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
    REQUIRED_VARS
        CMT_UNITY_INCLUDE_DIR
        CMT_UNITY_SOURCE
    VERSION_VAR Unity_VERSION
)

mark_as_advanced(
    CMT_UNITY_INCLUDE_DIR
    CMT_UNITY_SOURCE
    Unity_RUNNER_GENERATOR
    CMT_CMOCK_INCLUDE_DIR
    CMT_CMOCK_SOURCE
    CMT_CMOCK_EXECUTABLE
)

# Backward compatibility convenience variables
set(CMT_UNITY_INCLUDE_DIRS "${CMT_UNITY_INCLUDE_DIR}" CACHE INTERNAL "Unity include dirs")
if(TARGET Unity::Unity)
    set(CMT_UNITY_LIBRARIES Unity::Unity CACHE INTERNAL "Unity libraries")
endif()

if(Unity_FOUND)
    message(STATUS "${CMAKE_CURRENT_FUNCTION}: Found Unity ${Unity_VERSION}")
    message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Include: ${CMT_UNITY_INCLUDE_DIR}")
    message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Source: ${CMT_UNITY_SOURCE}")
    if(Unity_RUNNER_GENERATOR)
        message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Runner: ${Unity_RUNNER_GENERATOR}")
    endif()
    if(CMock_FOUND)
        message(STATUS "${CMAKE_CURRENT_FUNCTION}: Found CMock")
        message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Include: ${CMT_CMOCK_INCLUDE_DIR}")
        message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Source: ${CMT_CMOCK_SOURCE}")
        if(CMT_CMOCK_EXECUTABLE)
            message(STATUS "${CMAKE_CURRENT_FUNCTION}:   Executable: ${CMT_CMOCK_EXECUTABLE}")
        endif()
    endif()
endif()
