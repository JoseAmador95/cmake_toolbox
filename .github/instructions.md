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

### Utility Function Design Principles
- **Single responsibility**: Each utility function should do one thing well
- **No default assumptions**: Utility functions should require explicit parameters rather than assuming project structure
- **Clear parameter validation**: Always validate required inputs and provide helpful error messages
- **Consistent return patterns**: Use output variables consistently (e.g., first parameter for output)
- **Proper error propagation**: Use appropriate message levels and FATAL_ERROR for missing required inputs

### Example ClangFormat Utility Functions
The ClangFormat module demonstrates proper utility function design:

```cmake
# Validates configuration file and returns style argument
function(ClangFormat_ValidateConfig ARG_CONFIG_FILE ARG_OUTPUT_VAR)
    if(EXISTS "${ARG_CONFIG_FILE}")
        set(${ARG_OUTPUT_VAR} "--style=file:${ARG_CONFIG_FILE}" PARENT_SCOPE)
    else()
        set(${ARG_OUTPUT_VAR} "" PARENT_SCOPE)
    endif()
endfunction()

# Collects source files using configurable patterns
function(ClangFormat_CollectFiles ARG_OUTPUT_VAR)
    cmake_parse_arguments(ARG "" "" "SOURCE_DIRS;PATTERNS;EXCLUDE_PATTERNS" ${ARGN})
    
    if(NOT ARG_SOURCE_DIRS)
        message(FATAL_ERROR "${CMAKE_CURRENT_FUNCTION}: SOURCE_DIRS must be provided")
    endif()
    
    if(NOT ARG_PATTERNS)
        set(ARG_PATTERNS "*.c" "*.cpp" "*.cxx" "*.cc" "*.h" "*.hpp" "*.hxx")
    endif()
    
    # Implementation...
    set(${ARG_OUTPUT_VAR} "${collected_files}" PARENT_SCOPE)
endfunction()

# Creates command for different modes (FORMAT vs CHECK)
function(ClangFormat_CreateCommand ARG_OUTPUT_VAR)
    cmake_parse_arguments(ARG "" "EXECUTABLE;STYLE_ARG;MODE" "FILES;ADDITIONAL_ARGS" ${ARGN})
    
    # Build command based on mode
    if(ARG_MODE STREQUAL "FORMAT")
        set(command "${ARG_EXECUTABLE}" "-i" ${ARG_STYLE_ARG} ${ARG_ADDITIONAL_ARGS} ${ARG_FILES})
    elseif(ARG_MODE STREQUAL "CHECK")
        set(command "${ARG_EXECUTABLE}" "--dry-run" "--Werror" ${ARG_STYLE_ARG} ${ARG_FILES})
    endif()
    
    set(${ARG_OUTPUT_VAR} "${command}" PARENT_SCOPE)
endfunction()
```

These functions demonstrate:
- **Clear responsibility separation**: Config validation, file collection, and command creation
- **Explicit parameter requirements**: SOURCE_DIRS must be provided, no defaults assumed
- **Flexible configuration**: Patterns and modes can be customized
- **Consistent error handling**: FATAL_ERROR for missing required parameters

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
- **Use CTest for efficient testing** - prefer unit tests over throwaway example projects
- **Run tests with CTest**: `cd build && ctest --verbose`

