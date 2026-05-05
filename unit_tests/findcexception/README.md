# FindCException Module Unit Tests

Tests for the `FindCException` CMake find module.

## Test Files

- `test_find_cexception.cmake` — Verifies `find_package(CException QUIET)` completes without
  error regardless of whether CException is installed. If found, validates that result variables
  (`CException_INCLUDE_DIR`, `CException_SOURCE`) are set.

## Running

```sh
cmake -P unit_tests/findcexception/test_find_cexception.cmake
```

Or via CTest after configuring the examples directory:

```sh
ctest -L findcexception
```
