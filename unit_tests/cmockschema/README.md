# CMockSchema Unit Tests

Unit tests for the `CMockSchema.cmake` module.

## Module Under Test

`cmake/CMockSchema.cmake` - Provides template-based CMock configuration generation.

## Functions Tested

| Function | Test File |
|----------|-----------|
| `CMockSchema_SetDefaults` | `test_set_defaults.cmake` |
| `CMockSchema_GenerateConfigFile` | `test_generate_config.cmake` |

## Running Tests

```bash
# Run all CMockSchema tests
ctest -R "cmockschema_"

# Run a specific test
ctest -R "cmockschema_generate_config" -V

# Run with verbose output
ctest -R "cmockschema_" --output-on-failure
```

## Test Coverage

- **Happy paths**: Valid inputs produce expected outputs
- **Error paths**: Invalid inputs correctly trigger FATAL_ERROR
- **Edge cases**: Template rendering and custom overrides
