# Policy API Unit Test Suite

This document describes the comprehensive unit test suite for the CMake Policy API.

## Test Organization

All policy-related unit tests are located in `unit_tests/policy/` and are organized by functional area:

### Core Test Files

1. **`test_basic_operations.cmake`** - Tests fundamental policy operations
   - Policy registration with various configurations
   - Policy setting and getting
   - Handling of warnings and pipe character escaping
   - Basic error conditions

2. **`test_get_fields.cmake`** - Tests the `policy_get_fields` function
   - Retrieving all policy fields with custom prefixes
   - Testing with policies that have and don't have warnings
   - Verifying `IS_DEFAULT` flag behavior
   - Testing multiple prefixes don't interfere
   - Error handling for unregistered policies

3. **`test_policy_info.cmake`** - Tests the `policy_info` function
   - Pretty-printing of policy information
   - Display of all fields including warnings
   - Handling of multi-line warnings with special characters
   - Error handling for unregistered policies

4. **`test_policy_version.cmake`** - Tests the `policy_version` function
   - Setting policies based on minimum version requirements
   - Version range testing with MINIMUM and MAXIMUM
   - Complex version number comparisons
   - Verification of policy state changes

5. **`test_warning_handling.cmake`** - Tests warning message handling
   - Simple and complex warning messages
   - Pipe character escaping and unescaping
   - Multi-line warnings
   - Warnings with quotes and special characters
   - Empty warnings and missing warning parameters

6. **`test_error_handling.cmake`** - Tests error conditions and validation
   - Missing required parameters for all functions
   - Invalid parameter values
   - Duplicate policy registration
   - Operations on unregistered policies
   - Parameter validation for all public functions

7. **`test_edge_cases.cmake`** - Tests edge cases and integration scenarios
   - Very long policy names and descriptions
   - Complex version number scenarios
   - Stress testing with many policies
   - Complex warning messages with special characters
   - Consistency between different API functions
   - Minimal valid content edge cases

### Automatic CTest Integration

All test files matching the pattern `test_*.cmake` are automatically discovered and added to CTest using a programmatic approach in the CMakeLists.txt file. The test name is derived from the filename: `test_<name>.cmake` becomes `policy_<name>` in CTest.

## Test Quality Features

### Error Handling
- All tests use `message(SEND_ERROR)` for test failures
- Tests continue on error to report all issues
- Each test accumulates error counts
- Comprehensive test reporting with pass/fail status

### Coverage
The test suite covers:
- ✅ All public API functions (`policy_register`, `policy_set`, `policy_get`, `policy_version`, `policy_info`, `policy_get_fields`)
- ✅ All parameter combinations and optional parameters
- ✅ Error conditions and edge cases
- ✅ Special character handling (pipes, quotes, newlines)
- ✅ Version comparison logic
- ✅ Warning message escaping/unescaping
- ✅ Integration between different functions
- ✅ Stress testing with multiple policies

### CTest Integration
All test files are automatically discovered and integrated with CTest using pattern matching:

```cmake
# Automatically add all policy unit tests to CTest
file(GLOB POLICY_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/policy/test_*.cmake")
foreach(test_file ${POLICY_TEST_FILES})
    # Extract the test name from the filename (test_<name>.cmake -> <name>)
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    
    # Add the test to CTest with name policy_<name>
    add_test(
        NAME policy_${test_name}
        COMMAND ${CMAKE_COMMAND} -P ${test_file}
    )
endforeach()
```

Run tests with:
```bash
# Run all policy tests
ctest -R policy

# Run individual test categories  
ctest -R policy_basic_operations
ctest -R policy_get_fields
ctest -R policy_info
ctest -R policy_version
ctest -R policy_warning_handling
ctest -R policy_error_handling
ctest -R policy_edge_cases
```

## API Functions Tested

### `policy_register(NAME <name> DESCRIPTION <desc> DEFAULT <NEW|OLD> INTRODUCED_VERSION <ver> [WARNING <msg>])`
- ✅ All required parameters
- ✅ Optional WARNING parameter
- ✅ Parameter validation
- ✅ Duplicate registration prevention
- ✅ Warning message escaping

### `policy_set(POLICY <name> VALUE <NEW|OLD>)`
- ✅ Setting policy values
- ✅ Parameter validation
- ✅ Unregistered policy handling

### `policy_get(POLICY <name> OUTVAR <var>)`
- ✅ Getting policy values
- ✅ Default value behavior
- ✅ Parameter validation
- ✅ Unregistered policy handling

### `policy_version(MINIMUM <ver> [MAXIMUM <ver>])`
- ✅ Minimum version behavior
- ✅ Version range with MAXIMUM
- ✅ Complex version number comparisons
- ✅ Parameter validation

### `policy_info(POLICY <name>)`
- ✅ Information display formatting
- ✅ All field display including warnings
- ✅ Parameter validation
- ✅ Unregistered policy handling

### `policy_get_fields(POLICY <name> PREFIX <prefix>)`
- ✅ All field extraction
- ✅ Custom prefix handling
- ✅ IS_DEFAULT flag behavior
- ✅ Parameter validation
- ✅ Unregistered policy handling

## Test Execution

### Running Tests Locally
```bash
# Run individual tests directly
cmake -P unit_tests/policy/test_basic_operations.cmake
cmake -P unit_tests/policy/test_get_fields.cmake
# ... etc
```

### Running Tests via CTest
```bash
# From build directory
ctest -R policy --verbose

# Run all tests
ctest --verbose

# Run specific test
ctest -R policy_basic_operations --verbose
```

## Test Results
All tests are designed to:
- Pass with zero errors in normal operation
- Report specific failure details when issues occur
- Continue execution after failures to report all problems
- Provide clear, actionable error messages
- Exit with appropriate status codes for CI/CD integration

The test suite provides comprehensive coverage of the Policy API ensuring reliability, robustness, and correct behavior across all supported use cases.
