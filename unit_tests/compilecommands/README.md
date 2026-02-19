# CompileCommands Unit Tests

Unit tests for the `CompileCommands.cmake` module.

## Module Under Test

`cmake/CompileCommands.cmake` - Provides functions to manipulate compile_commands.json files.

## Functions Tested

| Function | Test File |
|----------|-----------|
| `CompileCommands_Trim` | `test_trim_basic.cmake`, `test_trim_error_handling.cmake` |
| Blacklist filtering | `test_trim_blacklist.cmake` |
| Clang-Tidy compatibility | `test_trim_clangtidy_compat.cmake` |

## Running Tests

```bash
# Run all CompileCommands tests
ctest -R "compilecommands_"

# Run a specific test
ctest -R "compilecommands_trim_basic" -V

# Run blacklist tests
ctest -R "compilecommands_trim_blacklist" -V

# Run with verbose output
ctest -R "compilecommands_" --output-on-failure
```

## Test Coverage

- **Happy paths**: Valid INPUT/OUTPUT produces expected behavior
- **Error paths**: Missing parameters trigger FATAL_ERROR
- **Edge cases**: Nested output directories are created
- **Blacklist**: ARM GCC, GCC modules, GCC warnings, user-defined patterns
- **Clang-Tidy compatibility**: Trimmed databases accepted by clang-tidy

## Blacklist Tests

The `test_trim_blacklist.cmake` verifies:

1. **ARM-specific flags removed**: `-mcpu`, `-mthumb`, `-mfloat-abi`, `-mfpu`
2. **GCC modules flags removed**: `-fmodules-ts`, `-fmodule-mapper`, `-fdeps-format`
3. **GCC warning flags removed**: `-Wformat-signedness`, `-Wsuggest-override`, etc.
4. **User blacklist works**: Custom patterns via `COMPILE_COMMANDS_TRIM_BLACKLIST`
5. **Safe flags preserved**: `-std`, `-fno-exceptions`, `-fPIC`, `-pthread`, `-D`, `-I`

## Clang-Tidy Compatibility Tests

The `test_trim_clangtidy_compat.cmake` verifies that clang-tidy accepts trimmed databases:

1. **ARM GCC compile commands**: After trim, no "unknown argument" errors
2. **GCC modules compile commands**: After trim, clang-tidy can parse
3. **Preserved flags work**: Analysis flags like `-fno-exceptions` are usable

## Notes

- `CompileCommands_Trim` creates a custom command in project mode
- Tests are run as integration tests (cmake -S -B) to test project-mode behavior
- The trim helper runs as a build-time custom command
- Clang-Tidy compatibility tests require clang-tidy to be installed
