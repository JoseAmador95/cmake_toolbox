# CMake Toolbox - Development Instructions

This document outlines the coding standards, patterns, and best practices to follow when working on the CMake Toolbox project.

## Code StyFunctions:
  ModuleName_AddTargets(PREFIX [options]) - Description

#]=======================================================================]nd Formatting

### CMake Formatting with Gersemi
- **Always use gersemi** for formatting CMake files
- Configuration is in `.gersemirc`:
- **Format before committing**: `gersemi --in-place <file.cmake>`

### Function Argument Patterns

#### Use `ARG` Prefix Consistently
- **All function arguments** must use the `ARG_` prefix for consistency
- Apply to both positional and parsed arguments:

```cmake
# Positional arguments
function(my_function ARG_OUTPUT_VAR ARG_INPUT_FILE)

# Parsed arguments  
function(my_function ARG_OUTPUT_VAR)
    cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
    # Use ARG_SOURCE_DIRS, ARG_EXTENSIONS, etc.
```

#### cmake_parse_arguments Pattern
- **Always use `ARG` as the first argument** to `cmake_parse_arguments`:
```cmake
cmake_parse_arguments(ARG "${options}" "${oneValueArgs}" "${multiValueArgs}" ${ARGN})
```
- **Never use** function-specific prefixes like `COLLECT`, `CMD`, `CLANGFMT`

### Error Handling and Messages

#### Dynamic Function Names
- **Use `${CMAKE_CURRENT_FUNCTION}`** instead of hardcoded function names:
```cmake
if(NOT ARG_REQUIRED_PARAM)
    message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: REQUIRED_PARAM must be provided")
endif()
```

#### Input Validation
- **Validate required parameters** at the beginning of functions
- **Use FATAL_ERROR** for missing required parameters
- **Use WARNING** for non-critical issues (missing files, etc.)

## Find Module Patterns

### Standard CMake Find Module Structure
- **Follow CMake conventions** for Find modules:
  - Use `find_program()`, `find_library()`, etc.
  - Set standard variables: `<Package>_FOUND`, `<Package>_EXECUTABLE`, `<Package>_VERSION`
  - Use `find_package_handle_standard_args()`
  - Mark cache variables as advanced with `mark_as_advanced()`

### Executable Find Modules
- **Do NOT create imported targets** for simple executables
- **Use `<Package>_EXECUTABLE` variable directly** in custom commands
- **Imported targets are uncommon** for tools/executables (unlike libraries)

### Version Detection
- **Extract version information** when possible:
```cmake
execute_process(
    COMMAND ${Tool_EXECUTABLE} --version
    OUTPUT_VARIABLE Tool_VERSION_OUTPUT
    ERROR_QUIET
    OUTPUT_STRIP_TRAILING_WHITESPACE
)
```

## Function Design Principles

### Utility Functions
- **Keep utility functions focused** - single responsibility
- **Avoid default assumptions** about project structure in utility functions
- **Let higher-level functions handle defaults**:

```cmake
# GOOD: Utility function requires explicit input
function(ClangFormat_CollectFiles ARG_OUTPUT_VAR)
    if(NOT ARG_SOURCE_DIRS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: SOURCE_DIRS must be provided")
    endif()
    # ... rest of function
endfunction()

# BAD: Utility function assumes defaults
function(ClangFormat_CollectFiles ARG_OUTPUT_VAR)
    if(NOT ARG_SOURCE_DIRS)
        set(ARG_SOURCE_DIRS "src" "include")  # Don't do this in utilities
    endif()
endfunction()
```

### API Design
- **Use keyword arguments** for complex functions with multiple parameters:
```cmake
ClangFormat_AddTargets(
    my_project
    SOURCE_DIRS src include
    CONFIG_FILE ${CMAKE_SOURCE_DIR}/.clang-format
    EXCLUDE_PATTERNS ".*generated.*"
)
```

- **Prefer explicit over implicit** - make the API clear about what's required vs optional

