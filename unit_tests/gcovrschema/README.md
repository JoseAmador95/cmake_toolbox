# GcovrSchema Unit Tests

Unit tests for the `GcovrSchema.cmake` module.

## Module Under Test

`cmake/GcovrSchema.cmake` - Provides capability-based gcovr configuration schema management.

## Functions Tested

| Function | Test File |
|----------|-----------|
| `GcovrSchema_DetectCapabilities` | `test_supported_versions.cmake` |
| `GcovrSchema_SetDefaults` | `test_set_defaults.cmake` |
| `GcovrSchema_GenerateConfigFile` | `test_generate_config.cmake` |
| `GcovrSchema_Validate` | `test_validate.cmake` |

## Running Tests

```bash
# Run all GcovrSchema tests
ctest -R "gcovrschema_"

# Run a specific test
ctest -R "gcovrschema_validate" -V

# Run with verbose output
ctest -R "gcovrschema_" --output-on-failure
```

## Test Coverage

- **Happy paths**: Valid inputs produce expected outputs
- **Error paths**: Invalid inputs correctly trigger FATAL_ERROR
- **Edge cases**: Boundary values, empty inputs, version compatibility
