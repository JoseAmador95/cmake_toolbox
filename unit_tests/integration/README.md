# Integration Tests

Integration tests that verify module behavior with real projects, compilers, and tools.

## Test Structure

```
integration/
├── gcov/
│   ├── test_schema_defaults.cmake     # SCHEMA mode with GCC/Clang defaults
│   ├── test_schema_thresholds.cmake   # Threshold enforcement ON/OFF
│   ├── test_config_file_mode.cmake    # External config file mode
│   └── test_compiler_compat.cmake     # GCC/Clang build verification
├── sanitizer/
│   ├── test_combinations.cmake        # ASan/UBSan/LSan combinations
│   └── test_build.cmake               # Actual build with sanitizers
├── clangtidy/
│   └── test_configuration.cmake       # Global/per-target config, tool missing
├── clangformat/
│   └── test_configuration.cmake       # Basic config, exclusions, tool missing
├── ctest/
│   └── test_junit_output.cmake         # JUnit output capture with custom size limits
├── compilecommands/
│   └── test_trim.cmake                # compile_commands trim behavior
├── findunity/
│   └── test_find_package.cmake        # find_package(Unity) hint/layout coverage
├── unity/
│   └── test_cmock_memory.cmake         # Unity_Initialize applies CMock memory defines
└── consumption/
    ├── test_add_subdirectory.cmake    # Consume toolbox as vendored source
    ├── test_fetchcontent.cmake        # Consume toolbox via FetchContent
    └── test_find_package.cmake        # Consume installed package via find_package
```

## Running Integration Tests

```bash
# From build directory
ctest -R "integration_" --output-on-failure

# Run specific module tests
ctest -R "integration_gcov" --output-on-failure
ctest -R "integration_sanitizer" --output-on-failure
ctest -R "integration_consumption" --output-on-failure
```

## Test Coverage Matrix

| Module | GCC | Clang | Tool Missing | Feature Combos |
|--------|-----|-------|--------------|----------------|
| Gcov | ✓ | ✓ | N/A (required) | SCHEMA/CONFIG_FILE modes |
| Sanitizer | ✓ | ✓ | N/A | ASan/UBSan/LSan combinations |
| ClangTidy | ✓ | ✓ | ✓ | Global/Per-target |
| ClangFormat | ✓ | ✓ | ✓ | Exclusions |
| CTest | ✓ | ✓ | N/A | JUnit output capture |
| CompileCommands | - | - | N/A | Trim |
| FindUnity | ✓ | ✓ | N/A | Hint resolution / layout validation |
| Unity | ✓ | ✓ | N/A | CMock memory definitions |
| Consumption | ✓ | ✓ | N/A | add_subdirectory / FetchContent / find_package |

## Notes

- Tests that require specific compilers will skip if the compiler is not found
- Tests that require optional tools (clang-tidy, clang-format) will verify graceful handling when missing
- Integration tests create temporary projects in `${CMAKE_BINARY_DIR}/integration_*`
