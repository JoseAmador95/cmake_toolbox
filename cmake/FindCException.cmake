# SPDX-License-Identifier: MIT
# ============================================================================
# FindCException
# ============================================================================
#
# CMake find module for the CException C exception-handling library.
#
# This module locates existing CException source distributions and provides
# an imported target for convenient linking. Can also fetch via FetchContent.
#
# Usage:
#   find_package(CException REQUIRED)   # Basic usage
#   find_package(CException QUIET)      # Suppress status output
#
# User Cache / Environment Hints:
#   - CException_ROOT / CEXCEPTION_ROOT (cache or normal variable)
#   - ENV{CEXCEPTION_ROOT}
#   - CEXCEPTION_FETCH (BOOL, OFF by default)  If ON and CException not found,
#       the repository will be fetched via FetchContent.
#   - CMT_CEXCEPTION_GIT_REPOSITORY (override CException repo URL)
#   - CMT_CEXCEPTION_GIT_TAG (override CException tag)
#
# Result Variables:
#   CException_FOUND        - TRUE if CException located (or fetched)
#   CException_INCLUDE_DIR  - Directory containing CException.h
#   CException_SOURCE       - Path to CException.c (required)
#   CException_VERSION      - Parsed version string if detected
#
# Imported Targets:
#   CException::CException  - Static library target (compiles CException.c)
#
# Notes:
#   - Both CException.h AND CException.c are required (no header-only mode)
#   - CExceptionConfig.h lives in the same directory as CException.h and is
#     automatically available through the target's include directories
#
# ============================================================================

include_guard(GLOBAL)

# ----------------------------------------------------------------------------
# Handle user overrides / hints
# ----------------------------------------------------------------------------
set(_CException_HINT_DIRS)
foreach(var IN ITEMS CException_ROOT CEXCEPTION_ROOT)
    if(DEFINED ${var})
        list(APPEND _CException_HINT_DIRS "${${var}}")
    endif()
endforeach()
if(DEFINED ENV{CEXCEPTION_ROOT})
    list(APPEND _CException_HINT_DIRS "$ENV{CEXCEPTION_ROOT}")
endif()

# Common relative subdirs to search inside each hint root
set(_CException_SUBDIRS
    ""
    "src"
    "lib"
    "source"
    "CException"
    "CException/src"
    "CException/lib"
)

# ----------------------------------------------------------------------------
# Locate CException.h
# ----------------------------------------------------------------------------
unset(CException_INCLUDE_DIR CACHE)
find_path(
    CException_INCLUDE_DIR
    NAMES
        CException.h
    HINTS
        ${_CException_HINT_DIRS}
    PATH_SUFFIXES
        ${_CException_SUBDIRS}
)

# ----------------------------------------------------------------------------
# Locate CException.c (required)
# ----------------------------------------------------------------------------
unset(CException_SOURCE CACHE)
find_file(
    CException_SOURCE
    NAMES
        CException.c
    HINTS
        ${CException_INCLUDE_DIR}
        ${_CException_HINT_DIRS}
    PATH_SUFFIXES
        .
        src
        lib
        source
        CException
        CException/src
        CException/lib
)

# ----------------------------------------------------------------------------
# Optional: Fetch if not found and user requested CEXCEPTION_FETCH
# ----------------------------------------------------------------------------
if((NOT CException_INCLUDE_DIR OR NOT CException_SOURCE) AND CEXCEPTION_FETCH)
    set(_cexception_repo "https://github.com/ThrowTheSwitch/CException.git")
    if(CMT_CEXCEPTION_GIT_REPOSITORY)
        set(_cexception_repo "${CMT_CEXCEPTION_GIT_REPOSITORY}")
    endif()
    set(_cexception_tag "v1.3.3")
    if(CMT_CEXCEPTION_GIT_TAG)
        set(_cexception_tag "${CMT_CEXCEPTION_GIT_TAG}")
    endif()

    include(FetchContent)

    FetchContent_Declare(
        cexception_repo
        GIT_REPOSITORY "${_cexception_repo}"
        GIT_TAG "${_cexception_tag}"
    )
    FetchContent_MakeAvailable(cexception_repo)

    if(cexception_repo_SOURCE_DIR AND EXISTS "${cexception_repo_SOURCE_DIR}/lib/CException.c")
        set(CException_INCLUDE_DIR "${cexception_repo_SOURCE_DIR}/lib")
        set(CException_SOURCE "${cexception_repo_SOURCE_DIR}/lib/CException.c")
    endif()
