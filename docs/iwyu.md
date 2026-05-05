# Include-What-You-Use (IWYU) CMake Module

This module integrates `include-what-you-use` (IWYU) into your CMake project for analyzing and optimizing C++ include directives.

IWYU is a tool that analyzes C++ code to identify unnecessary `#include` directives and suggest missing headers. It helps keep include dependencies clean and reduces compilation time by removing unused includes. **Note**: IWYU is C++-only and does not analyze C files.

## API Overview

Use the current API:

```cmake
find_package(IWYU QUIET)
include(IWYU)

IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--no_fwd_decls;--keep_going"
)

# Or per-target configuration
IWYU_ConfigureTarget(
    TARGET mylib
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
)
```

This module follows the same pattern as ClangTidy.cmake for consistency across the cmake_toolbox.

## Requirements

- CMake `3.15+`
- CMake module path includes this repository's `cmake/` directory
- `find_package(IWYU ...)` called before `include(IWYU)`
- `include-what-you-use` executable available in system PATH or CMake module path
- **C++ only**: this module only sets `CMAKE_CXX_INCLUDE_WHAT_YOU_USE` (never `CMAKE_C_INCLUDE_WHAT_YOU_USE`)

If `include-what-you-use` is not found:
- **Advisory mode (default)**: a message is issued (VERBOSE level) and processing continues
- **Strict mode**: a FATAL_ERROR is raised (when STRICT flag is specified)

## Function Reference

### IWYU_Configure()

Configure IWYU globally for all C++ targets.

```cmake
IWYU_Configure(
    STATUS <boolean>
    [STRICT]
    [MAPPING_FILE <path>]
    [ADDITIONAL_ARGS <arg1> [<arg2> ...]]
    [EXCLUDE_PATTERNS <pattern1> [<pattern2> ...]]
)
```

Parameters:

- `STATUS` (required): Enable or disable IWYU globally. Accepts `ON`, `OFF`, `TRUE`, `FALSE`, `1`, `0`
- `STRICT` (optional): If specified, raises a fatal error if IWYU is not found. Without this flag, a verbose message is issued
- `MAPPING_FILE` (optional): Path to an IWYU mapping file (`.imp` format). The file path is passed to IWYU as `-Xiwyu --mapping_file=<path>`. If STRICT mode is enabled and the file does not exist, an error is raised
- `ADDITIONAL_ARGS` (optional): List of IWYU-specific arguments (e.g., `--no_fwd_decls`, `--keep_going`). Each argument is automatically prefixed with `-Xiwyu`
- `EXCLUDE_PATTERNS` (optional): List of path patterns to exclude (reserved for future use or target-level filtering)

When `STATUS` is ON and IWYU is found:
- Sets `CMAKE_CXX_INCLUDE_WHAT_YOU_USE` to the IWYU command with configured options
- Analysis runs during compilation for all C++ targets

When `STATUS` is OFF or IWYU is not found:
- Clears `CMAKE_CXX_INCLUDE_WHAT_YOU_USE`
- No IWYU analysis occurs

### IWYU_ConfigureTarget()

Configure IWYU for a specific C++ target.

```cmake
IWYU_ConfigureTarget(
    TARGET <target>
    STATUS <boolean>
    [STRICT]
    [MAPPING_FILE <path>]
    [ADDITIONAL_ARGS <arg1> [<arg2> ...]]
    [EXCLUDE_PATTERNS <pattern1> [<pattern2> ...]]
)
```

Parameters:

- `TARGET` (required): The CMake target to configure IWYU for. Target must exist and be a C++ target; missing targets always cause a configuration error
- `STATUS` (required): Enable or disable IWYU for this target. Accepts `ON`, `OFF`, `TRUE`, `FALSE`, `1`, `0`
- `STRICT` (optional): If specified, raises a fatal error if IWYU is not found. Without this flag, a verbose message is issued for missing tools
- `MAPPING_FILE` (optional): Path to an IWYU mapping file
- `ADDITIONAL_ARGS` (optional): List of IWYU-specific arguments
- `EXCLUDE_PATTERNS` (optional): List of path patterns to exclude

When `STATUS` is ON and IWYU is found:
- Sets target property `CXX_INCLUDE_WHAT_YOU_USE` to the IWYU command
- Analysis runs when this C++ target is compiled

When `STATUS` is OFF or IWYU is not found:
- Clears `CXX_INCLUDE_WHAT_YOU_USE` property
- No analysis runs for the target

## Minimal Working Example

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.15)
project(Example LANGUAGES CXX)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(IWYU QUIET)
include(IWYU)

# Create a library
add_library(mylib src/lib.cpp)

