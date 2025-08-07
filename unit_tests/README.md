# Unit Tests

This directory contains unit tests for the CMake modules in this toolbox.

## Structure

- **`policy/`** - Unit tests for the Policy.cmake module
- **`clangformat/`** - Unit tests for the ClangFormat.cmake module

## Why No Unity Tests?

Unity module testing is **not included** in unit tests because:

- **`Unity_Initialize()`** requires FetchContent (external dependencies)
- **`Unity_GenerateMock()`**, **`Unity_GenerateRunner()`**, **`Unity_CreateTestTarget()`** all use `add_custom_command`/`add_executable` which don't work in script mode (`cmake -P`)

These functions are designed for use in real CMake projects where:
- FetchContent can download dependencies  
- `add_custom_command` can generate mocks and runners
- `add_executable` can create test targets
- Ruby executable is available (Unity uses `find_program(Ruby_EXECUTABLE ruby REQUIRED)` for simplicity)

## Testing Philosophy

Unit tests in this project:
- ✅ **Run in script mode** using `cmake -P` (no external dependencies)
- ✅ **Test pure logic** that can be isolated from CMake project context  
- ✅ **Validate parameter parsing** and error conditions
- ❌ **Don't test integration** with external tools or CMake project commands

Integration testing of Unity.cmake should be done within actual CMake projects that can handle the external dependencies and project-mode commands.

## Running Tests

```bash
# Run all unit tests
ctest -R "policy|clangformat"

# Run specific module tests  
ctest -R "policy"
ctest -R "clangformat"
```
