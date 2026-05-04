# Cppcheck Integration Tests

End-to-end integration tests for the Cppcheck CMake module with mock projects and actual builds.

## Test Suite

These tests use actual CMake projects to verify the Cppcheck module integrates correctly:

### 1. `test_configuration.cmake`

Comprehensive integration test suite for the Cppcheck module with mock projects and **real CMake builds**.

**Tests Included:**

1. **Global Configuration - ON (Advisory Mode)**
   - Verifies `Cppcheck_Configure(STATUS ON)` works
   - Creates a real CMake project and configures it
   - Tests advisory mode (graceful handling when tool missing)
   - Validates CMAKE_C_CPPCHECK is set when cppcheck found
   - **Executes `cmake --build` to verify Cppcheck runs during compilation**

2. **Global Configuration - OFF**
   - Tests `Cppcheck_Configure(STATUS OFF)` clears settings
   - Verifies idempotency (ON then OFF restores clean state)
   - Validates CMAKE_C_CPPCHECK is cleared
   - **Executes build to verify Cppcheck is disabled**

3. **Per-Target Configuration with Checks**
   - Tests `Cppcheck_ConfigureTarget()` on specific targets
   - Verifies selective target configuration
   - Tests with ENABLE/SUPPRESS parameters
   - Validates different targets can have different configs
   - **Executes build with per-target analysis**

4. **Strict Mode**
   - Tests `Cppcheck_Configure(STATUS ON STRICT)`
   - Verifies STRICT flag causes fatal error when tool missing
   - Validates advisory vs strict mode distinction

5. **Enable/Disable Checks**
   - Tests complex check configuration
   - Multiple targets with different check levels
   - Mixed C and C++ code
   - Validates parameter combinations
   - **Executes build with multiple check configurations**

## Running the Tests

```bash
# Run from repository root
cmake -P unit_tests/integration/cppcheck/test_configuration.cmake

# Or with more verbose output
cmake -P unit_tests/integration/cppcheck/test_configuration.cmake --debug-output
```

## Expected Output

All tests should PASS with output like:
```
-- === Cppcheck Integration Tests ===
-- Test 1: Cppcheck_Configure STATUS ON (advisory mode)
--   ✓ Cppcheck_Configure STATUS ON works (advisory mode)
-- Test 2: Cppcheck_Configure STATUS OFF
--   ✓ Cppcheck_Configure STATUS OFF works
...
-- All Cppcheck integration tests PASSED ✓
```

## Test Artifacts

Mock projects and build artifacts are created in:
- `${CMAKE_TOOLBOX_TEST_ARTIFACTS_ROOT}/integration_cppcheck/`

Default location: `build/test_artifacts/integration_cppcheck/`

Each test creates its own isolated mock project with:
- `CMakeLists.txt` - Test project configuration
- `.c` files - Test source code
- `build/` - CMake build directory
- `compile_commands.json` - For cppcheck to analyze

## Design Notes

- **Mock Projects**: Each test creates isolated, real CMake projects
- **Real Builds**: Each test executes `cmake --build` to verify tool integration
- **Build Verification**: Confirms Cppcheck runs (or doesn't run) as configured
- **Advisory Mode**: Tests pass even when cppcheck tool is not installed
- **Strict Mode**: Tests verify fatal errors when STRICT flag used without tool
- **Idempotency**: Configuration can be called multiple times safely
- **No Side Effects**: Tests clean up after themselves

## Features Tested

✅ Global configuration (Advisory and Strict modes)
✅ Per-target configuration with granular control
✅ Check enable/suppress parameters
✅ Mixed C/C++ projects
✅ Tool detection and graceful fallback
✅ Multiple enable/disable cycles
✅ TARGET and STATUS parameter validation
