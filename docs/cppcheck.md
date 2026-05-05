# Cppcheck CMake Module

This module integrates `cppcheck` static analysis into your CMake project by configuring compile-time analysis for C and C++ targets.

Cppcheck is a lightweight static analysis tool that detects various code defects, suspicious constructs, and potential bugs. It complements other tools like ClangTidy by providing fast, practical analysis without requiring full compilation.

## API Overview

Use the current API:

```cmake
find_package(Cppcheck QUIET)
include(Cppcheck)

Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance
    SUPPRESS missingIncludeSystem
)

# Or per-target configuration
Cppcheck_ConfigureTarget(
    TARGET mylib
    STATUS ON
    ENABLE warning style
)
```

This module follows the same pattern as ClangTidy.cmake for consistency across the cmake_toolbox.

## Requirements

- CMake `3.15+`
- CMake module path includes this repository's `cmake/` directory
- `find_package(Cppcheck ...)` called before `include(Cppcheck)`
- `cppcheck` executable available in system PATH or CMake module path

If `cppcheck` is not found:
- **Advisory mode (default)**: a message is issued (VERBOSE level) and processing continues
- **Strict mode**: a FATAL_ERROR is raised (when STRICT flag is specified)

## Function Reference

### Cppcheck_Configure()

Configure cppcheck globally for all C and C++ targets.

```cmake
Cppcheck_Configure(
    STATUS <boolean>
    [STRICT]
    [ENABLE <check1> [<check2> ...]]
    [SUPPRESS <check1> [<check2> ...]]
    [EXCLUDE_PATTERNS <pattern1> [<pattern2> ...]]
)
```

Parameters:

- `STATUS` (required): Enable or disable cppcheck globally. Accepts ON, OFF, TRUE, FALSE, 1, 0
- `STRICT` (optional): If specified, raises a fatal error if cppcheck is not found. Without this flag, a verbose message is issued
- `ENABLE` (optional): List of check severities to enable. These are joined with commas into the `--enable` flag
- `SUPPRESS` (optional): List of individual checks to suppress. These are joined with commas into the `--suppress` flag
- `EXCLUDE_PATTERNS` (optional): List of path patterns to exclude from analysis. Each is passed as a separate `--exclude` flag

When `STATUS` is ON and cppcheck is found:
- Sets `CMAKE_C_CPPCHECK` and `CMAKE_CXX_CPPCHECK` to the cppcheck command with configured options
- Analysis runs during the build for all applicable targets

When `STATUS` is OFF or cppcheck is not found:
- Clears `CMAKE_C_CPPCHECK` and `CMAKE_CXX_CPPCHECK`
- No cppcheck analysis occurs

### Cppcheck_ConfigureTarget()

Configure cppcheck for a specific C or C++ target.

```cmake
Cppcheck_ConfigureTarget(
    TARGET <target>
    STATUS <boolean>
    [STRICT]
    [ENABLE <check1> [<check2> ...]]
    [SUPPRESS <check1> [<check2> ...]]
    [EXCLUDE_PATTERNS <pattern1> [<pattern2> ...]]
)
```

Parameters:

- `TARGET` (required): The CMake target to configure cppcheck for (target must exist)
- `STATUS` (required): Enable or disable cppcheck for this target. Accepts ON, OFF, TRUE, FALSE, 1, 0
- `STRICT` (optional): If specified, raises a fatal error if cppcheck is not found or target does not exist. Without this flag, a verbose message is issued for missing tools
- `ENABLE` (optional): List of check severities to enable
- `SUPPRESS` (optional): List of individual checks to suppress
- `EXCLUDE_PATTERNS` (optional): List of path patterns to exclude

When `STATUS` is ON and cppcheck is found:
- Sets target properties `C_CPPCHECK` and `CXX_CPPCHECK` to the cppcheck command
- Analysis runs when this target is built

When `STATUS` is OFF or cppcheck is not found:
- Clears `C_CPPCHECK` and `CXX_CPPCHECK` properties
- No analysis runs for the target

## Minimal Working Example

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.15)
project(Example LANGUAGES C CXX)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(Cppcheck QUIET)
include(Cppcheck)

# Create a library
add_library(mylib src/lib.cpp)

# Enable cppcheck globally
Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance
)
```

Build and run:

```bash
cmake -S . -B build
cmake --build build
```

Cppcheck will run automatically during the build, reporting any issues to stdout.

## Complete Example

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.15)
project(MyProject LANGUAGES C CXX)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(Cppcheck QUIET)
include(Cppcheck)

# Configure cppcheck globally with strict checking
Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance portability
    SUPPRESS missingIncludeSystem unusedVariable
    EXCLUDE_PATTERNS "*/third_party/*" "*/generated/*" "*_autogen.*"
)

# Create libraries
add_library(core src/core.cpp)
add_library(utils src/utils.cpp)
add_executable(app src/main.cpp)

target_link_libraries(app core utils)

# Override for a specific target with stricter checks
Cppcheck_ConfigureTarget(
    TARGET core
    STATUS ON
    ENABLE warning style performance portability information
    SUPPRESS missingIncludeSystem
)

# Disable cppcheck for utils target (e.g., if it uses external code)
Cppcheck_ConfigureTarget(
    TARGET utils
    STATUS OFF
)
```

