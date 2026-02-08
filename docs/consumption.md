# cmake_toolbox Consumption Modes

`cmake_toolbox` supports three consumption modes:

- `add_subdirectory`
- `FetchContent`
- `find_package`

Choose the mode that best fits your project workflow and release model.

## 1) add_subdirectory

Use this when `cmake_toolbox` is a git submodule (or otherwise vendored into your source tree).

Best for:

- Simple local development
- Full control over exact source checkout
- No package installation step

```cmake
add_subdirectory(external/cmake_toolbox)
list(APPEND CMAKE_MODULE_PATH ${CMAKE_SOURCE_DIR}/external/cmake_toolbox/cmake)

include(ClangFormat)
include(Policy)
```

## 2) FetchContent

Use this when you want to fetch `cmake_toolbox` during CMake configure.

Best for:

- Reproducible source-based integration pinned to a tag/commit
- Keeping dependency declarations in CMake
- Projects that already use FetchContent

```cmake
include(FetchContent)

FetchContent_Declare(
    cmake_toolbox
    GIT_REPOSITORY https://github.com/JoseAmador95/cmake_toolbox.git
    GIT_TAG main
)
FetchContent_MakeAvailable(cmake_toolbox)

list(APPEND CMAKE_MODULE_PATH ${cmake_toolbox_SOURCE_DIR}/cmake)

include(ClangTidy)
include(Sanitizer)
```

## 3) find_package (installed package)

Use this when `cmake_toolbox` is installed in a prefix and consumed as a versioned dependency.

Best for:

- Stable, versioned integration between teams
- Offline/air-gapped consumption (no network during configure)
- CI environments with preinstalled dependencies

Install `cmake_toolbox`:

```bash
cmake -S . -B build -DCMAKE_TOOLBOX_BUILD_EXAMPLES=OFF
cmake --build build
cmake --install build --prefix /opt/cmake_toolbox
```

Consume from another project:

```cmake
find_package(cmake_toolbox CONFIG REQUIRED)

include(ClangFormat)
include(Policy)
```

If needed, point CMake to your prefix:

```bash
cmake -S . -B build -DCMAKE_PREFIX_PATH=/opt/cmake_toolbox
```