# Enable IWYU globally
IWYU_Configure(
    STATUS ON
)
```

Build and run:

```bash
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
```

IWYU will run automatically during compilation, reporting unused and missing includes.

## Complete Example

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.15)
project(MyProject LANGUAGES CXX)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

find_package(IWYU QUIET)
include(IWYU)

# Configure IWYU globally with mapping file and custom arguments
IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu_mapping.imp
    ADDITIONAL_ARGS "--no_fwd_decls;--keep_going"
)

# Create libraries
add_library(core src/core.cpp)
add_library(utils src/utils.cpp)
add_executable(app src/main.cpp)

target_link_libraries(app core utils)

# Override for a specific target with different settings
IWYU_ConfigureTarget(
    TARGET core
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu_mapping.imp
    ADDITIONAL_ARGS "--keep_going"
)

# Disable IWYU for utils target
IWYU_ConfigureTarget(
    TARGET utils
    STATUS OFF
)
```

Example `iwyu_mapping.imp` file:

```
[
  { include: ["<sys/types.h>", "private", "<sys/stat.h>", "public"] },
  { include: ["<vector>", "private", "<vector>", "public"] },
  { symbol: ["std::vector", "private", "<vector>", "public"] }
]
```

Output during compilation (if issues found):

```
src/lib.cpp:1:10: warning: #include <iostream> not used [iwyu]
src/lib.cpp:5:5: warning: 'std::vector' is declared in header
         '<vector>' and has associated headers '<bits/stdc++.h>', ...
src/lib.cpp:15:8: note: used at line 15, column 8
```

## Advisory vs Strict Mode

### Advisory Mode (Default)

When the `STRICT` flag is not specified:
- If IWYU is not found, a verbose message is issued and configuration continues
- Useful for development environments where IWYU may not be installed
- Suitable for optional analysis in CI/CD pipelines with fallback behavior

Example:

```cmake
# Advisory mode - continues even if IWYU not found
IWYU_Configure(
    STATUS ON
)
```

Output if IWYU not found:

```
-- IWYU not found
```

Build continues normally without IWYU analysis.

### Strict Mode

When the `STRICT` flag is specified:
- If IWYU is not found, a FATAL_ERROR is raised
- Ensures analysis is guaranteed in CI/CD pipelines
- Fails fast if the tool is missing

Example:

```cmake
# Strict mode - fails if IWYU not found
IWYU_Configure(
    STATUS ON
    STRICT
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
)
```

Output if IWYU not found:

```
CMake Error at cmake/IWYU.cmake:...:
  IWYU_Configure: IWYU not found and STRICT mode enabled
```

Build stops immediately.

## Mapping Files

IWYU mapping files customize symbol-to-header mappings using `.imp` (implementation mapping) format. They allow you to:

- Map non-standard symbols to canonical headers
- Redirect includes through preferred headers
- Handle platform-specific variations

### Where to Get Mapping Files

The official IWYU repository provides mapping files:

