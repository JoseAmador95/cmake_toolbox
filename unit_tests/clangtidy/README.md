# ClangTidy Unit Tests

Unit tests for the `ClangTidy.cmake` module.

## Module Under Test

`cmake/ClangTidy.cmake` - Provides functions to configure clang-tidy static analysis.

## Functions Tested

| Function | Test File |
|----------|-----------|
| `ClangTidy_Configure` | `test_configure_global.cmake` |
| `ClangTidy_ConfigureTarget` | `test_configure_target.cmake` |
| `.clang-tidy` config validation | `test_config_file_valid.cmake` |
| `FindClangTidy` version support (10-22) | `test_find_clangtidy_supported_versions.cmake` |

## Running Tests

```bash
# Run all ClangTidy tests
ctest -R "clangtidy_"

# Run a specific test
ctest -R "clangtidy_configure_global" -V

# Run with verbose output
ctest -R "clangtidy_" --output-on-failure
```

## Test Coverage

- **Happy paths**: Valid inputs produce expected behavior
- **Error paths**: Missing parameters trigger FATAL_ERROR
- **Integration**: Target configuration in mock projects
- **Config validation**: `.clang-tidy` validated with `--verify-config` (baseline clang-tidy 18)
- **Version support**: Finder behavior validated for clang-tidy 10..22

## Notes

- `ClangTidy_Configure` modifies CMAKE_C_CLANG_TIDY and CMAKE_CXX_CLANG_TIDY cache variables
- `ClangTidy_ConfigureTarget` requires an actual target, so tests use a mock project
- Some tests run in subprocess to test project-mode behavior