## Module Architecture

### Separation of Concerns
- **Basic utilities** in `<Tool>.cmake` (e.g., `ClangFormat.cmake`)
- **Find module** in `Find<Tool>.cmake` (e.g., `FindClangFormat.cmake`)
- **Find modules depend on utilities**: `include(<Tool>)`

### Backward Compatibility
- **Avoid backward compatibility** unless specifically required
- **Clean, modern APIs** are preferred over legacy support
- **Document migration paths** if breaking changes are necessary

## Testing Patterns

### Unit Testing Requirements
- **All new features must be unit tested** using the CTest framework
- **Unit tests are declared in `examples/CMakeLists.txt`** and automatically discovered
- **Follow the existing test patterns** in `unit_tests/` directory structure:
  - `unit_tests/<module>/test_*.cmake` files
  - Each test file should be self-contained and focused on specific functionality

### Integration Testing
- **Test in real CMake projects**, not just script mode
- **Script mode has limitations** (can't create targets, etc.)
- **Use simple test projects** to verify functionality:

```cmake
cmake_minimum_required(VERSION 3.15)
project(TestModule)
list(APPEND CMAKE_MODULE_PATH "${CMAKE_CURRENT_SOURCE_DIR}/../cmake")
find_package(MyTool REQUIRED)
# Test basic functionality
```

## File Organization

### Project Structure
```
cmake/
├── FindTool.cmake          # Find modules
├── Tool.cmake              # Basic utilities (CamelCase)
├── OtherTool.cmake         # Other tool utilities (CamelCase)
tests/
├── test_findtool.cmake     # Module tests
examples/
├── CMakeLists.txt          # Example usage
docs/
├── tool.md                 # Tool-specific documentation
```

### Naming Conventions
- **Find modules**: `FindToolName.cmake`
- **Utility modules**: `ToolName.cmake` (CamelCase - new pattern)
- **Test files**: `test_modulename.cmake`
- **Functions**: `ModuleName_FunctionName` (e.g., `ClangFormat_AddTargets`, `ClangFormat_CollectFiles`, `ClangFormat_ValidateConfig`)

## Documentation

### RST Documentation Headers
- **Include comprehensive RST documentation** in Find modules:
```cmake
#[=======================================================================[.rst:
FindToolName
------------

Brief description of what the module does.

Variables:
  ToolName_FOUND        - True if tool was found
  ToolName_EXECUTABLE   - Path to tool executable  
  ToolName_VERSION      - Version string

Functions:
  ToolName_add_targets(PREFIX [options]) - Description

#]=======================================================================]
```

### Code Comments
- **Comment the "why", not the "what"**
- **Explain complex logic** and design decisions
- **Document function parameters** and expected behavior

## Common Pitfalls to Avoid

### CMake-Specific Issues
- **Don't create targets in script mode** - check `CMAKE_SCRIPT_MODE_FILE`
- **Handle empty lists properly** - `if(NOT ARG_LIST)` vs `if(ARG_LIST STREQUAL "")`
- **Use `VERBATIM` in custom commands** to handle spaces and special characters

### Module Design Issues
- **Don't mix positional and keyword arguments** inconsistently
- **Don't hardcode project assumptions** in utility functions
- **Don't create unnecessary imported targets** for simple executables

### Error Handling
- **Always validate required inputs** early in functions
- **Provide clear, actionable error messages**
- **Use appropriate message levels** (STATUS, WARNING, FATAL_ERROR)

## Development Workflow

1. **Write the function signature** with `ARG_` prefixed parameters
2. **Add input validation** for required parameters
3. **Implement core logic** following the utility function principles
4. **Create unit tests** in `unit_tests/<module>/test_*.cmake` following existing patterns
5. **Format with gersemi** before testing
6. **Test in a real CMake project** (not just script mode)
7. **Verify unit tests pass** by running CTest
8. **Update documentation** if adding new public APIs

---

*This document should be updated as new patterns and requirements emerge in the project.*
