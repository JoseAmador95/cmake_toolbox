# Clang-Format CMake Module

This module integrates `clang-format` into your CMake project using generated build targets.

## API Overview

Use the current API:

```cmake
find_package(ClangFormat QUIET)
include(ClangFormat)

ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS src include
)
```

This creates:
- `myproject_check`: verifies formatting without modifying files
- `myproject_format`: formats files in-place

## Requirements

- CMake `3.22+`
- CMake module path includes this repository's `cmake/` directory
- `find_package(ClangFormat ...)` called before `include(ClangFormat)`

If `clang-format` is not found, target creation is skipped with a warning.

## Function Reference

```cmake
ClangFormat_AddTargets(
    TARGET_PREFIX <prefix>
    SOURCE_DIRS <dir1> [<dir2> ...]
    [EXTENSIONS <pattern1> [<pattern2> ...]]
    [EXCLUDE_PATTERNS <regex1> [<regex2> ...]]
    [CONFIG_FILE <path>]
    [ADDITIONAL_ARGS <arg1> [<arg2> ...]]
)
```

Parameters:
- `TARGET_PREFIX` (required): creates `<prefix>_check` and `<prefix>_format`
- `SOURCE_DIRS` (required): source directories to scan for files
- `EXTENSIONS` (optional): glob patterns (default includes common C/C++ extensions)
- `EXCLUDE_PATTERNS` (optional): regex patterns matched against source-relative paths
- `CONFIG_FILE` (optional): path to `.clang-format` (default `${CMAKE_SOURCE_DIR}/.clang-format`)
- `ADDITIONAL_ARGS` (optional): extra flags passed to `clang-format`

## Minimal Working Example

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.22)
project(Example LANGUAGES C CXX)

set(CMAKE_MODULE_PATH "${CMAKE_SOURCE_DIR}/cmake")

find_package(ClangFormat QUIET)
include(ClangFormat)

ClangFormat_AddTargets(
    TARGET_PREFIX example
    SOURCE_DIRS src include
)
```

Build and run targets:

```bash
cmake -S . -B build
cmake --build build --target example_check
cmake --build build --target example_format
```

## Target Naming

Target names are derived from `TARGET_PREFIX`:

- `<prefix>_check`
- `<prefix>_format`

Example:

```cmake
ClangFormat_AddTargets(TARGET_PREFIX core SOURCE_DIRS src)
```

Creates `core_check` and `core_format`.

## Excluding Files

Use `EXCLUDE_PATTERNS` with regex patterns:

```cmake
ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS src include tests
    EXCLUDE_PATTERNS
        "^generated/.*"
        ".*third_party.*"
        ".*_autogen\\."
)
```

Useful regex examples:
- `^generated/.*`: exclude files under `generated/`
- `.*test.*`: exclude files containing `test`
- `\\.bak$`: exclude `.bak` files

## Custom Extensions and Arguments

```cmake
ClangFormat_AddTargets(
    TARGET_PREFIX myproject
    SOURCE_DIRS src include
    EXTENSIONS "*.c" "*.h" "*.cpp" "*.hpp"
    ADDITIONAL_ARGS "--verbose" "--sort-includes"
)
```

## CI Example

```yaml
- name: Check formatting
  run: cmake --build build --target myproject_check
```

## Behavior and Errors

- Missing `clang-format`: warning, no targets created
- Missing source directories: warning for each non-existent directory
- No matching source files: warning, no targets created
- Missing config file: warning, style argument omitted

## Migration Notes (Legacy API)

The following legacy usage is deprecated and should be replaced:

- `include(clangformat)` -> `include(ClangFormat)`
- `CLANG_FORMAT_SOURCE_DIRS` and other `CLANG_FORMAT_*` cache variables -> `ClangFormat_AddTargets(...)` arguments
- `clangformat_check` / `clangformat_edit` -> `<prefix>_check` / `<prefix>_format`