### Unit Test Best Practices
- **Test actual module implementations** by including the module under test:
```cmake
include(${CMAKE_CURRENT_LIST_DIR}/../../cmake/ModuleName.cmake)
```
- **Organize tests into functions** for better maintainability and debugging:
```cmake
set(ERROR_COUNT 0)

function(setup_test_environment)
    # Create test directories and files
    set(TEST_DIR "${CMAKE_BINARY_DIR}/module_test")
    file(REMOVE_RECURSE "${TEST_DIR}")
    file(MAKE_DIRECTORY "${TEST_DIR}")
    # Set up test environment variables
    set(CMAKE_SOURCE_DIR "${TEST_DIR}" PARENT_SCOPE)
endfunction()

function(test_specific_function)
    message(STATUS "Test 1: ModuleName_SpecificFunction")
    
    # Test implementation with proper error counting
    ModuleName_SpecificFunction(RESULT "test_input")
    if(RESULT STREQUAL "expected_output")
        message(STATUS "  ✓ Function works correctly")
    else()
        message(STATUS "  ✗ Expected 'expected_output', got '${RESULT}'")
        math(EXPR ERROR_COUNT "${ERROR_COUNT} + 1")
        set(ERROR_COUNT "${ERROR_COUNT}" PARENT_SCOPE)
    endif()
endfunction()

function(cleanup_test_environment)
    # Clean up test files and restore original state
    file(REMOVE_RECURSE "${TEST_DIR}")
    set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
endfunction()

function(run_all_tests)
    message(STATUS "=== Module Name Unit Tests ===")
    
    setup_test_environment()
    test_specific_function()
    test_another_function()
    test_error_handling()
    cleanup_test_environment()
    
    # Test Summary
    message(STATUS "")
    if(ERROR_COUNT EQUAL 0)
        message(STATUS "✓ All tests passed!")
    else()
        message(STATUS "✗ ${ERROR_COUNT} test(s) failed")
    endif()
    message(STATUS "")
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
    run_all_tests()
endif()
```

- **Use PARENT_SCOPE for error counting** to propagate ERROR_COUNT across functions
- **Test behavior, not implementation details** - focus on what functions do, not how they work internally
- **Create realistic test environments** with actual files and directories
- **Include comprehensive error handling tests** to verify functions behave correctly with invalid inputs
- **Use descriptive test output** with ✓ and ✗ symbols for clear pass/fail indication
- **Calculate expected values dynamically** instead of using magic numbers:
```cmake
set(EXPECTED_FILES "file1.c" "file2.cpp" "file3.h")
list(LENGTH EXPECTED_FILES expected_count)
list(LENGTH ACTUAL_FILES actual_count)
if(actual_count EQUAL expected_count)
    message(STATUS "  ✓ Found expected ${expected_count} files")
endif()
```

### Function-Based Test Organization Benefits
- **Better debugging**: Call stack shows which test function failed
- **Improved maintainability**: Each test is isolated and can be run independently
- **Clear structure**: Setup, individual tests, cleanup, and orchestration are separated
- **Error isolation**: Failures in one test don't prevent others from running
- **Easier extension**: New tests can be added as new functions without affecting existing ones

### Test Environment Management
- **Always save and restore CMAKE_SOURCE_DIR** when modifying it for tests:
```cmake
set(ORIGINAL_CMAKE_SOURCE_DIR "${CMAKE_SOURCE_DIR}")
# ... modify CMAKE_SOURCE_DIR for testing ...
set(CMAKE_SOURCE_DIR "${ORIGINAL_CMAKE_SOURCE_DIR}" PARENT_SCOPE)
```
- **Create isolated test directories** to avoid conflicts with the actual build
- **Clean up test artifacts** to prevent test pollution between runs
- **Use absolute paths** for test directories to avoid working directory issues
    test_specific_function()
    message(STATUS "=== All ModuleName tests passed ===")
endfunction()

if(CMAKE_SCRIPT_MODE_FILE)
    run_all_tests()
endif()
```
- **Avoid testing implementation details** like checking if specific CMAKE variables are used internally
- **Focus on public API behavior** and observable outputs rather than internal mechanisms
- **Test error conditions** by verifying expected warnings and error messages
- **Create temporary test directories** and clean them up after tests
- **Use meaningful assertions** with clear error messages explaining what failed

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

### Unit Testing Anti-Patterns
- **Don't test implementation details** like checking which internal CMAKE variables are used
- **Don't use magic numbers** in tests - calculate expected values from actual data:
```cmake
# BAD: Magic number
if(file_count EQUAL 6)

# GOOD: Calculate from expected data
set(EXPECTED_FILES "file1.c" "file2.cpp" "file3.h")
list(LENGTH EXPECTED_FILES expected_count)
if(file_count EQUAL expected_count)
```
- **Don't create monolithic test files** - organize into functions for better debugging and maintainability
- **Don't skip test environment cleanup** - always clean up temporary files and restore original state
- **Don't ignore error propagation** - use `PARENT_SCOPE` to propagate ERROR_COUNT across functions

### Function Design Issues
- **Don't mix behavior testing with implementation testing** - focus on what functions do, not how they do it
- **Don't hardcode assumptions about command structure** - test observable behavior instead:
```cmake
# BAD: Testing implementation details
list(FIND COMMAND "CMAKE_COMMAND" cmd_index)
if(cmd_index GREATER -1)
    message(STATUS "Command uses CMAKE_COMMAND")  # This tests HOW, not WHAT
