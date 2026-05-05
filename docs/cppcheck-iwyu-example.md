# Example: Using Cppcheck and IWYU

This example demonstrates how to integrate Cppcheck and IWYU static analysis tools into a CMake project.

## Basic Usage

### Enable Cppcheck

```cmake
cmake_minimum_required(VERSION 3.22)
project(MyProject)

# Find and include the Cppcheck module
find_package(Cppcheck QUIET)
include(Cppcheck)

# Configure Cppcheck globally (advisory mode by default)
Cppcheck_Configure(
    STATUS ON
    ENABLE warning;style;performance
    SUPPRESS missingIncludeSystem
)

# Create your targets
add_library(mylib src/lib.c)
add_executable(myapp src/main.c)

# Configure Cppcheck for specific targets if needed
Cppcheck_ConfigureTarget(
    TARGET mylib
    STATUS ON
    ENABLE warning;style
)
```

### Enable IWYU

```cmake
# Find and include the IWYU module
find_package(IWYU QUIET)
include(IWYU)

# Configure IWYU globally (C++ only, advisory mode by default)
IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
)

# For C++ targets
add_executable(myapp_cpp src/main.cpp)

IWYU_ConfigureTarget(
    TARGET myapp_cpp
    STATUS ON
    ADDITIONAL_ARGS "--no_fwd_decls" "--keep_going"
)
```

## Strict Mode for CI

Use strict mode in CI pipelines to ensure tools are installed:

```cmake
if(CI_BUILD OR CMAKE_SYSTEM_NAME MATCHES "Linux")
    Cppcheck_Configure(
        STATUS ON
        STRICT  # Fail if cppcheck not found
        ENABLE warning;style;performance
    )
    
    IWYU_Configure(
        STATUS ON
        STRICT  # Fail if IWYU not found
    )
endif()
```

## Integration with Examples

The main `examples/CMakeLists.txt` includes both modules and demonstrates:
- Global configuration
- Per-target configuration
- Advisory mode (graceful degradation without tools)
- Parameter handling (ENABLE, SUPPRESS, MAPPING_FILE, etc.)

## Running

```bash
# Configure with Cppcheck and IWYU (if installed)
cmake -S . -B build

# Build project
cmake --build build

# Run CI with strict mode (fails if tools not installed)
cmake -S . -B build-ci -DMY_CI_BUILD=ON
```

## Requirements

- CMake 3.15+ for Cppcheck support
- CMake 3.15+ for IWYU support
- cppcheck executable (optional; advisory mode works without it)
- include-what-you-use executable (optional; advisory mode works without it)

## See Also

- `/docs/cppcheck.md` - Comprehensive Cppcheck documentation
- `/docs/iwyu.md` - Comprehensive IWYU documentation
- `/unit_tests/cppcheck/` - Test examples
- `/unit_tests/iwyu/` - Test examples
