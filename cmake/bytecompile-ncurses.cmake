# Byte-compile Lisp files using xyzzy-ncurses --batch
# Usage: cmake -DSOURCE_DIR=... -DXYZZY_EXE=... -P bytecompile-ncurses.cmake

set(ENV{XYZZYHOME} "${SOURCE_DIR}")
set(ENV{XYZZYINIFILE} "")
set(ENV{XYZZYCONFIGPATH} "")

message(STATUS "XYZZYHOME=${SOURCE_DIR}")

# Delete existing .lc files so we can count fresh ones
file(GLOB old_lc_files "${SOURCE_DIR}/lisp/*.lc")
list(LENGTH old_lc_files old_lc_count)
if(old_lc_count GREATER 0)
    message(STATUS "Deleting ${old_lc_count} existing .lc files")
    file(REMOVE ${old_lc_files})
endif()

set(LOGFILE "${SOURCE_DIR}/bytecompile-progress.log")
file(REMOVE "${LOGFILE}")

message(STATUS "Running: ${XYZZY_EXE} --batch -load misc/bytecompile-batch.l")

# ncurses --batch mode: no -q (needs full startup to bootstrap from .l)
execute_process(
    COMMAND ${XYZZY_EXE} --batch -load misc/bytecompile-batch.l
    WORKING_DIRECTORY ${SOURCE_DIR}
    RESULT_VARIABLE rc
    TIMEOUT 600
)
message(STATUS "xyzzy-ncurses exited with code: ${rc}")

# Show compilation log
if(EXISTS "${LOGFILE}")
    file(READ "${LOGFILE}" log_contents)
    message("${log_contents}")
endif()

file(GLOB lc_files "${SOURCE_DIR}/lisp/*.lc")
list(LENGTH lc_files lc_count)
message(STATUS "Generated ${lc_count} .lc files")

# Success is determined by .lc file count, not exit code.
if(lc_count LESS 100)
    message(FATAL_ERROR "Byte-compile failed: only ${lc_count} .lc files generated (exit code: ${rc})")
endif()

message(STATUS "Byte-compile succeeded: ${lc_count} .lc files")
