# CompileCommands

`CompileCommands.cmake` provides `CompileCommands_Trim()`, a standalone utility that rewrites a
`compile_commands.json` file, keeping only the flags a clang-based tool needs and dropping the ones
that make it choke.

No other module in this repository consumes it — it is a public feature in its own right, not dead
code.

## The problem it solves

`CMAKE_EXPORT_COMPILE_COMMANDS=ON` records the *exact* command line your compiler was invoked with.
When that compiler is not clang — an ARM GCC, a Tricore or RISC-V toolchain, ICC, or simply a GCC
version newer than your clang — the recorded flags are the compiler's own dialect. Point
`clang-tidy`, `clangd`, `include-what-you-use` or any other libTooling program at that database and
it stops at the first flag it does not recognise:

```
error: unknown argument: '-fstrict-volatile-bitfields'
error: unknown argument: '-mcpu=cortex-m4'
```

`CompileCommands_Trim()` produces a second, sanitised database that keeps everything relevant to
semantic analysis (include paths, macro definitions, language and standard selection) and discards
everything that only matters for code generation.

## API

```cmake
include(CompileCommands)

CompileCommands_Trim(
  INPUT <input_file>
  OUTPUT <output_file>
)
```

| Argument | Required | Meaning |
|---|---|---|
| `INPUT` | yes | Path to the source `compile_commands.json`. |
| `OUTPUT` | yes | Path of the trimmed file to produce. Its parent directory is created at configure time. |

Both are `FATAL_ERROR` if omitted.

The function declares an `add_custom_command(OUTPUT <output_file> ...)` that runs
[`internal/TrimCompileCommandsHelper.cmake`](../cmake/internal/TrimCompileCommandsHelper.cmake) via
`cmake -P`. It depends on `INPUT` and on the helper script, so the output is regenerated when either
changes. Because it is a custom **command** and not a target, you need something that consumes the
output for it to run:

```cmake
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

include(CompileCommands)

CompileCommands_Trim(
    INPUT ${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT ${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)

add_custom_target(trim_compile_commands DEPENDS ${CMAKE_BINARY_DIR}/trimmed/compile_commands.json)
```

```bash
cmake --build build --target trim_compile_commands
clang-tidy -p build/trimmed src/foo.c
```

The trimming is done entirely with CMake's built-in JSON support — no shell redirection, no `jq`,
no Python — so it behaves the same across Ninja, Makefiles and MSBuild, and on all platforms.

## What is kept and what is dropped

For every entry, the `command` string is split into tokens. The first token (the compiler) and the
last token (the source file) are always kept. In between, a token survives only if it matches one of:

- `-D...` — macro definitions
- `-std=...` — language standard
- `-I`, `-isystem`, `-iquote`, `-idirafter`, `-iframework`, `-isysroot`, `-include`, `-imsvc`
  followed immediately by their value (`-Iinclude`)
- `-x` — explicit language selection
- `-fexceptions` / `-fno-exceptions`, `-frtti` / `-fno-rtti`
- `-fPIC`, `-fpic`, `-fPIE`, `-fpie`
- `-pthread`
- `-m32`, `-m64`

Flags that take their value as a *separate* token (`-I include`, `-isystem /path`, `-o out.o`,
`-x c`, `-resource-dir ...`, ...) are kept together with that value, so paths containing spaces
survive intact.

Everything else is dropped — in particular optimisation (`-O*`), debug (`-g*`) and warning flags,
which are irrelevant to static analysis.

Finally, anything matching the blacklist is dropped even if it appeared in the keep list above.

## Built-in blacklist

Defined in `_CompileCommands_InitBlacklist` in the helper script. Each entry is a CMake regex matched
against a whole token:

| Group | Patterns |
|---|---|
| GCC modules | `^-fmodules-ts$`, `^-fmodule-mapper=.*`, `^-fdeps-format=.*` |
| GCC bitfield semantics | `^-fstrict-volatile-bitfields$` |
| ARM / embedded codegen | `^-mcpu=.*`, `^-march=arm.*`, `^-mthumb$`, `^-mno-thumb$`, `^-mfloat-abi=.*`, `^-mfpu=.*` |
| GCC-only warnings | `^-Wformat-signedness$`, `^-Wsuggest-override$`, `^-Wduplicated-cond$`, `^-Wduplicated-branches$`, `^-Wlogical-op$`, `^-Wuseless-cast$`, `^-Wno-maybe-uninitialized$` |
| Intel ICC | `^-w[0-9]$` |
| Tricore | `^-m(tc\|tricore).*` |
| RISC-V / other embedded | `^-msmall-data-limit=.*`, `^-mexplicit-reloc=.*`, `^-mno-explicit-reloc$`, `^-msram-size=.*`, `^-mno-sdata$`, `^-msdata=.*` |
| Data-race codegen | `^-fallow-store-data-races$`, `^-fno-allow-store-data-races$` |

Separately, a short list of *space-separated* forms (`-mcpu`, `-march`, `-mfpu`, `-mfloat-abi`,
`-msram-size`, `-msdata`, `-mexplicit-reloc`) is recognised so that both the flag and the value token
that follows it are removed.

## Extending the blacklist

Add your own regexes through the `COMPILE_COMMANDS_TRIM_BLACKLIST` cache variable (semicolon
separated). They are appended to the built-in list; there is no way to shrink the built-in list.

```cmake
set(COMPILE_COMMANDS_TRIM_BLACKLIST "^-Wmy-custom-flag$;^-fmy-custom-opt")

CompileCommands_Trim(
    INPUT ${CMAKE_BINARY_DIR}/compile_commands.json
    OUTPUT ${CMAKE_BINARY_DIR}/trimmed/compile_commands.json
)
```

or from the command line:

```bash
cmake -S . -B build "-DCOMPILE_COMMANDS_TRIM_BLACKLIST=^-Wmy-custom-flag$;^-fmy-custom-opt"
```

The value is read when `CompileCommands_Trim()` is called, so set it before the call.

## Multi-config generators

Visual Studio and Xcode do not generate `compile_commands.json` at all. On a multi-config generator
the module disables itself at `include()` time:

- it sets the internal `CMT_COMPILECOMMANDS_AVAILABLE` to `FALSE`,
- emits a `WARNING` saying the module is disabled,
- and replaces `CompileCommands_Trim()` with a stub that warns and does nothing.

This means `include(CompileCommands)` is always safe to call unconditionally; it just becomes inert.
Single-config multi-configuration generators such as *Ninja Multi-Config* are also affected, since
`GENERATOR_IS_MULTI_CONFIG` is what the check reads. If you need a trimmed database in such a build
tree, configure a separate single-config build directory (Ninja or Makefiles) for the analysis pass.

The repository's own test suite skips the CompileCommands tests on multi-config generators for the
same reason.

## See also

- [`cmake/CompileCommands.cmake`](../cmake/CompileCommands.cmake) and
  [`cmake/internal/TrimCompileCommandsHelper.cmake`](../cmake/internal/TrimCompileCommandsHelper.cmake)
  — authoritative docstrings and implementation
- [consumption.md](consumption.md) — getting `cmake_toolbox` into your project
