# Test Suites

This directory contains both script-mode unit tests and project-mode integration tests for `cmake_toolbox` modules.

## Directory Layout

- `policy/`, `compilecommands/`, `gcov/`, `cmockschema/`, `findunity/`, `sanitizer/`: module-focused unit tests (mostly `cmake -P` script mode)
- `discover_tests/`: script-level verification for `DiscoverTests.cmake`, including paths with spaces and special characters
- `integration/ceedling/`, `integration/compilecommands/`, `integration/consumption/`, `integration/ctest/`, `integration/findunity/`, `integration/gcov/`, `integration/sanitizer/`, `integration/unity/`: project-mode integration tests that configure/build mini CMake projects and assert observable outputs (see [integration/README.md](integration/README.md))

## How Tests Are Registered

There is no `CMakeLists.txt` in this directory. The tests are registered by
[`examples/CMakeLists.txt`](../examples/CMakeLists.txt), which is added by the root project when
`CMAKE_TOOLBOX_BUILD_EXAMPLES=ON` (the default for a top-level build).

For each module it does a configure-time glob and turns every matching file into a CTest test that
re-invokes CMake in script mode:

```cmake
file(GLOB GCOV_TEST_FILES "${CMAKE_CURRENT_LIST_DIR}/../unit_tests/gcov/test_*.cmake")
foreach(test_file ${GCOV_TEST_FILES})
    get_filename_component(test_filename ${test_file} NAME_WE)
    string(REGEX REPLACE "^test_" "" test_name ${test_filename})
    add_test(NAME gcov_${test_name} COMMAND ${CMAKE_COMMAND} -P ${test_file})
    set_tests_properties(gcov_${test_name} PROPERTIES LABELS "script;gcov")
endforeach()
```

Consequences worth knowing:

- **Naming**: `unit_tests/<module>/test_<name>.cmake` becomes the CTest test `<module>_<name>`, and
  `unit_tests/integration/<module>/test_<name>.cmake` becomes `integration_<module>_<name>`.
- **Labels**: script-mode tests get `script;<module>`; integration tests get `integration;<module>`.
- **Adding a test is just adding a file** — but because `file(GLOB)` runs at configure time, a new
  file is only picked up after CMake re-configures.
- Most suites are passed the parent build's toolchain through `-D` flags
  (`CMAKE_TOOLBOX_TEST_GENERATOR`, `CMAKE_TOOLBOX_TEST_C_COMPILER`, `CMAKE_TOOLBOX_TEST_CXX_COMPILER`,
  `CMAKE_TOOLBOX_TEST_BUILD_TYPE`); scripts turn them back into configure arguments with
  `TestHelpers_GetConfigureArgs()` from [`cmake/TestHelpers.cmake`](../cmake/TestHelpers.cmake).
- Some suites are skipped by the generator/toolchain: `compilecommands` on multi-config generators,
  `gcov` on MSVC toolchains.

## Testing Strategy

