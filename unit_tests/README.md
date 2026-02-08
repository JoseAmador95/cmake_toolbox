# Test Suites

This directory contains both script-mode unit tests and project-mode integration tests for `cmake_toolbox` modules.

## Directory Layout

- `policy/`, `clangformat/`, `clangtidy/`, `compilecommands/`, `gcov/`, `gcovrschema/`, `cmockschema/`, `findunity/`, `sanitizer/`: module-focused unit tests (mostly `cmake -P` script mode)
- `discover_tests/`: script-level verification for `DiscoverTests.cmake`, including paths with spaces and special characters
- `integration/clangformat/`, `integration/compilecommands/`, `integration/gcov/`, `integration/sanitizer/`, `integration/clangtidy/`, `integration/consumption/`: project-mode integration tests that configure/build mini CMake projects and assert observable outputs

## Testing Strategy

- Prefer behavior assertions over configure-only checks (for example, build custom targets, verify generated artifacts, inspect transformed output files)
- Keep failures deterministic and actionable (tests should fail with explicit missing artifact/output messages)
- Gate tool-dependent checks (`jq`, `clang-format`, compiler-specific coverage support) with clear skip messages instead of silent pass-through
- Use integration tests when functionality relies on CMake project context (`add_custom_command`, `add_custom_target`, target properties, generated build artifacts)
- Script and integration tests write temporary artifacts under `${CMAKE_BINARY_DIR}/test_artifacts` to keep repository roots clean
- In script-mode tests, prefer `list(FIND ...)` over `IN_LIST` to avoid dependence on CMP0057 policy state

## Unity Module Note

`Unity_Initialize()`, `Unity_GenerateMock()`, `Unity_GenerateRunner()`, and `Unity_CreateTestTarget()` are not fully unit-testable in pure script mode because they depend on project-mode operations and external tooling.

`FindUnity.cmake` also requires real `find_package()` behavior and environment-dependent lookup logic, so script-mode coverage is intentionally limited.

## Local Reproduction

```bash
# Full configure/build/test cycle (matches CI baseline)
cmake -S . -B build -DCMAKE_TOOLBOX_BUILD_EXAMPLES=ON
cmake --build build
ctest --test-dir build --output-on-failure

# Run focused suites
ctest --test-dir build --output-on-failure -R "compilecommands|integration_compilecommands"
ctest --test-dir build --output-on-failure -R "integration_clangformat"
ctest --test-dir build --output-on-failure -R "integration_gcov"
```

## CI Enforcement

GitHub Actions runs on every pull request and push to `main`:

- `test-linux`: configure, build, full `ctest` execution
- `test-macos`: configure, build, core test matrix execution
- `lint-basic`: install/configuration sanity checks

Failed test jobs upload CTest logs as artifacts for debugging.
