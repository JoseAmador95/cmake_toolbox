# IWYU Module Test Suite

This directory contains comprehensive tests for the `FindIWYU.cmake` and `IWYU.cmake` modules.

## Overview

The IWYU (Include What You Use) module provides static code analysis integration for C++ projects. These tests verify:

- **FindIWYU module**: Locating the include-what-you-use executable
- **IWYU_Configure()**: Global configuration for C++ targets
- **IWYU_ConfigureTarget()**: Per-target C++ configuration
- **Advisory mode**: Graceful handling when IWYU is not installed
- **Strict mode**: Enforcing IWYU availability when required
- **Parameter handling**: MAPPING_FILE, ADDITIONAL_ARGS, EXCLUDE_PATTERNS
- **C++ only**: Verifying IWYU is configured only for C++, not C

## Key Features Tested

1. **Tool Discovery**: FindIWYU locates include-what-you-use on the system
2. **Advisory Mode (Default)**: CMake configuration succeeds even without IWYU
3. **Strict Mode**: Configuration fails with clear error when IWYU is unavailable
4. **Per-Target Configuration**: Setting analysis rules for specific C++ targets
5. **Mapping File Handling**: Proper validation of .imp mapping files
6. **Argument Processing**: Correct prefixing with -Xiwyu for all additional arguments
7. **C++ Only**: Verifying CMAKE_CXX_INCLUDE_WHAT_YOU_USE is set but not CMAKE_C_INCLUDE_WHAT_YOU_USE

## Running Tests

### Run All Tests
```bash
cd unit_tests/iwyu
for test in test_*.cmake; do
  echo "=== Running $test ==="
  cmake -P "$test"
done
```

### Run Individual Tests
Each test can be executed independently with cmake:

```bash
cmake -P test_find_iwyu.cmake
cmake -P test_configure_advisory.cmake
cmake -P test_configure_strict_fails.cmake
cmake -P test_configure_target_basic.cmake
cmake -P test_configure_target_missing_advisory.cmake
cmake -P test_mapping_file_handling.cmake
cmake -P test_additional_args.cmake
cmake -P test_exclude_patterns.cmake
cmake -P test_cxx_only.cmake
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

### test_find_iwyu.cmake
Tests the FindIWYU module's ability to:
- Use `find_package(IWYU QUIET)` without errors
- Set/unset `IWYU_FOUND` variable appropriately
- Populate `IWYU_EXECUTABLE` when available
- Extract version information

**Expected Result:** PASS (with or without IWYU installed)

### test_configure_advisory.cmake
Tests the default advisory mode where IWYU is optional:
- Calls `IWYU_Configure(STATUS ON)` without STRICT flag
- Verifies CMake configuration succeeds even if IWYU unavailable
- Works with or without IWYU installed

**Expected Result:** PASS

### test_configure_strict_fails.cmake
Tests strict mode enforcement:
- Calls `IWYU_Configure(STATUS ON STRICT)` without IWYU
- Expects CMake configuration to FAIL with fatal error
- This test is expected to fail when IWYU is not installed

**Expected Result:** FAIL (intentional, when IWYU not available)

### test_configure_target_basic.cmake
Tests per-target configuration with real C++ target:
- Creates a dummy C++ CMake target
- Calls `IWYU_ConfigureTarget(TARGET mytarget STATUS ON)`
- Verifies configuration succeeds in advisory mode

**Expected Result:** PASS

### test_configure_target_missing_advisory.cmake
Tests per-target configuration with missing target validation:
- Attempts to call `IWYU_ConfigureTarget(TARGET nonexistent STATUS ON)` with non-existent target
- Verifies configuration FAILS because target must exist (not context-dependent)

**Expected Result:** FAIL (target validation is always enforced)

### test_mapping_file_handling.cmake
Tests mapping file parameter:
- Calls with `MAPPING_FILE /path/to/mapping.imp`
- Verifies parameter is properly processed as `-Xiwyu --mapping_file=<path>`
- In strict mode, should fail if file doesn't exist and IWYU is available

**Expected Result:** PASS (advisory mode), behavior varies with tool availability

### test_additional_args.cmake
Tests argument passing:
- Calls with `ADDITIONAL_ARGS "--no_fwd_decls;--keep_going"`
- Verifies args are properly prefixed with `-Xiwyu`
- Prints resulting command for verification

**Expected Result:** PASS

### test_exclude_patterns.cmake
Tests exclusion patterns (reserved for future use):
- Calls with `EXCLUDE_PATTERNS` parameter
- Verifies parameter is stored for future filtering

**Expected Result:** PASS

### test_cxx_only.cmake
Tests that IWYU is C++ only:
- Verifies `CMAKE_CXX_INCLUDE_WHAT_YOU_USE` is configured
- Verifies `CMAKE_C_INCLUDE_WHAT_YOU_USE` is NOT set
- Confirms IWYU handles only C++ sources

**Expected Result:** PASS

## Test Architecture

All tests follow this pattern:

1. **Minimal Project Setup**: Each test creates a minimal CMake project
2. **Module Inclusion**: Includes the IWYU module from the parent cmake directory
3. **Configuration Test**: Executes the function being tested
4. **Verification**: Checks that the result is as expected
5. **Status Reporting**: Outputs PASS or FAIL via CMake messages

## CI/CD Integration

These tests are designed for CI/CD pipelines:

- **Works without IWYU**: Advisory tests pass even in minimal environments
- **Works with IWYU**: Tests validate correct configuration when tool is available
- **Clear error messages**: Each test provides clear PASS/FAIL output
- **Fast execution**: Tests run in seconds without building anything

## Dependencies

- CMake 3.22 or later
- include-what-you-use (optional; tests work without it)

## Notes

- Tests are stateless and can run in any order
- Each test file can be executed independently
- No file system modifications outside the test directory
- All temporary files are created in the test process's temporary directory
