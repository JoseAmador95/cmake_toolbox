# Clang-Format CMake Module

This module provides CMake integration for clang-format to automatically format C/C++ source code.

## Features

- **Automatic Discovery**: Finds all C/C++ source files in specified directories
- **Flexible Configuration**: Supports both file-based and inline style configuration
- **Optional Dependencies**: Gracefully handles missing clang-format installation
- **File Exclusion**: Powerful pattern-based exclusion system
- **Two Modes**: Check-only mode for CI/CD and edit mode for development

## Configuration Variables

### Required Configuration
```cmake
set(CLANG_FORMAT_SOURCE_DIRS "src;include" CACHE STRING 
    "Semicolon-separated list of source directories to format")
```

### Optional Configuration
```cmake
# Use .clang-format file (default: ON)
option(CLANG_FORMAT_USE_FILE "Use .clang-format file" ON)

# Path to .clang-format file (default: ${CMAKE_SOURCE_DIR}/.clang-format)
set(CLANG_FORMAT_CONFIG_FILE "${CMAKE_SOURCE_DIR}/.clang-format" CACHE STRING 
    "Clang-Format config file")

# Additional command-line arguments
set(CLANG_FORMAT_ARGS "--verbose" CACHE STRING 
    "Additional arguments to pass to clang-format")

# File exclusion patterns
set(CLANG_FORMAT_EXCLUDE_PATTERNS "generated/.*;\\.test\\." CACHE STRING 
    "Semicolon-separated list of regex patterns to exclude from formatting")
```

## File Exclusion Patterns

The `CLANG_FORMAT_EXCLUDE_PATTERNS` variable accepts a semicolon-separated list of regex patterns to exclude files from formatting.

```cmake
set(CLANG_FORMAT_EXCLUDE_PATTERNS "pattern1;pattern2;pattern3")
```

### Regex Pattern Types

#### 1. Directory Patterns
Exclude entire directories or files within specific directories:

```cmake
# Exclude all files in generated/ directory
set(CLANG_FORMAT_EXCLUDE_PATTERNS "^generated/.*")

# Exclude multiple directories
set(CLANG_FORMAT_EXCLUDE_PATTERNS "^generated/.*;^third_party/.*;^build/.*")

# Exclude any directory named "vendor" anywhere in the tree
set(CLANG_FORMAT_EXCLUDE_PATTERNS ".*/vendor/.*")
```

#### 2. Filename Patterns
Exclude files based on their names using precise regex:

```cmake
# Exclude all files containing "test" anywhere in the name
set(CLANG_FORMAT_EXCLUDE_PATTERNS ".*test.*")

# Exclude backup and temporary files
set(CLANG_FORMAT_EXCLUDE_PATTERNS "\\.bak$;\\.tmp$;~$")

# Exclude files starting with "test_"
set(CLANG_FORMAT_EXCLUDE_PATTERNS "^test_.*")

# Exclude specific filenames exactly
set(CLANG_FORMAT_EXCLUDE_PATTERNS "^config\\.h$;^version\\.c$")
```

#### 3. File Extension Patterns
Use regex for precise file extension matching:

```cmake
# Exclude C++ files (but keep C files)
set(CLANG_FORMAT_EXCLUDE_PATTERNS "\\.(cpp|cxx|cc|c\\+\\+)$")

# Exclude header files only
set(CLANG_FORMAT_EXCLUDE_PATTERNS "\\.(h|hpp|hxx|hh|h\\+\\+)$")

# Exclude files with double extensions
set(CLANG_FORMAT_EXCLUDE_PATTERNS "\\.[^.]+\\.[^.]+$")
```

#### 4. Advanced Regex Patterns
Leverage full regex power for complex exclusions:

```cmake
# Use alternation: exclude generated OR test files
set(CLANG_FORMAT_EXCLUDE_PATTERNS "(^generated/.*|.*test.*)")

# Exclude numbered files (file1.c, file2.h, etc.)
set(CLANG_FORMAT_EXCLUDE_PATTERNS ".*[0-9]+\\.(c|h)$")

# Exclude files modified recently (combine with CMake date logic)
set(CLANG_FORMAT_EXCLUDE_PATTERNS ".*_(today|new|recent)\\.")
```

### Real-World Exclusion Examples

#### Typical C Project
```cmake
set(CLANG_FORMAT_SOURCE_DIRS "src;include;examples")
set(CLANG_FORMAT_EXCLUDE_PATTERNS 
    "^third_party/.*"    # External dependencies
    "^generated/.*"      # Auto-generated files
    ".*test.*"          # Test files (if using separate linter rules)
    "examples/legacy/.*" # Legacy example code
)
```

#### CMake Project with Multiple Components
```cmake
set(CLANG_FORMAT_SOURCE_DIRS "lib;tools;tests")
set(CLANG_FORMAT_EXCLUDE_PATTERNS 
    ".*/vendor/.*"       # Vendor code in any directory
    ".*_autogen\\."      # Auto-generated files
    "^tests/data/.*"     # Test data files
    "tools/external/.*"  # External tools
)
```

#### Cross-Platform Project
```cmake
set(CLANG_FORMAT_SOURCE_DIRS "src;platform")
set(CLANG_FORMAT_EXCLUDE_PATTERNS 
    "^platform/windows/.*" # Platform-specific code (if desired)
    ".*/compat/.*"         # Compatibility layers
    ".*_win32\\."          # Windows-specific files
    ".*\\.(asm|s)$"        # Assembly files
)
```

