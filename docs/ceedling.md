# Ceedling-style unit testing

`Ceedling.cmake` is the headline module of `cmake_toolbox`. It gives you the ergonomics of
[Ceedling](https://github.com/ThrowTheSwitch/Ceedling) — write a `test_*.c`, `#include` the mocks you
want, run the tests — while keeping the build in plain CMake and the test registry in CTest.

For one test source it:

1. Creates an executable from the test source and links it against the target under test,
   `Unity::Unity` and `Unity::CMock`.
2. Runs Unity's Ruby runner generator on the test source and adds the generated runner to the
   executable.
3. Scans the test source for `#include "mock_<name>.h"`, resolves `<name>.h` on the include path of
   the target under test, and runs CMock's Ruby generator on every header it found.
4. Optionally adds coverage and/or sanitizer instrumentation.
5. Registers the result with CTest (one test per file, or one test per test function).

Prerequisite: **Ruby must be on `PATH`** — both generators are Ruby scripts and
`Unity.cmake` does `find_program(Ruby_EXECUTABLE ruby REQUIRED)`.

See [consumption.md](consumption.md) for how to make `include(Ceedling)` resolvable in your project.

## `Ceedling_AddUnitTest`

```cmake
Ceedling_AddUnitTest(
  NAME <test_name>
  UNIT_TEST <test_source>
  TARGET <target_under_test>
  [LABELS <label>...]
  [ENABLE_SANITIZER]
  [DISABLE_SANITIZER]
)
```

| Argument | Kind | Required | Meaning |
|---|---|---|---|
| `NAME` | one value | yes | Name of both the test executable target and the CTest test. |
| `UNIT_TEST` | one value | yes | Path to the test source file. Use an absolute path (for example `${CMAKE_CURRENT_SOURCE_DIR}/unit_test/test_foo.c`); the module checks the file with `if(EXISTS ...)`, whose behaviour on relative paths is unspecified. |
| `TARGET` | one value | yes | The CMake target under test. It is linked into the test executable, and its include directories (plus those of its transitive dependencies) are searched when resolving mock headers. |
| `LABELS` | multi value | no | Extra CTest labels, appended to `CMT_CEEDLING_TEST_LABELS`. Duplicates are removed. |
| `ENABLE_SANITIZER` | option | no | Force sanitizer instrumentation for this test when `CMT_CEEDLING_SANITIZER_DEFAULT=OFF`. |
| `DISABLE_SANITIZER` | option | no | Suppress sanitizer instrumentation for this test when `CMT_CEEDLING_SANITIZER_DEFAULT=ON`. |

Passing both `ENABLE_SANITIZER` and `DISABLE_SANITIZER` is a `FATAL_ERROR`. So is omitting any of
`NAME`, `UNIT_TEST` or `TARGET`.

Minimal use:

```cmake
include(Ceedling)

add_library(example STATIC ${CMAKE_CURRENT_SOURCE_DIR}/source/example.c)
target_include_directories(example PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/include)

Ceedling_AddUnitTest(
    NAME example_test
    UNIT_TEST ${CMAKE_CURRENT_SOURCE_DIR}/unit_test/test_example.c
    TARGET example
)
```

Generated files land in `${CMAKE_CURRENT_BINARY_DIR}/<NAME>.dir/`:

```
<NAME>.dir/
├── cmock.yml                 # rendered CMock config used for this test
├── mocks/                    # mock_<name>.c / mock_<name>.h  (CMT_CMOCK_MOCK_SUBDIR)
└── runners/
    └── test_example_runner.c
```

`<NAME>.dir/mocks` is added to the test executable's private include directories, which is why
`#include "mock_dependency.h"` resolves without any extra configuration.

## Automatic mock detection

You never pass a list of headers to mock. `_Ceedling_ParseMockIncludes` reads the test source and
matches every include of the form

```
#include "mock_<name>.h"     /* also <mock_<name>.h> and .hpp */
```

against the configured mock prefix (`CMT_CMOCK_MOCK_PREFIX`, default `mock_`), collecting `<name>`.
Duplicates are removed.

Each `<name>` is then resolved to a real header by `_Ceedling_ResolveHeader`, which tries
`<dir>/<name>.h` and `<dir>/<name>.hpp` in this order of directories:

1. `INCLUDE_DIRECTORIES` and `INTERFACE_INCLUDE_DIRECTORIES` of `TARGET`, then of every target
   reachable through its `LINK_LIBRARIES` / `INTERFACE_LINK_LIBRARIES` (a transitive walk).
   Entries that are generator expressions are skipped — they cannot be evaluated at configure time.
2. `${CMAKE_CURRENT_SOURCE_DIR}`
3. `${CMAKE_CURRENT_SOURCE_DIR}/include`
4. `${CMAKE_SOURCE_DIR}`
5. `${CMAKE_SOURCE_DIR}/include`

The first hit wins, and CMock is run on that header.

If no directory contains the header, configuration stops with a `FATAL_ERROR` that lists the mock it
came from and every directory that was searched:

```
_Ceedling_ResolveHeader: Could not find header 'dependency.h' or 'dependency.hpp'
Searched in directories:
  /path/one;/path/two
This header was detected from a mock include (mock_dependency.h) in the test file.
Make sure the header exists and the target's include directories are set correctly.
```

The usual causes are a typo in the mock include, or a header exposed with a `PRIVATE` include
directory (only `INCLUDE_DIRECTORIES` and `INTERFACE_INCLUDE_DIRECTORIES` of the target itself are
read, so a dependency that keeps its include path private is invisible), or an include directory
written as a generator expression.

## Known limitation: `TARGET` is linked whole

`Ceedling_AddUnitTest` links the **entire** `TARGET` library into the test executable. Real Ceedling
links only the single translation unit under test plus its mocks.

The consequence: **a mocked header must not have its implementation compiled into `TARGET`.** If
`test_example.c` mocks `dependency.h` while `dependency.c` is part of `TARGET`, the link step sees
both the real `dependency_malloc` and the mock's `dependency_malloc` and fails with duplicate
symbols for every mocked function.

The bundled example only works because `dependency` is a header-only `INTERFACE` library:

```cmake
add_library(example STATIC source/example.c)

add_library(dependency INTERFACE)                       # no dependency.c anywhere
target_include_directories(dependency INTERFACE include)
target_link_libraries(example PUBLIC dependency)
```

Workarounds, in order of preference:

- Keep the mocked collaborators out of the linked target: expose them as `INTERFACE` (header-only)
  libraries, or as separate libraries that `TARGET` does not link.
- Split the unit under test into its own small library that contains only the file being tested, and
  pass that as `TARGET`.
- Use `Unity_CreateTestTarget()` from [`Unity.cmake`](../cmake/Unity.cmake) instead, which takes an
  explicit `SOURCES` / `MOCK_HEADERS` / `LINK_LIBRARIES` list and therefore lets you link exactly the
  translation unit under test.

## Acquiring Unity and CMock

`include(Ceedling)` calls `Unity_Initialize()` once, which calls `find_package(Unity REQUIRED)`
([`FindUnity.cmake`](../cmake/FindUnity.cmake)). The search order is:

1. **An existing checkout**, looked up through these hints (each is searched with the suffixes
   `src`, `source`, `unity`, `unity/src`, `Unity`, `Unity/src`, `include`, `unity/include`):
   - `Unity_ROOT` (cache or normal variable)
   - `UNITY_ROOT` (cache or normal variable)
   - the `UNITY_ROOT` environment variable
   - plus CMake's normal search paths

   Both `unity.h` and `unity.c` must be found; there is no header-only mode. CMock (`cmock.h`,
   `cmock.c`, `cmock.rb`) and Unity's `generate_test_runner.rb` are located the same way.

2. **FetchContent fallback.** `Unity_Initialize()` sets `UNITY_FETCH=ON` before the
   `find_package`, so when no local Unity is found the repositories are cloned during configure.

Defaults and overrides for the fallback:

| Variable | Default | Purpose |
|---|---|---|
| `CMT_UNITY_GIT_REPOSITORY` | `https://github.com/ThrowTheSwitch/Unity.git` | Unity repository URL |
| `CMT_UNITY_GIT_TAG` | `v2.6.1` | Unity tag/commit to fetch |
| `CMT_CMOCK_GIT_REPOSITORY` | `https://github.com/ThrowTheSwitch/CMock.git` | CMock repository URL |
| `CMT_CMOCK_GIT_TAG` | `v2.6.0` | CMock tag/commit to fetch |

```bash
cmake -S . -B build -DCMT_UNITY_GIT_TAG=v2.5.2 -DCMT_CMOCK_GIT_TAG=v2.5.2
```

CI exercises Unity/CMock `2.6.1/2.6.0`, `2.5.2/2.5.2` and `2.4.3/2.4.3`.

Whichever route is taken, the result is the imported targets `Unity::Unity` and `Unity::CMock`,
which `Ceedling_AddUnitTest` links into every test.

> Note: `Unity_Initialize()` also accepts `CMT_UNITY_REPO` / `CMT_UNITY_TAG` / `CMT_CMOCK_REPO` /
> `CMT_CMOCK_TAG` keyword arguments, but they are currently not honoured (the function reads
> `ARG_UNITY_REPO`, not `ARG_CMT_UNITY_REPO`). Use the `CMT_*_GIT_*` variables above.

## `cmock.yml` and the `CMT_CMOCK_*` options

CMock is configured with a YAML file. This toolbox never hands your file to CMock directly: it
treats it as a **template** that is rendered with `configure_file(... @ONLY)` into
`<NAME>.dir/cmock.yml`, substituting the `@CMT_CMOCK_*_YAML@` placeholders computed from the cache
variables below. The shipped [`cmock.yml`](../cmock.yml) at the repository root is such a template.

`Ceedling_AddUnitTest` picks the template by taking the **first existing** path of:

1. `${CMAKE_SOURCE_DIR}/cmock.yml`
2. `${CMAKE_CURRENT_SOURCE_DIR}/cmock.yml`
3. `${CMAKE_CURRENT_BINARY_DIR}/cmock.yml`

If none exists, it prints `No cmock.yml found; using generated defaults` and falls back to the
template bundled with the toolbox (`cmake/../cmock.yml`, i.e. the file installed next to the
modules).

A custom template must keep the `@...@` placeholders it wants to remain configurable; a plain CMock
`cmock.yml` copied from another project will be used verbatim for anything it hard-codes.

### Options

Defaults are set by `CMockSchema_SetDefaults()` in
[`cmake/CMockSchema.cmake`](../cmake/CMockSchema.cmake); the memory options live in
[`cmake/Unity.cmake`](../cmake/Unity.cmake).

| Option | Type | Default | Effect |
|---|---|---|---|
| `CMT_CMOCK_MOCK_PREFIX` | STRING | `mock_` | Prefix of generated mock files. Also drives the `#include "<prefix><name>.h"` pattern used for auto-detection. |
| `CMT_CMOCK_MOCK_SUFFIX` | STRING | *(empty)* | Suffix of generated mock files. |
| `CMT_CMOCK_MOCK_PATH` | STRING | `mocks` | Subdirectory for generated mocks. Inside `Ceedling_AddUnitTest` the effective value is `CMT_CMOCK_MOCK_SUBDIR` (which the function defaults to `mocks`), so set `CMT_CMOCK_MOCK_SUBDIR` to move the directory for Ceedling tests; `CMT_CMOCK_MOCK_PATH` applies to direct `Unity_*` calls. |
| `CMT_CMOCK_INCLUDES` | STRING (list) | `unity.h` | Headers added to `:includes:` in the generated config. |
| `CMT_CMOCK_PLUGINS` | STRING (list) | `ignore;callback` | CMock plugins to enable (`ignore`, `callback`, `expect_any_args`, `array`, `return_thru_ptr`, ...). |
| `CMT_CMOCK_TREAT_AS` | STRING (list) | *(empty)* | Type treatments as `TYPE:TREATMENT` pairs, e.g. `uint8_t:HEX8;size_t:HEX32`. Malformed entries produce a warning and are skipped. |
| `CMT_CMOCK_WHEN_NO_PROTOTYPES` | STRING | `:warn` | `:ignore`, `:warn` or `:error`. A leading `:` is added if you omit it. |
| `CMT_CMOCK_ENFORCE_STRICT_ORDERING` | BOOL | `OFF` | Enforce the order of expected calls. |
| `CMT_CMOCK_CALLBACK_INCLUDE_COUNT` | BOOL | `ON` | Pass the call count to callbacks. |
| `CMT_CMOCK_CALLBACK_AFTER_ARG_CHECK` | BOOL | `OFF` | Run callbacks only after argument validation. |
| `CMT_CMOCK_INCLUDES_H_PRE_ORIG_HEADER` | STRING | *(empty)* | Text injected in the mock header before the original header include. |
| `CMT_CMOCK_INCLUDES_H_POST_ORIG_HEADER` | STRING | *(empty)* | Text injected in the mock header after the original header include. |
| `CMT_CMOCK_INCLUDES_C_PRE_HEADER` | STRING | *(empty)* | Text injected in the mock source before the header include. |
| `CMT_CMOCK_INCLUDES_C_POST_HEADER` | STRING | *(empty)* | Text injected in the mock source after the header include. |
| `CMT_CMOCK_MEM_DYNAMIC` | BOOL | `OFF` | Defines `CMOCK_MEM_DYNAMIC` on the CMock target, switching CMock to dynamic allocation. |
| `CMT_CMOCK_MEM_SIZE` | STRING | *(empty)* | Defines `CMOCK_MEM_SIZE=<value>` on the CMock target (static pool size, or growth increment in dynamic mode). Must be a positive integer or configuration fails. |

Example:

```cmake
set(CMT_CMOCK_PLUGINS "ignore;callback;expect_any_args" CACHE STRING "" FORCE)
set(CMT_CMOCK_TREAT_AS "uint8_t:HEX8;uint16_t:HEX16" CACHE STRING "" FORCE)
set(CMT_CMOCK_MEM_SIZE "65536" CACHE STRING "" FORCE)

include(Ceedling)
```

Set these **before** `include(Ceedling)`: the module initialises Unity, and therefore the schema
defaults, at include time.

## `CMT_CEEDLING_*` options

Declared at the top of [`cmake/Ceedling.cmake`](../cmake/Ceedling.cmake).

| Option | Type | Default | Effect |
|---|---|---|---|
| `CMT_CEEDLING_ENABLE_GCOV` | BOOL | `OFF` | Includes `Gcov.cmake` and instruments both the test executable (`PRIVATE`) and the target under test (`PUBLIC`) with `--coverage`. |
| `CMT_CEEDLING_GCOVR_POST_RUN` | BOOL | `ON` when `CMT_CEEDLING_ENABLE_GCOV=ON`, else `OFF` | Registers the `gcovr_unit` CTest fixture so the coverage report is generated after the unit tests. |
| `CMT_CEEDLING_ENABLE_SANITIZER` | BOOL | `OFF` | Includes `Sanitizer.cmake` and makes sanitizer instrumentation available to tests. |
| `CMT_CEEDLING_SANITIZER_DEFAULT` | BOOL | `ON` | Whether tests are instrumented by default when sanitizers are enabled (see below). |
| `CMT_CEEDLING_EXTRACT_FUNCTIONS` | BOOL | `OFF` | Register each Unity test function as its own CTest test instead of one test per file. |
| `CMT_CEEDLING_TEST_LABELS` | STRING (list) | `ceedling;unit` | Labels applied to every Ceedling test. |

```bash
cmake -S . -B build -DCMT_CEEDLING_ENABLE_GCOV=ON -DCMT_CEEDLING_ENABLE_SANITIZER=ON
ctest --test-dir build -L ceedling
```

### One test per function

With `CMT_CEEDLING_EXTRACT_FUNCTIONS=ON`:

- `Unity_Initialize()` is called with `ENABLE_CEEDLING`, which sets `:cmdline_args: true` in the
  rendered `cmock.yml` and adds `UNITY_USE_COMMAND_LINE_ARGS` to the Unity target, so the generated
  runner can list and filter test functions.
- After each test executable is built, a `POST_BUILD` step runs
  [`DiscoverTests.cmake`](../cmake/DiscoverTests.cmake) with `cmake -P`, which queries the
  executable for its test names and writes an `add_test()` per function into
  `<NAME>_tests.cmake`, hooked into the directory's `TEST_INCLUDE_FILES`.
- Labels, sanitizer environment and the coverage fixture are propagated to each discovered test.

## Coverage integration

```bash
cmake -S . -B build -DCMT_CEEDLING_ENABLE_GCOV=ON
cmake --build build
ctest --test-dir build
# -> build/.../coverage report produced automatically after the tests
```

`CMT_CEEDLING_ENABLE_GCOV=ON` includes [`Gcov.cmake`](../cmake/Gcov.cmake), which instruments the
targets and creates a `gcovr` target. Report format, output directory, filters and `fail-under`
thresholds are controlled by the `CMT_GCOVR_*` cache variables documented in that module's docstring.

`gcov`/`gcovr` are GCC/Clang-specific: on MSVC and clang-cl `Gcov.cmake` warns, defines a no-op
`Gcov_AddToTarget` and creates no `gcovr` target, so `CMT_CEEDLING_ENABLE_GCOV=ON` degrades to a
plain build instead of failing.

### The `gcovr_unit` fixture

Running `gcovr` as a build target after `ctest` is easy to forget, and running it as an ordinary
test would run it once per test. Instead, when `CMT_CEEDLING_ENABLE_GCOV`, `CMT_CEEDLING_GCOVR_POST_RUN`
and a `gcovr` target are all present, the module registers exactly one extra CTest test:

```cmake
add_test(NAME gcovr_unit COMMAND ${CMAKE_COMMAND} --build <binary dir> --target gcovr)
set_property(TEST gcovr_unit PROPERTY FIXTURES_CLEANUP "gcovr_unit")
```

and every Ceedling test declares `FIXTURES_REQUIRED "gcovr_unit"`.

CTest's fixture semantics then guarantee that:

- `gcovr_unit` runs **once**, **after** all the unit tests that require the fixture, in the same
  `ctest` invocation — this is the parity with `ceedling gcov:all`;
- it is pulled in automatically whenever any Ceedling test is selected, so
  `ctest -R example_test`, `ctest -L unit` or a `-j` parallel run all still produce a report;
- it is skipped when no Ceedling test is selected, so unrelated `ctest -R integration_...` runs do
  not pay for a coverage report.

`gcovr_unit` is labelled with `CMT_CEEDLING_TEST_LABELS` plus `gcovr`, and is only added once per
project (guarded by the `CMT_CEEDLING_GCOVR_POST_RUN_ADDED` global property). Set
`-DCMT_CEEDLING_GCOVR_POST_RUN=OFF` to keep instrumentation but generate the report manually with
`cmake --build build --target gcovr`.

## Sanitizer integration

Sanitizers are off unless `CMT_CEEDLING_ENABLE_SANITIZER=ON`. With them enabled, whether an
individual test is instrumented follows this truth table:

| `CMT_CEEDLING_SANITIZER_DEFAULT` | test keyword | instrumented? |
|---|---|---|
| `ON` (default) | *(none)* | yes |
| `ON` | `DISABLE_SANITIZER` | no |
| `ON` | `ENABLE_SANITIZER` | yes |
| `OFF` | *(none)* | no |
| `OFF` | `ENABLE_SANITIZER` | yes |
| `OFF` | `DISABLE_SANITIZER` | no |

Instrumentation is applied to the test executable (`PRIVATE`) and to the target under test
(`PUBLIC`) via `Sanitizer_AddToTarget`. Which sanitizers are used is controlled by
`ENABLE_SANITIZER_ADDRESS`, `ENABLE_SANITIZER_UNDEFINED` and `ENABLE_SANITIZER_LEAK` (all `ON` by
default, with per-compiler filtering) — see [`cmake/Sanitizer.cmake`](../cmake/Sanitizer.cmake).

**The runtime environment matters as much as the flags.** For every instrumented test the module
applies `SANITIZER_ENV_VARS` to the CTest `ENVIRONMENT` property (through
`Sanitizer_ApplyEnvironmentToTests`, or through `TEST_ENVIRONMENT` when tests are discovered per
function). The default is:

```
ASAN_OPTIONS=detect_leaks=1:abort_on_error=1
UBSAN_OPTIONS=print_stacktrace=1
```

`abort_on_error=1` is the load-bearing part. Unity tests keep running after an ASan report
otherwise, the process still exits 0, and CTest happily reports the test as passed — a sanitizer
failure inside a Unity test would be silently swallowed. With the environment wired in, the first
ASan report aborts the process and the test fails.

## Troubleshooting

| Symptom | Cause |
|---|---|
| `Could NOT find Ruby_EXECUTABLE` | Ruby is not on `PATH`. It is mandatory. |
| `Could not find header '<name>.h' ...` | A `mock_<name>.h` include could not be resolved; check the target's include directories (see [Automatic mock detection](#automatic-mock-detection)). |
| Duplicate symbol errors on the mocked functions | The mocked implementation is compiled into `TARGET`; see [Known limitation](#known-limitation-target-is-linked-whole). |
| `Unity runner generator not found` | Unity was located without `auto/generate_test_runner.rb` (an incomplete or trimmed checkout). |
| `cmock.yml template not found` | No template on the search path and the bundled one is not installed alongside the modules; pass your own template via `${CMAKE_SOURCE_DIR}/cmock.yml`. |
| Coverage report never appears | `CMT_CEEDLING_GCOVR_POST_RUN=OFF`, gcovr missing, or an MSVC toolchain (no `gcovr` target is created). |

## See also

- [consumption.md](consumption.md) — getting `cmake_toolbox` into your project
- [`cmake/Ceedling.cmake`](../cmake/Ceedling.cmake), [`cmake/Unity.cmake`](../cmake/Unity.cmake),
  [`cmake/FindUnity.cmake`](../cmake/FindUnity.cmake),
  [`cmake/CMockSchema.cmake`](../cmake/CMockSchema.cmake) — authoritative API docstrings
- [`examples/`](../examples) — the working example this document is based on
