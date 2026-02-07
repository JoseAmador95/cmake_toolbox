# Sanitizer Module Tests

This directory contains tests for the Sanitizer.cmake module.

## Test Coverage

### Integration Test (CMakeLists.txt)

Tests the Sanitizer module in a real CMake project context:

- Compiler detection and automatic flag configuration
- Application of sanitizer flags via `Sanitizer_AddToTarget`
- Verification of `COMPILE_OPTIONS` and `INTERFACE_COMPILE_OPTIONS`
- Verification of `LINK_OPTIONS` and `INTERFACE_LINK_OPTIONS`
- Verification of `ENVIRONMENT` property
- Compiler-specific flag validation (GNU/Clang vs MSVC)

**Test approach:**
- Creates a dummy library target
- Applies sanitizer instrumentation with PUBLIC scope
- Queries target properties and validates they match expected values
- Validates compiler-specific flag syntax

## Running Tests

From the build directory:

```bash
# Run all sanitizer tests
ctest -R "sanitizer" --verbose

# Run manually
cmake -S unit_tests/sanitizer -B build-sanitizer-test
cmake --build build-sanitizer-test
```

## Expected Behavior

- **GNU/Clang/AppleClang/MinGW**: Should use `-fsanitize=address,undefined,leak`
- **MSVC/Clang-cl**: Should use `/fsanitize=address`
- **Unsupported compilers**: Should FATAL_ERROR if SANITIZER_FLAGS not set manually

The test validates that:
1. Flags are applied to both compile and link stages
2. PUBLIC scope propagates to both direct and interface properties
3. Environment variables are set correctly
4. Compiler-specific syntax is correct
