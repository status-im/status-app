# Idempotently apply PATCH_FILE (git format-patch output) to the working
# directory — the FetchContent PATCH_COMMAND helper. The patch step can re-run
# on an already-patched source tree (e.g. a re-triggered update step), so a
# patch that is already applied (reverse-applies cleanly) is a no-op instead
# of an error.
#
# Usage: cmake -DPATCH_FILE=<path> -P apply_patch.cmake  (cwd = source dir)

if(NOT DEFINED PATCH_FILE)
    message(FATAL_ERROR "apply_patch.cmake: pass -DPATCH_FILE=<path>")
endif()

execute_process(
    COMMAND git apply --reverse --check --ignore-whitespace "${PATCH_FILE}"
    RESULT_VARIABLE already_applied
    OUTPUT_QUIET ERROR_QUIET
)

if(already_applied EQUAL 0)
    return()
endif()

execute_process(
    COMMAND git apply --ignore-whitespace "${PATCH_FILE}"
    RESULT_VARIABLE apply_result
)

if(NOT apply_result EQUAL 0)
    message(FATAL_ERROR "apply_patch.cmake: failed to apply ${PATCH_FILE}")
endif()
