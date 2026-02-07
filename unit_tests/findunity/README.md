# FindUnity.cmake Tests

This directory contains unit tests for the FindUnity.cmake module's hint variable handling.

## Test Coverage

### test_hint_safety.cmake

Tests the fix for **Issue #10** - unsafe if() expansion for optional hints.

**Test scenarios:**
1. Undefined hint variables (Unity_ROOT, UNITY_ROOT not set)
2. Empty hint variables (set to "")
3. Valid hint paths
4. Mixed defined/undefined hints
5. Hints with special characters (spaces, semicolons)
6. Environment variable hints (ENV{UNITY_ROOT})

**Important:** These tests verify the **internal hint processing logic** only. They do not test the full `find_package(Unity)` functionality, which requires a complete CMake project context.

## Running Tests

```bash
# Run from build directory
ctest -R findunity

# Or run directly
cmake -P unit_tests/findunity/test_hint_safety.cmake
```

## Why Limited Testing?

The full FindUnity.cmake module cannot be tested in script mode because:
- `find_package()` requires a real CMake project context
- Find module logic depends on CMake search paths and system introspection
- `add_library()` and other project commands don't work in script mode

These tests focus on the **specific bug fix** (safe variable expansion) rather than the complete find module behavior.