#### Large Codebase with Strict Rules
```cmake
set(CLANG_FORMAT_SOURCE_DIRS "src;include;lib;tools")
set(CLANG_FORMAT_EXCLUDE_PATTERNS 
    "^(third_party|external|vendor)/.*"  # All external code
    ".*/deprecated/.*"                    # Deprecated code
    ".*\\.(proto|generated)\\."          # Generated files
    ".*/test[_-].*"                      # Test files with various naming
    ".*[Bb]ackup.*"                      # Backup files
)
```

### Pattern Matching Rules

1. **Path Matching**: Patterns are matched against the relative path from `CMAKE_SOURCE_DIR`
2. **Filename Matching**: Patterns are also matched against just the filename
3. **Full Regex**: Use complete CMake regex syntax including:
   - `^` - Start of string
   - `$` - End of string  
   - `.*` - Match any characters
   - `.` - Match single character
   - `[abc]` - Character class
   - `(a|b)` - Alternation
   - `\\` - Escape special characters
4. **Case Sensitivity**: Patterns are case-sensitive
5. **First Match Wins**: Patterns are evaluated in order, first match excludes the file

### Common Regex Patterns

| Pattern | Description | Example |
|---------|-------------|---------|
| `^generated/.*` | Files in generated/ directory | `generated/parser.c` |
| `.*test.*` | Files with "test" anywhere | `test_file.c`, `utils_test.h` |
| `\\.bak$` | Files ending with .bak | `main.c.bak` |
| `^test_.*` | Files starting with "test_" | `test_utils.c` |
| `.*[0-9]+\\.c$` | C files with numbers | `file1.c`, `test123.c` |
| `(generated\\|tests)/.*` | Files in generated OR tests | `generated/a.c`, `tests/b.c` |
| `\\.(cpp\\|hpp)$` | C++ files only | `main.cpp`, `api.hpp` |

### Testing Your Patterns

You can test your regex patterns by temporarily adding debug output:

```cmake
# Add this temporarily to see what gets excluded
if(CLANG_FORMAT_EXCLUDE_PATTERNS)
    message(STATUS "Active exclusion patterns: ${CLANG_FORMAT_EXCLUDE_PATTERNS}")
    # Module will automatically report excluded count
endif()
```

### Migration from Glob Patterns

If you were using glob-style patterns before:

| Old Glob Pattern | New Regex Pattern | Description |
|------------------|-------------------|-------------|
| `generated/*` | `^generated/.*` | Directory exclusion |
| `*test*` | `.*test.*` | Filename containing text |
| `*.bak` | `\\.bak$` | File extension |
| `*/legacy/*` | `.*/legacy/.*` | Subdirectory anywhere |

### Performance Tips

1. **Anchor patterns** when possible (`^`, `$`) for faster matching
2. **Order patterns** from most specific to most general
3. **Combine related patterns** using alternation `(a|b|c)` instead of separate patterns
4. **Escape special characters** properly to avoid unexpected matches

## Usage

### Basic Setup
```cmake
include(clangformat)

# Configure source directories
set(CLANG_FORMAT_SOURCE_DIRS "src;include;examples")

# Optional: exclude patterns
set(CLANG_FORMAT_EXCLUDE_PATTERNS "generated/*;*test*")
```

### Generated Targets

The module creates two custom targets:

#### `clangformat_check`
- Checks code formatting without making changes
- Uses `--dry-run` and `--Werror` flags
- Perfect for CI/CD pipelines
- Returns non-zero exit code if formatting issues found

```bash
cmake --build . --target clangformat_check
```

#### `clangformat_edit`
- Formats code in-place
- Uses `-i` flag to edit files directly
- For development workflow

```bash
cmake --build . --target clangformat_edit
```

## Examples

### Simple Project
```cmake
include(clangformat)
set(CLANG_FORMAT_SOURCE_DIRS "src;include")
```

### Complex Project with Exclusions
```cmake
include(clangformat)
set(CLANG_FORMAT_SOURCE_DIRS "lib;tools;examples")
set(CLANG_FORMAT_EXCLUDE_PATTERNS 
    "^third_party/.*"     # External dependencies
    "^generated/.*"       # Auto-generated files
    ".*_test\\."         # Test files
    "examples/legacy/.*" # Legacy examples
)
set(CLANG_FORMAT_ARGS "--verbose --sort-includes")
```

### CI/CD Integration
```yaml
- name: Check Code Formatting
  run: |
    cmake --build build --target clangformat_check
```

## Supported File Extensions

The module automatically formats files with these extensions:
- **C**: `.c`, `.h`
- **C++**: `.cpp`, `.cxx`, `.cc`, `.c++`, `.hpp`, `.hxx`, `.hh`, `.h++`

## Error Handling

- **Missing clang-format**: Module skips target creation with status message
- **Missing config file**: Fatal error with clear message (when using file-based style)
- **No source files**: Warning message and graceful exit
- **Invalid directories**: Warning for each non-existent directory

## Dependencies

- **clang-format**: Optional, module gracefully handles absence
- **CMake 3.22+**: Required for modern CMake features

## Output Examples

```
-- clang-format not found, skipping format targets
```

```
-- Excluded 5 files matching patterns: ^generated/.*;.*test.*
-- Found 23 source files for clang-format
```

```
-- Source directory does not exist: /path/to/nonexistent
-- Found 15 source files for clang-format
```