Output during build (if issues found):

```
[100%] Building CXX object CMakeFiles/core.dir/src/core.cpp.o
cppcheck: style: Variable 'x' is assigned a value that is never used. [unusedVariable]
cppcheck: performance: Function parameter 'data' should be passed by const reference. [passedByValue]
```

## Advisory vs Strict Mode

### Advisory Mode (Default)

When the `STRICT` flag is not specified:
- If cppcheck is not found, a verbose message is issued and configuration continues
- Useful for development environments where cppcheck may not be installed
- Suitable for optional analysis in CI/CD pipelines with fallback behavior

Example:

```cmake
# Advisory mode - continues even if cppcheck not found
Cppcheck_Configure(
    STATUS ON
    ENABLE warning style
)
```

Output if cppcheck not found:

```
-- Cppcheck not found
```

Build continues normally without cppcheck analysis.

### Strict Mode

When the `STRICT` flag is specified:
- If cppcheck is not found, a FATAL_ERROR is raised
- Ensures analysis is guaranteed in CI/CD pipelines
- Fails fast if the tool is missing

Example:

```cmake
# Strict mode - fails if cppcheck not found
Cppcheck_Configure(
    STATUS ON
    STRICT
    ENABLE warning style performance
)
```

Output if cppcheck not found:

```
CMake Error at cmake/Cppcheck.cmake:...:
  Cppcheck_Configure: Cppcheck not found
```

Build stops immediately.

## Check Categories

Cppcheck organizes checks into severity levels and categories. Common values for `ENABLE`:

- `warning`: suspicious code that may be incorrect (high priority)
- `style`: code style issues and suspicious patterns (medium priority)
- `performance`: code that could be optimized (medium priority)
- `portability`: code that may not be portable across platforms (lower priority)
- `information`: informational messages (lowest priority)

Enable multiple categories:

```cmake
Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance portability information
)
```

Or enable a single category:

```cmake
Cppcheck_Configure(
    STATUS ON
    ENABLE warning
)
```

Typical usage patterns:

- **Minimal**: Just `warning` for critical issues only
- **Standard**: `warning style performance` (recommended)
- **Comprehensive**: `warning style performance portability information`

## Suppressions

### Suppress Individual Checks

Use `SUPPRESS` to disable specific checks that produce false positives or are not applicable:

```cmake
Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance
    SUPPRESS missingIncludeSystem unusedVariable
)
```

Common checks to suppress:

- `missingIncludeSystem`: missing system headers (often false positives)
- `unusedVariable`: unused local variables (may be intentional)
- `constParameter`: parameter could be const (code style preference)
- `constVariable`: variable could be const (code style preference)

### Per-Target Suppressions

Suppress checks for specific targets:

```cmake
add_library(legacy_code src/legacy.cpp)

Cppcheck_ConfigureTarget(
    TARGET legacy_code
    STATUS ON
    ENABLE warning style
    SUPPRESS unusedVariable missingIncludeSystem
)
```

### Suppress Globally and Override

Set global suppressions and override for specific targets:

```cmake
# Global: suppress common false positives
Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance
    SUPPRESS missingIncludeSystem
)

# Target: stricter, no suppressions
Cppcheck_ConfigureTarget(
    TARGET critical_lib
    STATUS ON
    ENABLE warning style performance
    SUPPRESS missingIncludeSystem
)

# Target: more lenient
Cppcheck_ConfigureTarget(
    TARGET util_lib
    STATUS ON
    ENABLE warning
    SUPPRESS missingIncludeSystem unusedVariable
)
```

## Excluding Patterns

Use `EXCLUDE_PATTERNS` to skip analysis of files matching certain patterns:

```cmake
Cppcheck_Configure(
    STATUS ON
    ENABLE warning style performance
    EXCLUDE_PATTERNS
        "*/third_party/*"
        "*/generated/*"
        "*_autogen.*"
        "*/test/*"
)
```

Useful regex patterns:

- `*/third_party/*`: exclude third-party dependencies
- `*/generated/*`: exclude auto-generated code
- `*_autogen.*`: exclude Qt/CMake generated files
- `*/test/*`: exclude test code (optional)
- `^build/.*`: exclude build artifacts
- `.*moc_.*`: exclude Qt MOC files
- `.*/CMakeFiles/.*`: exclude CMake generated files

### Per-Target Exclusions

Exclude patterns for specific targets:

```cmake
add_library(mylib src/main.cpp src/generated.cpp)

Cppcheck_ConfigureTarget(
    TARGET mylib
    STATUS ON
    ENABLE warning style
    EXCLUDE_PATTERNS "*generated*"
)
```

## CI Integration

### GitHub Actions Example

`.github/workflows/cppcheck.yml`:

