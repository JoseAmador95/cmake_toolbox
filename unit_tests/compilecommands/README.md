# CompileCommands Unit Tests

Unit tests for the `CompileCommands.cmake` module.

## Module Under Test

`cmake/CompileCommands.cmake` - Provides functions to manipulate compile_commands.json files.

## Functions Tested

| Function | Test File |
|----------|-----------|
| `CompileCommands_Trim` | `test_trim_basic.cmake`, `test_trim_error_handling.cmake` |

## Running Tests

```bash
# Run all CompileCommands tests
ctest -R "compilecommands_"

# Run a specific test
ctest -R "compilecommands_trim_basic" -V

# Run with verbose output
ctest -R "compilecommands_" --output-on-failure
```

## Test Coverage

- **Happy paths**: Valid INPUT/OUTPUT produces expected behavior
- **Error paths**: Missing parameters trigger FATAL_ERROR
- **Edge cases**: Missing jq executable emits warning

## Notes

- `CompileCommands_Trim` creates a custom command in project mode
- Tests are run as integration tests (cmake -S -B) to test project-mode behavior
- If jq is not found, the function emits a WARNING but doesn't fail
