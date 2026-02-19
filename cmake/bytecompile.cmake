# Byte-compile Lisp files using xyzzy-batch (console version)
# Usage: cmake -DSOURCE_DIR=... -DXYZZY_EXE=... -P bytecompile.cmake

set(ENV{XYZZYHOME} "${SOURCE_DIR}")
set(ENV{XYZZYINIFILE} "")
set(ENV{XYZZYCONFIGPATH} "")

message(STATUS "XYZZYHOME=${SOURCE_DIR}")

# Delete stale dump image (next to exe)
get_filename_component(EXE_DIR "${XYZZY_EXE}" DIRECTORY)
get_filename_component(EXE_NAME "${XYZZY_EXE}" NAME_WE)
set(DUMP_IMAGE "${EXE_DIR}/${EXE_NAME}.wxp")
if(EXISTS "${DUMP_IMAGE}")
    message(STATUS "Deleting stale dump image: ${DUMP_IMAGE}")
    file(REMOVE "${DUMP_IMAGE}")
endif()

# Delete existing .lc files so we can count fresh ones
file(GLOB old_lc_files "${SOURCE_DIR}/lisp/*.lc")
list(LENGTH old_lc_files old_lc_count)
if(old_lc_count GREATER 0)
    message(STATUS "Deleting ${old_lc_count} existing .lc files")
    file(REMOVE ${old_lc_files})
endif()

set(LOGFILE "${SOURCE_DIR}/bytecompile-progress.log")
file(REMOVE "${LOGFILE}")

message(STATUS "Running: ${XYZZY_EXE} -q -load misc/bytecompile-batch.l")

# Console subsystem app — execute_process properly waits for it
execute_process(
    COMMAND ${XYZZY_EXE} -q -load misc/bytecompile-batch.l
    WORKING_DIRECTORY ${SOURCE_DIR}
    RESULT_VARIABLE rc
    TIMEOUT 600
)
message(STATUS "xyzzy-batch exited with code: ${rc}")

# Show compilation log
if(EXISTS "${LOGFILE}")
    file(READ "${LOGFILE}" log_contents)
    message("${log_contents}")
endif()

file(GLOB lc_files "${SOURCE_DIR}/lisp/*.lc")
list(LENGTH lc_files lc_count)
message(STATUS "Generated ${lc_count} .lc files")

# Success is determined by .lc file count, not exit code.
# The process may stack-overflow during cleanup after all files are generated.
if(lc_count LESS 100)
    message(FATAL_ERROR "Byte-compile failed: only ${lc_count} .lc files generated (exit code: ${rc})")
endif()

message(STATUS "Byte-compile succeeded: ${lc_count} .lc files")