```yaml
name: Cppcheck Analysis

on: [push, pull_request]

jobs:
  cppcheck:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
        with:
          submodules: recursive

      - name: Install cppcheck
        run: sudo apt-get update && sudo apt-get install -y cppcheck

      - name: Configure CMake
        run: cmake -S . -B build -DCMAKE_EXPORT_COMPILE_COMMANDS=ON

      - name: Build with cppcheck
        run: cmake --build build

      - name: Archive cppcheck results
        if: always()
        uses: actions/upload-artifact@v3
        with:
          name: cppcheck-results
          path: build/
```

### Strict CI Mode

For strict CI environments where analysis must succeed:

`CMakeLists.txt`:

```cmake
# Enable strict mode for CI, advisory for development
if(DEFINED ENV{CI})
    set(CPPCHECK_STRICT STRICT)
endif()

find_package(Cppcheck QUIET)
include(Cppcheck)

Cppcheck_Configure(
    STATUS ON
    ${CPPCHECK_STRICT}
    ENABLE warning style performance
    SUPPRESS missingIncludeSystem
)
```

Run locally with advisory mode, in CI with strict mode:

```bash
# Local development (advisory)
cmake -S . -B build
cmake --build build

# CI pipeline (strict)
export CI=1
cmake -S . -B build
cmake --build build
```

## Troubleshooting

### "Cppcheck not found"

**Problem**: Build fails or continues with verbose message about cppcheck not found.

**Solution**:

1. Install cppcheck:
   ```bash
   # Ubuntu/Debian
   sudo apt-get install cppcheck

   # macOS
   brew install cppcheck

   # Fedora/RHEL
   sudo dnf install cppcheck
   ```

2. Verify cppcheck is in PATH:
   ```bash
   which cppcheck
   cppcheck --version
   ```

3. If not in PATH, set cmake module path or use `-DCMAKE_PREFIX_PATH`:
   ```bash
   cmake -S . -B build -DCMAKE_PREFIX_PATH=/usr/local/opt/cppcheck
   ```

4. Switch from strict to advisory mode during development:
   ```cmake
   # Remove STRICT flag for optional analysis
   Cppcheck_Configure(
       STATUS ON
       ENABLE warning style
   )
   ```

### Analysis takes too long

**Problem**: Build is slow due to cppcheck analysis.

**Solution**:

1. Exclude unnecessary patterns:
   ```cmake
   Cppcheck_Configure(
       STATUS ON
       ENABLE warning style
       EXCLUDE_PATTERNS "*/test/*" "*/third_party/*"
   )
   ```

2. Reduce check categories:
   ```cmake
   # Use fewer checks
   Cppcheck_Configure(
       STATUS ON
       ENABLE warning
   )
   ```

3. Disable for non-critical targets:
   ```cmake
   add_library(utils src/utils.cpp)
   Cppcheck_ConfigureTarget(TARGET utils STATUS OFF)
   ```

4. Use advisory mode during development:
   ```cmake
   set(CPPCHECK_STATUS OFF)
   if(DEFINED ENV{CI})
       set(CPPCHECK_STATUS ON)
   endif()

   Cppcheck_Configure(
       STATUS ${CPPCHECK_STATUS}
       ENABLE warning style
   )
   ```

### False positives from analysis

**Problem**: Cppcheck reports issues that are not real bugs.

**Solution**:

1. Suppress specific checks:
   ```cmake
   Cppcheck_Configure(
       STATUS ON
       ENABLE warning style performance
       SUPPRESS missingIncludeSystem unusedVariable
   )
   ```

2. Suppress for specific targets:
   ```cmake
   Cppcheck_ConfigureTarget(
       TARGET legacy_lib
       STATUS ON
       ENABLE warning
       SUPPRESS unusedVariable constParameter
   )
   ```

3. Use inline suppression comments (add to source code):
   ```cpp
   // cppcheck-suppress unusedVariable
   int unused_var = 0;
   ```

### Target does not exist

**Problem**: `Cppcheck_ConfigureTarget` fails because target doesn't exist.

**Solution**:

1. Ensure target is created before configuration:
   ```cmake
   add_library(mylib src/lib.cpp)
   
   # Configure AFTER target creation
   Cppcheck_ConfigureTarget(
       TARGET mylib
       STATUS ON
   )
   ```

2. Use advisory mode to avoid fatal error:
   ```cmake
   # Without STRICT flag, missing target produces warning only
   Cppcheck_ConfigureTarget(
       TARGET possibly_missing
       STATUS ON
   )
   ```

3. Check target exists before configuring:
   ```cmake
   if(TARGET mylib)
       Cppcheck_ConfigureTarget(
           TARGET mylib
           STATUS ON
       )
   endif()
   ```

## See Also

- [ClangFormat CMake Module](./clangformat.md) - Code formatting
- [Cppcheck Official Documentation](http://cppcheck.sourceforge.net/)
- [Cppcheck Manual](http://cppcheck.sourceforge.net/manual.pdf)
- [CMake compile-time checks](https://cmake.org/cmake/help/latest/prop_tgt/C_CPPCHECK.html)
