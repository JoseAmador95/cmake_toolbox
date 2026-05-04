# IWYU Integration Tests

End-to-end integration tests for the IWYU (include-what-you-use) CMake module with mock C++ projects and actual builds.

## Test Suite

These tests use actual CMake projects to verify the IWYU module integrates correctly:

### 1. `test_configuration.cmake`

Comprehensive integration test suite for the IWYU module with mock C++ projects and **real CMake builds**.

**Tests Included:**

1. **Global Configuration - ON (Advisory Mode, C++-only)**
   - Verifies `IWYU_Configure(STATUS ON)` works
   - Creates a real CMake C++ project
   - Tests advisory mode (graceful handling when tool missing)
   - **Validates CMAKE_CXX_INCLUDE_WHAT_YOU_USE is set**
   - **Verifies CMAKE_C_INCLUDE_WHAT_YOU_USE is NOT set (C++-only)**
   - **Executes `cmake --build` to verify IWYU runs during compilation**

2. **Global Configuration - OFF**
   - Tests `IWYU_Configure(STATUS OFF)` clears settings
   - Verifies idempotency (ON then OFF restores clean state)
   - Validates CMAKE_CXX_INCLUDE_WHAT_YOU_USE is cleared
   - **Executes build to verify IWYU is disabled**

3. **Per-Target Configuration with Mapping File**
   - Tests `IWYU_ConfigureTarget()` on specific targets
   - Verifies selective C++ target configuration
   - Tests MAPPING_FILE parameter (for IWYU .imp mapping files)
   - Tests ADDITIONAL_ARGS parameter
   - Validates different targets can have different configs
   - **Executes build with per-target analysis**

4. **C++-Only Verification**
   - Critical test: Verifies IWYU is NOT applied to C code
   - Mixed C and C++ project
   - Validates CMAKE_CXX_INCLUDE_WHAT_YOU_USE set for C++
   - Validates CMAKE_C_INCLUDE_WHAT_YOU_USE is NOT set for C
   - **Executes build with mixed C/C++ project**

5. **Strict Mode**
   - Tests `IWYU_Configure(STATUS ON STRICT)`
   - Verifies STRICT flag causes fatal error when tool missing
   - Validates advisory vs strict mode distinction

6. **Additional -Xiwyu Arguments**
   - Tests ADDITIONAL_ARGS parameter
   - Verifies arguments like `--no_fwd_decls`, `--keep_going`
   - Each argument automatically prefixed with `-Xiwyu`
   - **Executes build with IWYU arguments**

## Running the Tests

```bash
# Run from repository root
cmake -P unit_tests/integration/iwyu/test_configuration.cmake

# Or with more verbose output
cmake -P unit_tests/integration/iwyu/test_configuration.cmake --debug-output
```

## Expected Output

All tests should PASS with output like:
```
-- === IWYU Integration Tests ===
-- Test 1: IWYU_Configure STATUS ON (C++-only, advisory mode)
--   ✓ IWYU_Configure STATUS ON works (advisory mode)
-- Test 2: IWYU_Configure STATUS OFF
--   ✓ IWYU_Configure STATUS OFF works
...
-- All IWYU integration tests PASSED ✓
```

## Test Artifacts

Mock projects and build artifacts are created in:
- `${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_iwyu/`

Default location: `build/test_artifacts/integration_iwyu/`

Each test creates its own isolated mock C++ project with:
- `CMakeLists.txt` - Test project configuration (C++-only or mixed)
- `.cpp` files - C++ test source code
- `.c` files - C test source code (for C++-only verification)
- `iwyu.imp` - IWYU mapping file (for mapping file tests)
- `build/` - CMake build directory

## Design Notes

- **Mock C++ Projects**: Each test creates isolated, real CMake C++ projects
- **Real Builds**: Each test executes `cmake --build` to verify tool integration
- **Build Verification**: Confirms IWYU runs (or doesn't run) as configured
- **C++-Only Enforcement**: IWYU is always configured ONLY for CMAKE_CXX_INCLUDE_WHAT_YOU_USE
- **Advisory Mode**: Tests pass even when include-what-you-use tool is not installed
- **Strict Mode**: Tests verify fatal errors when STRICT flag used without tool
- **Idempotency**: Configuration can be called multiple times safely
- **No Side Effects**: Tests clean up after themselves

## C++-Only Constraint

IMPORTANT: IWYU is always C++-only per CMake standards. This module:
- Sets CMAKE_CXX_INCLUDE_WHAT_YOU_USE (C++ compiler)
- Never sets CMAKE_C_INCLUDE_WHAT_YOU_USE (C compiler)
- Test 4 verifies this constraint in mixed C/C++ projects

## Features Tested

✅ Global configuration (Advisory and Strict modes)
✅ Per-target configuration with granular control
✅ Mapping file support (IWYU .imp format)
✅ Additional -Xiwyu arguments
✅ C++-only enforcement (verified with mixed C/C++ project)
✅ Tool detection and graceful fallback
✅ Multiple enable/disable cycles
✅ TARGET and STATUS parameter validation
