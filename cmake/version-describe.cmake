# Equivalent of misc/update_version_describe.bat: define
# PROGRAM_VERSION_DESCRIBE_STRING when building a non-release (post-tag) commit.
#
#   cmake -DXY_SOURCE_DIR=<dir> -DXY_OUT=<file> -P version-describe.cmake
if(NOT DEFINED XY_SOURCE_DIR OR NOT DEFINED XY_OUT)
  message(FATAL_ERROR "version-describe.cmake: XY_SOURCE_DIR and XY_OUT are required")
endif()

set(content "\n")

if(EXISTS ${XY_SOURCE_DIR}/.git)
  find_package(Git QUIET)
  if(GIT_FOUND)
    execute_process(COMMAND ${GIT_EXECUTABLE} describe --tags --dirty
                    WORKING_DIRECTORY ${XY_SOURCE_DIR}
                    OUTPUT_VARIABLE describe
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_QUIET)
    execute_process(COMMAND ${GIT_EXECUTABLE} describe --tags --dirty --long
                    WORKING_DIRECTORY ${XY_SOURCE_DIR}
                    OUTPUT_VARIABLE describe_long
                    OUTPUT_STRIP_TRAILING_WHITESPACE
                    ERROR_QUIET)
    # Equal outputs mean "not exactly on a tag", i.e. a development build.
    if(describe AND describe STREQUAL describe_long)
      set(content "#define PROGRAM_VERSION_DESCRIBE_STRING \"${describe}\"\n")
    endif()
  endif()
endif()

if(EXISTS ${XY_OUT})
  file(READ ${XY_OUT} current)
  if(current STREQUAL content)
    return()
  endif()
endif()

file(WRITE ${XY_OUT} "${content}")