endif()

# ----------------------------------------------------------------------------
# Parse version from CException.h macros (cross-compile safe)
# ----------------------------------------------------------------------------
unset(CException_VERSION)
if(CException_INCLUDE_DIR AND EXISTS "${CException_INCLUDE_DIR}/CException.h")
    set(_cexception_header "${CException_INCLUDE_DIR}/CException.h")
    file(
        STRINGS "${_cexception_header}"
        _cexception_version_lines
        REGEX "^#[ \t]*define[ \t]+CEXCEPTION_VERSION_(MAJOR|MINOR|BUILD)[ \t]+[0-9]+"
    )

    unset(_cexception_major)
    unset(_cexception_minor)
    unset(_cexception_patch)
    foreach(_cexception_line IN LISTS _cexception_version_lines)
        if(_cexception_line MATCHES "^#[ \t]*define[ \t]+CEXCEPTION_VERSION_MAJOR[ \t]+([0-9]+)")
            set(_cexception_major "${CMAKE_MATCH_1}")
        elseif(
            _cexception_line
                MATCHES
                "^#[ \t]*define[ \t]+CEXCEPTION_VERSION_MINOR[ \t]+([0-9]+)"
        )
            set(_cexception_minor "${CMAKE_MATCH_1}")
        elseif(
            _cexception_line
                MATCHES
                "^#[ \t]*define[ \t]+CEXCEPTION_VERSION_BUILD[ \t]+([0-9]+)"
        )
            set(_cexception_patch "${CMAKE_MATCH_1}")
        endif()
    endforeach()

    if(DEFINED _cexception_major AND DEFINED _cexception_minor)
        set(CException_VERSION "${_cexception_major}.${_cexception_minor}")
        if(DEFINED _cexception_patch)
            string(APPEND CException_VERSION ".${_cexception_patch}")
        endif()
    endif()

    unset(_cexception_header)
    unset(_cexception_version_lines)
    unset(_cexception_line)
    unset(_cexception_major)
    unset(_cexception_minor)
    unset(_cexception_patch)
endif()

# ----------------------------------------------------------------------------
# Create imported target
# ----------------------------------------------------------------------------
if(CException_INCLUDE_DIR AND CException_SOURCE)
    if(NOT TARGET CException::CException)
        add_library(cexception_cexception STATIC "${CException_SOURCE}")
        target_include_directories(cexception_cexception PUBLIC "${CException_INCLUDE_DIR}")
        # Disable linting for external dependencies
        set_target_properties(
            cexception_cexception
            PROPERTIES
                C_CLANG_TIDY
                    ""
                SKIP_LINTING
                    TRUE
        )
        # Create namespaced alias
        add_library(CException::CException ALIAS cexception_cexception)
    endif()
endif()

# ----------------------------------------------------------------------------
# Set required standard find_package variables
# ----------------------------------------------------------------------------
include(FindPackageHandleStandardArgs)
find_package_handle_standard_args(
    CException
    REQUIRED_VARS
        CException_INCLUDE_DIR
        CException_SOURCE
    VERSION_VAR CException_VERSION
)

mark_as_advanced(
    CException_INCLUDE_DIR
    CException_SOURCE
)

if(CException_FOUND AND NOT CException_FIND_QUIETLY)
    message(STATUS "FindCException: Found CException ${CException_VERSION}")
    message(STATUS "FindCException:   Include: ${CException_INCLUDE_DIR}")
    message(STATUS "FindCException:   Source:  ${CException_SOURCE}")
endif()
