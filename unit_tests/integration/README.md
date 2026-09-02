# Integration Tests

Integration tests that verify module behavior with real projects, compilers, and tools.

Each file is a `cmake -P` script that generates a small project under
`${CMAKE_BINARY_DIR}/test_artifacts/...`, configures/builds it with a real toolchain, and asserts on
the observable result. They are registered automatically as `integration_<module>_<name>` with the
labels `integration;<module>` — see [../README.md](../README.md#how-tests-are-registered).

## Test Structure

```
integration/
├── ceedling/
│   └── test_gcovr_post_run.cmake       # gcovr_unit CTest fixture: runs once, after the unit tests
├── compilecommands/
│   └── test_trim.cmake                 # compile_commands trim behavior
├── consumption/
│   ├── test_add_subdirectory.cmake     # Consume toolbox as vendored source
│   ├── test_fetchcontent.cmake         # Consume toolbox via FetchContent
│   └── test_find_package.cmake         # Consume installed package via find_package
├── ctest/
│   └── test_junit_output.cmake         # JUnit output capture with custom size limits
├── findunity/
│   └── test_find_package.cmake         # find_package(Unity) hint/layout coverage
├── gcov/
│   ├── test_compiler_compat.cmake      # GCC/Clang coverage flag verification
│   ├── test_config_file_mode.cmake     # External CMT_GCOVR_CONFIG_FILE mode
│   ├── test_generated_config.cmake     # Generated gcovr.cfg from CMT_GCOVR_* variables
│   └── test_report_generation.cmake    # End-to-end report generation with the real gcovr
├── sanitizer/
│   ├── test_build.cmake                # Actual build and run with sanitizers
│   └── test_combinations.cmake         # ASan/UBSan/LSan combinations
└── unity/
    └── test_cmock_memory.cmake         # Unity_Initialize applies CMock memory defines
```

## Running Integration Tests

```bash
# From build directory
ctest -R "integration_" --output-on-failure

# Run specific module tests
ctest -R "integration_ceedling" --output-on-failure
ctest -R "integration_gcov" --output-on-failure
ctest -R "integration_sanitizer" --output-on-failure
ctest -R "integration_consumption" --output-on-failure
```

## Test Coverage Matrix

| Module | GCC | Clang | Tool Missing | Feature Combos |
|--------|-----|-------|--------------|----------------|
| Ceedling | ✓ | ✓ | Uses a mock gcovr; skips on MSVC | gcovr post-run fixture on/off, per-function discovery |
| Gcov | ✓ | ✓ | `test_report_generation` skips without a real gcovr | Generated/CONFIG_FILE modes, report generation |
| Sanitizer | ✓ | ✓ | N/A | ASan/UBSan/LSan combinations |
| CTest | ✓ | ✓ | N/A | JUnit output capture |
| CompileCommands | ✓ | ✓ | N/A | Trim (skipped on multi-config generators) |
| FindUnity | ✓ | ✓ | N/A | Hint resolution / layout validation |
| Unity | ✓ | ✓ | N/A | CMock memory definitions |
| Consumption | ✓ | ✓ | N/A | add_subdirectory / FetchContent / find_package |

## Notes

- Tests that require specific compilers will skip if the compiler is not found
- Tests that require optional tools (for example `clang-tidy`) skip gracefully when missing, unless the matching `CMAKE_TOOLBOX_REQUIRE_*` option is ON
- The Ceedling and Unity suites need Ruby on `PATH`, like the module itself
- Integration tests create temporary projects under `${CMAKE_BINARY_DIR}/test_artifacts`
