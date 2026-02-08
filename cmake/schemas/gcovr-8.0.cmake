# SPDX-License-Identifier: MIT
# ==============================================================================
# Gcovr 8.0 Schema and Configuration Generator
# ==============================================================================
#
# gcovr 8.x keeps compatibility with the configuration keys emitted by our 7.0
# schema for the options currently managed by cmake_toolbox. Reuse the 7.0
# schema implementation while exposing an explicit 8.0 schema entry point.
#
# ==============================================================================

include("${CMAKE_CURRENT_LIST_DIR}/gcovr-7.0.cmake")

function(GcovrSchema_8_0_GenerateConfig CONFIG_FILE)
    GcovrSchema_7_0_GenerateConfig("${CONFIG_FILE}")
endfunction()