endif()

# GOOD: Testing behavior
execute_process(COMMAND ${COMMAND} RESULT_VARIABLE result)
if(result EQUAL 0)
    message(STATUS "Command executed successfully")  # This tests WHAT
endif()
```
- **Don't forget to test error conditions** - verify functions handle invalid inputs gracefully
- **Don't make utility functions too rigid** - allow customization through optional parameters

## Additional Development Best Practices

### Naming Conventions
- **Parameter names should reflect their purpose accurately**:
  - Use `PATTERNS` for glob patterns like `*.c`, `*.cpp` (not `EXTENSIONS`)
  - Use `EXTENSIONS` only for literal file extensions like `.c`, `.cpp`
  - This helps users understand what format the parameter expects

### File Organization
- **Use `.in` extension only for configure_file() templates**:
  - Files processed by `configure_file()` should use `.in` extension (e.g., `config.h.in`)
  - Generic CMake scripts executed with `cmake -P` should not use `.in` extension
  - This prevents confusion about the file's purpose and processing method

### Cross-Platform Compatibility
- **Prefer CMake-native operations over shell commands**:
  - Use `CMAKE_COMMAND` for executing CMake scripts
  - Use CMake's built-in file operations instead of shell commands
  - Pass parameters to scripts via `-D` arguments rather than generating script content
  - Include `CMAKE_SCRIPT_MODE_FILE` protection in standalone scripts

### Script Parameter Passing
- **Pass parameters to CMake scripts efficiently**:
```cmake
execute_process(
    COMMAND ${CMAKE_COMMAND} 
        -DPARAMETER1=${value1}
        -DPARAMETER2=${value2}
        -P ${CMAKE_CURRENT_LIST_DIR}/script.cmake
    WORKING_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}
    RESULT_VARIABLE result
)
```
- This approach is more maintainable than generating script content dynamically

### Testing Efficiency
- **Use CTest unit tests instead of throwaway example projects**:
  - Unit tests run much faster and provide better isolation
  - They can test individual functions directly
  - Throwaway projects are time-consuming and harder to debug
  - Save integration testing for verifying complete workflows

### Diff Output Formatting
- **Use git-style diff formatting for better patch compatibility**:
  - Format paths as `a/filename` and `b/filename` in diff headers
  - This enables copy-paste of diffs into patch tools and git workflows
  - Helps users apply formatting changes more easily

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
2. **Add input validation** for required parameters with clear error messages
3. **Implement core logic** following the utility function principles (single responsibility, no defaults)
4. **Create comprehensive unit tests** in `unit_tests/<module>/test_*.cmake`:
   - Include the actual module under test
   - Organize tests into functions (setup, individual tests, cleanup, orchestration)
   - Test behavior, not implementation details
   - Use proper error counting with PARENT_SCOPE
   - Create realistic test environments
   - Calculate expected values dynamically (avoid magic numbers)
5. **Format with gersemi** before testing
6. **Run unit tests with CTest** to verify functionality: `cd build && ctest -R module_name --verbose`
7. **Test in a real CMake project** for integration testing (not just script mode)
8. **Update documentation** if adding new public APIs
9. **Review test output** for clear pass/fail indication and proper error messages

### Unit Test Development Checklist
- [ ] Tests include actual module implementation (not duplicate logic)
- [ ] Tests are organized into functions for better debugging
- [ ] Error counting uses PARENT_SCOPE for proper propagation
- [ ] Test environment is created and cleaned up properly
- [ ] Expected values are calculated dynamically, not hardcoded
- [ ] Tests focus on behavior/output, not implementation details
- [ ] Both success and error conditions are tested
- [ ] Test output uses clear ✓/✗ indicators
- [ ] CMAKE_SOURCE_DIR is saved/restored if modified
- [ ] All test functions are called from run_all_tests()

---

*This document should be updated as new patterns and requirements emerge in the project.*
