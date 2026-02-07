# Distributed under the OSI-approved BSD 3-Clause License.
# See accompanying file LICENSE.txt for details.

#[=======================================================================[.rst:
Internal CMake script helper for CompileCommands_Trim function.

This script is executed via ``cmake -P`` to trim a compile_commands.json file
using the jq tool. It is designed to work portably across different CMake
generators (Ninja, Make, MSBuild, etc.) and platforms without shell redirection.

Expected variables (passed via -D flags):
  JQ_EXECUTABLE - Path to the jq executable
  INPUT_FILE - Path to the source compile_commands.json
  OUTPUT_FILE - Path where the trimmed output will be written
  JQ_SCRIPT - Path to the jq script file (.jq)
#]=======================================================================]

# Validate that all required variables are set
if(NOT DEFINED JQ_EXECUTABLE)
    message(FATAL_ERROR "TrimCompileCommandsHelper: JQ_EXECUTABLE is not defined")
endif()

if(NOT DEFINED INPUT_FILE)
    message(FATAL_ERROR "TrimCompileCommandsHelper: INPUT_FILE is not defined")
endif()

if(NOT DEFINED OUTPUT_FILE)
    message(FATAL_ERROR "TrimCompileCommandsHelper: OUTPUT_FILE is not defined")
endif()

if(NOT DEFINED JQ_SCRIPT)
    message(FATAL_ERROR "TrimCompileCommandsHelper: JQ_SCRIPT is not defined")
endif()

# Validate that input files exist
if(NOT EXISTS "${INPUT_FILE}")
    message(FATAL_ERROR "TrimCompileCommandsHelper: INPUT_FILE does not exist: ${INPUT_FILE}")
endif()

if(NOT EXISTS "${JQ_SCRIPT}")
    message(FATAL_ERROR "TrimCompileCommandsHelper: JQ_SCRIPT does not exist: ${JQ_SCRIPT}")
endif()

# Create output directory if it doesn't exist
get_filename_component(output_dir "${OUTPUT_FILE}" DIRECTORY)
if(NOT EXISTS "${output_dir}")
    file(MAKE_DIRECTORY "${output_dir}")
endif()

# Execute jq with OUTPUT_FILE to redirect output portably (no shell redirection needed)
execute_process(
    COMMAND ${JQ_EXECUTABLE} -f "${JQ_SCRIPT}" "${INPUT_FILE}"
    OUTPUT_FILE "${OUTPUT_FILE}"
    RESULT_VARIABLE result
    ERROR_VARIABLE error_msg
)

# Check for errors and provide helpful messages
if(NOT result EQUAL 0)
    message(FATAL_ERROR "TrimCompileCommandsHelper: jq command failed with exit code ${result}\n${error_msg}")
endif()

# Verify output file was created
if(NOT EXISTS "${OUTPUT_FILE}")
    message(FATAL_ERROR "TrimCompileCommandsHelper: Failed to create output file: ${OUTPUT_FILE}")
endif()

message(STATUS "Successfully trimmed compile commands: ${OUTPUT_FILE}")
