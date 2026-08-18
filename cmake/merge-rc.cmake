# Build the resource script the executable is compiled from.
#
# The MSVC build does "type xyzzy.rc version-rc.h > gen\xyzzy.rc"; reproduce it
# here.  Additionally rewrite the backslashes in resource file references, since
# GNU windres resolves them literally on a non-Windows host.
#
#   cmake -DXY_IN=<a;b;...> -DXY_OUT=<file> -P merge-rc.cmake
if(NOT DEFINED XY_IN OR NOT DEFINED XY_OUT)
  message(FATAL_ERROR "merge-rc.cmake: XY_IN and XY_OUT are required")
endif()

set(merged "")
foreach(part IN LISTS XY_IN)
  file(READ ${part} chunk)
  string(APPEND merged "${chunk}\n")
endforeach()

if(NOT WIN32)
  # GNU windres opens a resource file name literally, so "res\\check.bmp" has to
  # become "res/check.bmp".  Only the res\ prefix is rewritten: other
  # backslashes in the script are \t escapes inside displayed strings.
  string(REPLACE "res\\\\" "res/" merged "${merged}")
  string(REPLACE "res\\" "res/" merged "${merged}")
endif()

file(WRITE ${XY_OUT} "${merged}")
