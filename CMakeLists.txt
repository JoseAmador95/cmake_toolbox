cmake_minimum_required(VERSION 3.22)

project(cmake_toolbox VERSION 0.1)

include(GNUInstallDirs)
include(CMakePackageConfigHelpers)

option(
    CMAKE_TOOLBOX_BUILD_EXAMPLES
    "Build examples and tests from examples/"
    ${PROJECT_IS_TOP_LEVEL}
)

list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/cmake)

if(CMAKE_TOOLBOX_BUILD_EXAMPLES)
    enable_testing()
    add_subdirectory(examples)
endif()

set(CMAKE_TOOLBOX_INSTALL_CMAKEDIR "${CMAKE_INSTALL_LIBDIR}/cmake/cmake_toolbox")

install(
    DIRECTORY
        ${CMAKE_CURRENT_LIST_DIR}/cmake/
    DESTINATION ${CMAKE_TOOLBOX_INSTALL_CMAKEDIR}
    FILES_MATCHING
    PATTERN "*.cmake"
)

install(
    FILES
        ${CMAKE_CURRENT_LIST_DIR}/cmock.yml
    DESTINATION ${CMAKE_TOOLBOX_INSTALL_CMAKEDIR}
)

configure_package_config_file(
    ${CMAKE_CURRENT_LIST_DIR}/cmake/cmake_toolboxConfig.cmake.in
    ${CMAKE_CURRENT_BINARY_DIR}/cmake_toolboxConfig.cmake
    INSTALL_DESTINATION ${CMAKE_TOOLBOX_INSTALL_CMAKEDIR}
)

write_basic_package_version_file(
    ${CMAKE_CURRENT_BINARY_DIR}/cmake_toolboxConfigVersion.cmake
    VERSION ${PROJECT_VERSION}
    COMPATIBILITY SameMajorVersion
)

install(
    FILES
        ${CMAKE_CURRENT_BINARY_DIR}/cmake_toolboxConfig.cmake
        ${CMAKE_CURRENT_BINARY_DIR}/cmake_toolboxConfigVersion.cmake
    DESTINATION ${CMAKE_TOOLBOX_INSTALL_CMAKEDIR}
)
