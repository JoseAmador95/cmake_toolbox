# cmake_toolbox

`cmake_toolbox` is a small library of CMake modules for **Ceedling-style unit testing of C code**:
one call wires up a [Unity](https://github.com/ThrowTheSwitch/Unity) test executable, generates its
runner, auto-generates the [CMock](https://github.com/ThrowTheSwitch/CMock) mocks the test asks for,
and registers it with CTest. Coverage (gcov/gcovr) and sanitizer (ASan/UBSan/LSan) instrumentation
are opt-in flags on the same call.

There is no Ruby-side Ceedling project file, no `project.yml`, and no rake: the build system stays
plain CMake + CTest.

## Quickstart

Directory layout (this is the layout of the bundled [`examples/`](examples) project, which is built
and tested on every CI run):

```
my_project/
├── CMakeLists.txt
├── include/
│   ├── dependency.h
│   └── example.h
├── source/
│   └── example.c
└── unit_test/
    └── test_example.c
```

`CMakeLists.txt`:

```cmake
cmake_minimum_required(VERSION 3.22)
project(my_project C)

enable_testing()

# Point CMake at the toolbox modules. See docs/consumption.md for the three
# supported ways of getting cmake_toolbox into your project.
list(APPEND CMAKE_MODULE_PATH ${CMAKE_CURRENT_LIST_DIR}/external/cmake_toolbox/cmake)

include(Ceedling)

add_library(example STATIC ${CMAKE_CURRENT_SOURCE_DIR}/source/example.c)

# dependency.h is mocked, so it must NOT be compiled into the linked target.
# Here it is a header-only INTERFACE library. See "Known limitation" in docs/ceedling.md.
add_library(dependency INTERFACE)
target_include_directories(dependency INTERFACE ${CMAKE_CURRENT_SOURCE_DIR}/include)
target_link_libraries(example PUBLIC dependency)

Ceedling_AddUnitTest(
    NAME example_test
    UNIT_TEST ${CMAKE_CURRENT_SOURCE_DIR}/unit_test/test_example.c
    TARGET example
)
```

`unit_test/test_example.c`:

```c
#include "example.h"
#include "mock_dependency.h"   /* mock is auto-detected from this include */
#include "unity.h"

void setUp(void) {}
void tearDown(void) {}

void test_foo(void)
{
    TEST_ASSERT_EQUAL(3, example_foo(1, 2));
}

void test_malloc(void)
{
    dependency_malloc_ExpectAndReturn(10, NULL);
    TEST_ASSERT_NULL(example_malloc(10));
}
```

Build and run:

```bash
cmake -S . -B build
cmake --build build
ctest --test-dir build
```

No `MOCK_HEADERS` list is needed: `#include "mock_dependency.h"` in the test source is enough for
the module to find `dependency.h` on the include path of `example` (and its dependencies) and to
generate `mock_dependency.c/.h` for it.

Full reference: [docs/ceedling.md](docs/ceedling.md).

## Requirements

| Requirement | Notes |
|---|---|
| CMake >= 3.22 | See the root [`CMakeLists.txt`](CMakeLists.txt) |
| A C compiler | GCC, Clang/AppleClang, MSVC and MinGW are exercised in CI |
| **Ruby** | **Hard requirement** for the Ceedling/Unity modules |
| `gcovr` | Only when `CMT_CEEDLING_ENABLE_GCOV=ON` (not supported on MSVC) |
| `git` | Only when Unity/CMock are fetched with FetchContent instead of being provided locally |

### Ruby is mandatory

Unity's test-runner generator (`generate_test_runner.rb`) and CMock's mock generator (`cmock.rb`)
are Ruby scripts, and this toolbox invokes them directly. `Unity.cmake` therefore does:

```cmake
find_program(Ruby_EXECUTABLE ruby REQUIRED)
```

If `ruby` is not on `PATH`, configuration fails immediately with
`Could NOT find Ruby_EXECUTABLE`. This is the single most common setup failure. Install Ruby
(`apt install ruby`, `brew install ruby`, `choco install ruby`, or `ruby/setup-ruby` in GitHub
Actions) before configuring.

## Modules

| Module | What it does | Documentation |
|---|---|---|
| `Ceedling.cmake` | `Ceedling_AddUnitTest()`: test executable + runner + auto-detected mocks + CTest registration | [docs/ceedling.md](docs/ceedling.md) |
| `Unity.cmake` | Acquires Unity/CMock and exposes `Unity_Initialize`, `Unity_GenerateMock`, `Unity_GenerateRunner`, `Unity_CreateTestTarget` | [docs/ceedling.md](docs/ceedling.md), [`cmake/Unity.cmake`](cmake/Unity.cmake) |
| `FindUnity.cmake` | `find_package(Unity)`: locates an existing Unity/CMock checkout, or fetches one; provides `Unity::Unity` / `Unity::CMock` | [`cmake/FindUnity.cmake`](cmake/FindUnity.cmake) |
| `CMockSchema.cmake` | Renders `cmock.yml` from the `CMT_CMOCK_*` cache variables | [docs/ceedling.md](docs/ceedling.md#cmockyml-and-the-cmt_cmock_-options) |
| `DiscoverTests.cmake` | `cmake -P` helper that lists the test functions in a built Unity executable so each becomes its own CTest test | [`cmake/DiscoverTests.cmake`](cmake/DiscoverTests.cmake) |
| `Gcov.cmake` | `--coverage` instrumentation and a `gcovr` report target driven by `CMT_GCOVR_*` variables | [`cmake/Gcov.cmake`](cmake/Gcov.cmake) |
| `FindGcovr.cmake` | Locates the `gcovr` executable | [`cmake/FindGcovr.cmake`](cmake/FindGcovr.cmake) |
| `Sanitizer.cmake` | Per-language ASan/UBSan/LSan flags and the matching CTest runtime environment | [`cmake/Sanitizer.cmake`](cmake/Sanitizer.cmake) |
| `CompileCommands.cmake` | `CompileCommands_Trim()`: makes a cross-compiler `compile_commands.json` digestible by clang-based tools | [docs/compile-commands.md](docs/compile-commands.md) |
| `Policy.cmake` | CMake-like policy registration/lifecycle for your own project options | [`cmake/Policy.cmake`](cmake/Policy.cmake) |
| `TestHelpers.cmake` | `TestHelpers_GetConfigureArgs()`, used by this repository's own integration tests | [`cmake/TestHelpers.cmake`](cmake/TestHelpers.cmake) |

Every module carries a full RST docstring at the top of the file; those docstrings are the
authoritative API reference.

## Consuming the toolbox

Three modes are supported: `add_subdirectory`, `FetchContent` and `find_package` on an installed
prefix. See [docs/consumption.md](docs/consumption.md) for the snippets of each.

## Developing this repository

```bash
cmake -S . -B build -DCMAKE_TOOLBOX_BUILD_EXAMPLES=ON
cmake --build build
ctest --test-dir build --output-on-failure
```

The test suite is described in [unit_tests/README.md](unit_tests/README.md); coding conventions live
in [.github/instructions.md](.github/instructions.md).

## License

MIT. See [LICENSE](LICENSE).
