# Clang-Format Unit Test Suite

This document describes the comprehensive unit test suite for the CMake Clang-Format module.

## Test Organization

All clang-format-related unit tests are located in `unit_tests/clangformat/` and are organized by functional area:

### Core Test Files

1. **`test_basic_functionality.cmake`** - Tests fundamental clang-format operations
   - Target creation when clang-format is available
   - Graceful handling when clang-format is not found
   - Configuration file validation
   - Basic source file discovery

2. **`test_file_discovery.cmake`** - Tests source file discovery functionality
   - File extension handling (C, C++, headers)
   - Multiple source directory support
   - Directory existence validation
   - Duplicate file removal

3. **`test_configuration.cmake`** - Tests configuration options
   - Config file vs inline style options
   - Custom arguments handling
   - Source directory configuration
   - Cache variable behavior

4. **`test_target_creation.cmake`** - Tests custom target creation
   - clangformat_check target properties
   - clangformat_edit target properties
   - Command line argument construction
   - VERBATIM handling

5. **`test_edge_cases.cmake`** - Tests edge cases and error conditions
   - Missing configuration files
   - Empty source directories
   - Invalid directory paths
   - No source files found scenarios

## Test Execution

The clang-format tests are automatically integrated with CTest. To run all tests:

```bash
cd build
ctest
```

To run only clang-format tests:
```bash
ctest -R "clangformat_.*"
```

To run a specific test:
```bash
ctest -R "clangformat_basic_functionality"
```

Available test names:
- `clangformat_basic_functionality`
- `clangformat_file_discovery`
- `clangformat_configuration`
- `clangformat_target_creation`
- `clangformat_edge_cases`

To run individual tests directly (for debugging):
```cmake
cmake -P unit_tests/clangformat/test_basic_functionality.cmake
```

## Test Environment

Tests create isolated temporary directories and mock executables to ensure:
- No dependency on system clang-format installation
- Predictable test results
- No side effects on the actual project

## Expected Behavior

- Tests should pass regardless of whether clang-format is installed on the system
- Each test file reports its own error count
- Failed tests provide clear diagnostic messages
- All tests clean up after themselves
