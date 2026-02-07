# CMockSchema Unit Tests

Unit tests for the `CMockSchema.cmake` module.

## Module Under Test

`cmake/CMockSchema.cmake` - Provides version-aware CMock configuration schema management.

## Functions Tested

| Function | Test File |
|----------|-----------|
| `CMockSchema_GetSupportedVersions` | `test_supported_versions.cmake` |
| `CMockSchema_DetectVersion` | `test_detect_version.cmake` |
| `CMockSchema_SetDefaults` | `test_set_defaults.cmake` |
| `CMockSchema_GenerateConfigFile` | `test_generate_config.cmake` |

## Running Tests

```bash
# Run all CMockSchema tests
ctest -R "cmockschema_"

# Run a specific test
ctest -R "cmockschema_detect_version" -V

# Run with verbose output
ctest -R "cmockschema_" --output-on-failure
```

## Test Coverage

- **Happy paths**: Valid inputs produce expected outputs
- **Error paths**: Invalid inputs correctly trigger FATAL_ERROR
- **Edge cases**: Version parsing from tags and executables
