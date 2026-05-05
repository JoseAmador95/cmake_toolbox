# Cppcheck Module Test Suite

This directory contains comprehensive tests for the `FindCppcheck.cmake` and `Cppcheck.cmake` modules.

## Overview

The Cppcheck module provides static code analysis integration for CMake projects. These tests verify:

- **FindCppcheck module**: Locating the cppcheck executable
- **Cppcheck_Configure()**: Global configuration for all targets
- **Cppcheck_ConfigureTarget()**: Per-target configuration
- **Advisory mode**: Graceful handling when cppcheck is not installed
- **Strict mode**: Enforcing cppcheck availability when required
- **Parameter handling**: ENABLE, SUPPRESS, EXCLUDE_PATTERNS flags

## Key Features Tested

1. **Tool Discovery**: FindCppcheck locates cppcheck on the system
2. **Advisory Mode (Default)**: CMake configuration succeeds even without cppcheck
3. **Strict Mode**: Configuration fails with clear error when cppcheck is unavailable
4. **Per-Target Configuration**: Setting analysis rules for specific targets
5. **Flag Processing**: Proper handling of enable/suppress/exclude patterns

## Running Tests

### Run All Tests
```bash
cd unit_tests/cppcheck
for test in test_*.cmake; do
  echo "=== Running $test ==="
  cmake -P "$test"
done
```

### Run Individual Tests
Each test can be executed independently with cmake:

```bash
cmake -P test_find_cppcheck.cmake
cmake -P test_configure_advisory.cmake
cmake -P test_configure_strict_fails.cmake
cmake -P test_configure_target_basic.cmake
cmake -P test_enable_suppress_flags.cmake
cmake -P test_exclude_patterns.cmake
cmake -P test_status_off.cmake
```

### Expected Output

Tests produce status messages using CMake's `message()` command:

**On Success:**
```
-- PASS: [test description]
```

**On Failure:**
```
FATAL_ERROR: FAIL: [error description]
```

## Test Files

### test_find_cppcheck.cmake
Tests the FindCppcheck module's ability to:
- Use `find_package(Cppcheck QUIET)` without errors
- Set/unset `Cppcheck_FOUND` variable appropriately
- Populate `Cppcheck_EXECUTABLE` when available
- Extract version information

**Expected Result:** PASS (with or without cppcheck installed)

### test_configure_advisory.cmake
Tests the default advisory mode where cppcheck is optional:
- Calls `Cppcheck_Configure(STATUS ON)` without STRICT flag
- Verifies CMake configuration succeeds even if cppcheck unavailable
- Works with or without cppcheck installed

**Expected Result:** PASS

### test_configure_strict_fails.cmake
Tests strict mode enforcement:
- Calls `Cppcheck_Configure(STATUS ON STRICT)` without cppcheck
- If cppcheck is installed: configures successfully
- If cppcheck is NOT installed: runs a subprocess to verify STRICT causes FATAL_ERROR

**Expected Result:** PASS (test validates strict mode enforcement correctly)

### test_configure_target_basic.cmake
Tests per-target configuration with missing target validation:
- Attempts to call `Cppcheck_ConfigureTarget(TARGET nonexistent STATUS ON)` with non-existent target
- Verifies configuration FAILS because target must exist (not context-dependent)
- Also tests that STRICT flag is properly accepted

**Expected Result:** FAIL (target validation is always enforced)

### test_enable_suppress_flags.cmake
Tests flag processing:
- Calls with `ENABLE warning;style` and `SUPPRESS missingIncludeSystem`
- Verifies flags are properly formatted as: `--enable=warning,style` and `--suppress=missingIncludeSystem`
- Prints resulting command for verification

**Expected Result:** PASS (if cppcheck available), PASS (graceful in advisory mode)

### test_exclude_patterns.cmake
Tests pattern exclusion:
- Calls with multiple `EXCLUDE_PATTERNS`
- Verifies patterns are stored as `--exclude=pattern` flags
- Prints patterns for verification

**Expected Result:** PASS

### test_status_off.cmake
Tests disabling cppcheck:
- Calls `Cppcheck_Configure(STATUS OFF)`
- Verifies `CMAKE_C_CPPCHECK` and `CMAKE_CXX_CPPCHECK` are empty
- Works regardless of tool availability

**Expected Result:** PASS

## Test Architecture

All tests follow this pattern:

1. **Minimal Project Setup**: Each test creates a minimal CMake project
2. **Module Inclusion**: Includes the Cppcheck module from the parent cmake directory
3. **Configuration Test**: Executes the function being tested
4. **Verification**: Checks that the result is as expected
5. **Status Reporting**: Outputs PASS or FAIL via CMake messages

## CI/CD Integration

These tests are designed for CI/CD pipelines:

- **Works without cppcheck**: Advisory tests pass even in minimal environments
- **Works with cppcheck**: Tests validate correct configuration when tool is available
- **Clear error messages**: Each test provides clear PASS/FAIL output
- **Fast execution**: Tests run in seconds without building anything

## Dependencies

- CMake 3.22 or later
- cppcheck (optional; tests work without it)

## Notes

- Tests are stateless and can run in any order
- Each test file can be executed independently
- No file system modifications outside the test directory
- All temporary files are created in the test process's temporary directory