- [IWYU Mappings Documentation](https://github.com/include-what-you-use/include-what-you-use/blob/master/docs/IWYUMappings.md)
- [IWYU Mapping Files](https://github.com/include-what-you-use/include-what-you-use/tree/master/mappings)

Common mappings:

- `boost-all.imp`: Boost library mappings
- `stl-all.imp`: C++ standard library mappings
- `qt5-all.imp`: Qt5 mappings

### Mapping File Format (.imp)

Basic structure:

```
[
  # Include mapping
  { include: [<include>, "private"|"public", <replacement>, "private"|"public"] },
  
  # Symbol mapping
  { symbol: [<symbol>, "private"|"public", <header>, "private"|"public"] },
  
  # Fwd declaration mapping
  { forward_decl: [<symbol>, "private"|"public", <header>, "private"|"public"] }
]
```

Example mapping file:

```
[
  # Map sys/types.h to sys/stat.h
  { include: ["<sys/types.h>", "private", "<sys/stat.h>", "public"] },
  
  # Map symbols to standard headers
  { symbol: ["std::vector", "private", "<vector>", "public"] },
  { symbol: ["std::string", "private", "<string>", "public"] },
  { symbol: ["std::map", "private", "<map>", "public"] },
  
  # Forward declaration mappings
  { forward_decl: ["std::vector", "private", "<vector>", "public"] }
]
```

### Using Mapping Files

```cmake
IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu_mapping.imp
)
```

If the mapping file doesn't exist:

- **Advisory mode**: omits mapping file flag, analysis continues
- **Strict mode**: FATAL_ERROR is raised

Verify mapping file path:

```cmake
if(NOT EXISTS "${CMAKE_SOURCE_DIR}/iwyu_mapping.imp")
    message(WARNING "IWYU mapping file not found")
endif()

IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu_mapping.imp
)
```

## Common IWYU Arguments

IWYU-specific arguments are passed using the `ADDITIONAL_ARGS` parameter. Each argument is automatically prefixed with `-Xiwyu`.

### Common Arguments

- `--no_fwd_decls`: Report all forward declarations as needed (even if not required)
- `--keep_going`: Continue analysis after first error
- `--check_also=<pattern>`: Check additional files matching pattern
- `--mapping_file=<path>`: Specify mapping file (also available via `MAPPING_FILE` parameter)
- `--verbose`: Increase verbosity

### Examples

#### No Forward Declarations

```cmake
IWYU_Configure(
    STATUS ON
    ADDITIONAL_ARGS "--no_fwd_decls"
)
```

#### Keep Going Through Errors

```cmake
IWYU_Configure(
    STATUS ON
    ADDITIONAL_ARGS "--keep_going"
)
```

#### Multiple Arguments

```cmake
IWYU_Configure(
    STATUS ON
    ADDITIONAL_ARGS "--no_fwd_decls;--keep_going;--verbose"
)
```

#### Check Additional Files

```cmake
IWYU_Configure(
    STATUS ON
    ADDITIONAL_ARGS "--check_also=*_impl.cpp"
)
```

### Full Command Generation

The module builds the final IWYU command automatically. For example:

```cmake
IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--no_fwd_decls;--keep_going"
)
```

Generates the command:

```
include-what-you-use -Xiwyu --mapping_file=/path/to/iwyu.imp -Xiwyu --no_fwd_decls -Xiwyu --keep_going
```

## Excluding Patterns

Use `EXCLUDE_PATTERNS` to skip analysis of files matching certain patterns:

```cmake
IWYU_Configure(
    STATUS ON
    EXCLUDE_PATTERNS
        "*/third_party/*"
        "*/generated/*"
        "*_autogen.*"
)
```

Useful patterns:

- `*/third_party/*`: exclude third-party dependencies
- `*/generated/*`: exclude auto-generated code
- `*_autogen.*`: exclude Qt/CMake generated files
- `*/test/*`: exclude test code (optional)
- `^build/.*`: exclude build artifacts

**Note**: Exclude patterns are reserved for future use in target-level filtering. Currently, they may not affect global configuration.

## Per-Target Configuration

Configure IWYU differently for different targets:

```cmake
add_library(core src/core.cpp src/utils.cpp)
add_library(legacy src/legacy.cpp)
add_executable(app src/main.cpp)

# Strict checking for core library
IWYU_ConfigureTarget(
    TARGET core
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--keep_going"
)

# Lenient checking for legacy code
IWYU_ConfigureTarget(
    TARGET legacy
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--no_fwd_decls;--keep_going"
)

# Disable for executable
IWYU_ConfigureTarget(
    TARGET app
    STATUS OFF
)
```

### Override Global Configuration

Global settings are overridden by target-specific settings:

```cmake
# Global: standard checking
IWYU_Configure(
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
)

# Target: override with different arguments
IWYU_ConfigureTarget(
    TARGET special_lib
    STATUS ON
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--no_fwd_decls"
)

# Target: disable analysis
IWYU_ConfigureTarget(
    TARGET excluded_lib
    STATUS OFF
)
```

## CI Integration

### GitHub Actions Example

`.github/workflows/iwyu.yml`:

```yaml
name: IWYU Analysis

on: [push, pull_request]

jobs:
  iwyu:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive

      - name: Install IWYU
        run: |
          sudo apt-get update
          sudo apt-get install -y include-what-you-use

      - name: Configure CMake
        run: cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

      - name: Build with IWYU
        run: cmake --build build 2>&1 | tee iwyu-results.txt

      - name: Archive IWYU results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: iwyu-results
          path: iwyu-results.txt
```

### Strict CI Mode

For strict CI environments where analysis must succeed:

`CMakeLists.txt`:

```cmake
# Enable strict mode for CI, advisory for development
if(DEFINED ENV{CI})
    set(IWYU_STRICT STRICT)
endif()

find_package(IWYU QUIET)
include(IWYU)

IWYU_Configure(
    STATUS ON
    ${IWYU_STRICT}
    MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu.imp
    ADDITIONAL_ARGS "--keep_going"
)
```

Run locally with advisory mode, in CI with strict mode:

```bash
# Local development (advisory)
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build

# CI pipeline (strict)
export CI=1
cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
cmake --build build
```

## Troubleshooting

### "IWYU not found"

**Problem**: Build fails or continues with verbose message about IWYU not found.

**Solution**:

1. Install include-what-you-use:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install include-what-you-use

   # macOS
   brew install include-what-you-use

   # Fedora/RHEL
   sudo dnf install include-what-you-use
   ```

2. Verify IWYU is in PATH:
   ```bash
   which include-what-you-use
   include-what-you-use --version
   ```

3. If not in PATH, set cmake module path or use `-DCMAKE_PREFIX_PATH`:
   ```bash
   cmake -S . -B build -DCMAKE_PREFIX_PATH=/usr/local/opt/include-what-you-use
   ```

4. Switch from strict to advisory mode during development:
   ```cmake
   # Remove STRICT flag for optional analysis
   IWYU_Configure(
       STATUS ON
   )
   ```

### Mapping file not found

**Problem**: CMake fails because mapping file doesn't exist or path is incorrect.

**Solution**:

1. Verify file exists:
   ```bash
   ls -la ${CMAKE_SOURCE_DIR}/iwyu_mapping.imp
   ```

2. Use absolute path:
   ```cmake
   IWYU_Configure(
       STATUS ON
       MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu_mapping.imp
   )
   ```

3. Use advisory mode:
   ```cmake
   # Advisory: continues if file missing
   IWYU_Configure(
       STATUS ON
       MAPPING_FILE ${CMAKE_SOURCE_DIR}/iwyu_mapping.imp
   )
   ```

4. Check file exists before configuring:
   ```cmake
   if(EXISTS "${CMAKE_SOURCE_DIR}/iwyu_mapping.imp")
       set(IWYU_MAPPING_FILE "${CMAKE_SOURCE_DIR}/iwyu_mapping.imp")
   else()
       message(WARNING "IWYU mapping file not found, using without mapping")
   endif()

   IWYU_Configure(
       STATUS ON
       MAPPING_FILE "${IWYU_MAPPING_FILE}"
   )
   ```

### Tool version compatibility

**Problem**: IWYU version on system incompatible with project expectations.

**Solution**:

1. Check IWYU version:
   ```bash
   include-what-you-use --version
   ```

2. Install specific version (if package manager supports it):
   ```bash
   # Ubuntu
   apt-cache policy include-what-you-use
   sudo apt-get install include-what-you-use=<version>
   ```

3. Build from source if needed:
   ```bash
   git clone https://github.com/include-what-you-use/include-what-you-use.git
   cd include-what-you-use
   mkdir build && cd build
   cmake -DCMAKE_BUILD_TYPE=Release ..
   make
   sudo make install
   ```

4. Disable IWYU if version incompatible:
   ```cmake
   IWYU_Configure(STATUS OFF)
   ```

### "Target does not exist"

**Problem**: `IWYU_ConfigureTarget` fails because target doesn't exist.

**Solution**:

1. Ensure target is created before configuration:
   ```cmake
   add_library(mylib src/lib.cpp)
   
   # Configure AFTER target creation
   IWYU_ConfigureTarget(
       TARGET mylib
       STATUS ON
   )
   ```

2. Target existence ALWAYS fails with FATAL_ERROR:
   ```cmake
   # Target existence is a CMakeLists.txt usage error, always fatal
   IWYU_ConfigureTarget(
       TARGET possibly_missing
       STATUS ON
   )
   ```

3. Check target exists before configuring:
   ```cmake
   if(TARGET mylib)
       IWYU_ConfigureTarget(
           TARGET mylib
           STATUS ON
       )
   endif()
   ```

### compile_commands.json missing

**Problem**: IWYU needs compile_commands.json but it's not generated.

**Solution**:

1. Enable compile commands generation:
   ```bash
   cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON
   ```

2. Or set in CMakeLists.txt:
   ```cmake
   set(CMAKE_EXPORT_COMPILE_COMMANDS ON)
   ```

3. Verify compile_commands.json is created:
   ```bash
   ls -la build/compile_commands.json
   ```

## See Also

- [Official IWYU Documentation](https://include-what-you-use.org/)
- [IWYU GitHub Repository](https://github.com/include-what-you-use/include-what-you-use)
- [IWYU Mapping Files](https://github.com/include-what-you-use/include-what-you-use/tree/master/mappings)
- [IWYU Design Documentation](https://github.com/include-what-you-use/include-what-you-use/blob/master/docs)
- [Cppcheck CMake Module](./cppcheck.md) - C/C++ static analysis
- [CMake CXX_INCLUDE_WHAT_YOU_USE Property](https://cmake.org/cmake/help/latest/prop_tgt/CXX_INCLUDE_WHAT_YOU_USE.html)
