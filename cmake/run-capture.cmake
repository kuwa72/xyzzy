# Run a command and capture its standard output into a file.
#
# The code generators write to stdout, which add_custom_command cannot redirect
# portably.  Invoke via:
#   cmake -DXY_CMD=<a;b;c> -DXY_OUT=<file> [-DXY_WD=<dir>] -P run-capture.cmake
if(NOT DEFINED XY_CMD OR NOT DEFINED XY_OUT)
  message(FATAL_ERROR "run-capture.cmake: XY_CMD and XY_OUT are required")
endif()

if(NOT DEFINED XY_WD)
  set(XY_WD ${CMAKE_CURRENT_BINARY_DIR})
endif()

execute_process(
  COMMAND ${XY_CMD}
  WORKING_DIRECTORY ${XY_WD}
  OUTPUT_FILE ${XY_OUT}
  RESULT_VARIABLE result)

if(NOT result EQUAL 0)
  file(REMOVE ${XY_OUT})
  message(FATAL_ERROR "run-capture.cmake: '${XY_CMD}' failed (${result})")
endif()
