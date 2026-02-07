# Gcov Module Tests

This directory contains tests for the Gcov.cmake module.

## Test Coverage

### Integration Test (CMakeLists.txt)

Tests the Gcov module in a real CMake project context:

- Compiler detection and automatic flag configuration
- Application of coverage flags via `Gcov_AddToTarget`
- Verification of `COMPILE_OPTIONS` and `INTERFACE_COMPILE_OPTIONS`
- Verification of `LINK_OPTIONS` and `INTERFACE_LINK_OPTIONS`
- Compiler-specific behavior validation
- MSVC/Clang-cl handling (empty flags with warning)

**Test approach:**
- Creates a dummy library target
- Applies coverage instrumentation with PUBLIC scope
- Queries target properties and validates they match expected values
- Validates compiler-specific behavior

## Running Tests

From the build directory:

```bash
# Run all gcov tests
ctest -R "gcov" --verbose

# Run manually
cmake -S unit_tests/gcov -B build-gcov-test
cmake --build build-gcov-test
```

## Expected Behavior

- **GNU/Clang/AppleClang/MinGW**: Should use `--coverage` for both compile and link
- **MSVC/Clang-cl**: Should emit WARNING and use empty flags (no FATAL_ERROR)
- **Unsupported compilers**: Should FATAL_ERROR if flags not set manually

The test validates that:
1. Flags are applied to both compile and link stages (when non-empty)
2. PUBLIC scope propagates to both direct and interface properties
3. MSVC correctly has empty flags (with warning during module load)
4. Compiler-specific behavior is correct