- Prefer behavior assertions over configure-only checks (for example, build custom targets, verify generated artifacts, inspect transformed output files)
- Keep failures deterministic and actionable (tests should fail with explicit missing artifact/output messages)
- Gate tool-dependent checks (`clang-tidy`, compiler-specific coverage support) with clear skip messages instead of silent pass-through. When a CI leg installs the tool, set the matching `CMAKE_TOOLBOX_REQUIRE_*` option (for example `CMAKE_TOOLBOX_REQUIRE_CLANG_TIDY=ON`) so the skip becomes a hard failure and the test cannot go silently inert
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
ctest --test-dir build --output-on-failure -R "integration_gcov"
```

Ruby must be on `PATH`: the example Ceedling test built by `examples/CMakeLists.txt` needs Unity's
and CMock's Ruby generators.

## Labels and JUnit Output

- Ceedling tests carry the labels in `CMT_CEEDLING_TEST_LABELS` (default `ceedling;unit`) plus any
  `LABELS` passed to `Ceedling_AddUnitTest`.
- When `CMT_CEEDLING_ENABLE_GCOV=ON`, gcovr runs after the unit tests by default via the
  `gcovr_unit` CTest fixture. Disable with `-DCMT_CEEDLING_GCOVR_POST_RUN=OFF`. See
  [docs/ceedling.md](../docs/ceedling.md#coverage-integration).
- Script-mode tests use labels `script` and the module name.
- Integration tests use labels `integration` and the module name.

```bash
ctest --test-dir build -L unit
ctest --test-dir build -LE unit
ctest --test-dir build -L integration
ctest --test-dir build --output-junit build/junit.xml
ctest --test-dir build --output-junit build/junit.xml --test-output-size-passed 200000
ctest --test-dir build --output-junit build/junit.xml --test-output-size-failed 400000
```

JUnit output limits are defined by the project (CLI or presets). Defaults are 1024 bytes for passed
tests and 300 KiB for failed tests when no limits are specified.

## CI Enforcement

GitHub Actions ([`.github/workflows/ci.yml`](../.github/workflows/ci.yml)) runs on every pull
request and on pushes to `main`. There are four jobs.

### `test` — full suite across toolchains

Configures with `-DCMAKE_TOOLBOX_BUILD_EXAMPLES=ON`, builds, and runs the whole suite with
`ctest --output-on-failure -j`.

| Leg | OS / toolchain | Extra flags |
|-----|----------------|-------------|
| `linux-baseline` | Ubuntu (GCC) | `CMAKE_TOOLBOX_REQUIRE_CLANG_TIDY=ON` (installs `clang-tidy`, so the CompileCommands compatibility test cannot skip) |
| `linux-gcov` | Ubuntu (GCC) | `CMT_CEEDLING_ENABLE_GCOV=ON` |
| `linux-sanitizer` | Ubuntu (GCC) | `CMT_CEEDLING_ENABLE_SANITIZER=ON` |
| `linux-gcov-sanitizer` | Ubuntu (GCC) | both |
| `linux-clang-baseline` | Ubuntu (Clang) | defaults |
| `linux-clang-gcov` | Ubuntu (Clang) | `CMT_CEEDLING_ENABLE_GCOV=ON` (installs `llvm` for `llvm-cov`) |
| `linux-clang-sanitizer` | Ubuntu (Clang) | `CMT_CEEDLING_ENABLE_SANITIZER=ON` |
| `linux-clang-gcov-sanitizer` | Ubuntu (Clang) | both |
| `macos-baseline` | macOS (AppleClang) | defaults |
| `macos-sanitizer` | macOS (AppleClang) | `CMT_CEEDLING_ENABLE_SANITIZER=ON` |
| `windows-msvc-baseline` | Windows (MSVC) | `--config Debug` |
| `windows-msvc-sanitizer` | Windows (MSVC) | `CMT_CEEDLING_ENABLE_SANITIZER=ON`, `--config Debug`, ASan runtime added to `PATH` |
| `windows-mingw-baseline` | Windows (MinGW Makefiles, gcc/g++) | defaults |
| `windows-mingw-gcov` | Windows (MinGW Makefiles, gcc/g++) | `CMT_CEEDLING_ENABLE_GCOV=ON` |

Every leg also runs a **"tests do not mutate source tree"** check (`git status --porcelain` must be
empty afterwards), and uploads `build/Testing/Temporary/LastTest.log` as an artifact on failure.

### `lint-basic`

Configures with `-DCMAKE_TOOLBOX_BUILD_EXAMPLES=OFF` and runs `cmake --install`, validating the
install rules of the module-only project.

### `generator-matrix`

Configures and builds with `-DCMAKE_TOOLBOX_BUILD_EXAMPLES=ON` under each generator below, then runs
`ctest -L "ceedling|unity|findunity|gcov|sanitizer"`. Ruby is provisioned with `ruby/setup-ruby`.

| Leg | OS | Generator | Config |
|-----|----|-----------|--------|
| `linux-ninja` | Ubuntu | Ninja | single |
| `linux-makefiles` | Ubuntu | Unix Makefiles | single |
| `linux-ninja-multi` | Ubuntu | Ninja Multi-Config | Debug |
| `macos-ninja` | macOS | Ninja | single |
| `macos-makefiles` | macOS | Unix Makefiles | single |
| `macos-ninja-multi` | macOS | Ninja Multi-Config | Debug |
| `macos-xcode` | macOS | Xcode | Debug |
| `windows-ninja` | Windows | Ninja | single |
| `windows-ninja-multi` | Windows | Ninja Multi-Config | Debug |
| `windows-vs2026` | Windows | Visual Studio 18 2026 | Debug |

### `unity-cmock-versions`

Ubuntu + Ninja, pinning the dependency versions with `-DCMT_UNITY_GIT_TAG` / `-DCMT_CMOCK_GIT_TAG`,
then running `ctest -L "ceedling|unity|findunity"`.

| Leg | Unity | CMock |
|-----|-------|-------|
| `unity-2.6.1-cmock-2.6.0` | `v2.6.1` | `v2.6.0` |
| `unity-2.5.2-cmock-2.5.2` | `v2.5.2` | `v2.5.2` |
| `unity-2.4.3-cmock-2.4.3` | `v2.4.3` | `v2.4.3` |
