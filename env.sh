#!/usr/bin/env bash

# An editor convenience, nothing more: the pinned Nim compiler on PATH, for
# tools that need a bare `nim`/`nimsuggest` and are not started by the driver.
#
#     ./env.sh code .        # VS Code with the pinned compiler on PATH
#     ./env.sh bash          # a shell in the same environment
#     source ./env.sh        # this shell, no child process
#
# NO build needs this: `./status <task>` is the front door and finds the
# compiler by itself (see BUILDING.md).
#
# `nimble path nim` names the store entries `nimble setup` materialised — every
# nim the store holds, so the pinned version is picked out of the list. Run
# `./status` once before sourcing this, or there is nothing to point at.

status_env_root="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
status_env_pin="$(sed -n -E 's/^[[:space:]]*requires[[:space:]]+"nim[[:space:]]*==[[:space:]]*([^"[:space:]]+)".*/\1/p' \
	"${status_env_root}/nim_status_client.nimble" 2>/dev/null | head -n 1)"
status_env_nim=""

while IFS= read -r status_env_candidate; do
	[ -x "${status_env_candidate}/bin/nim" ] || continue
	case "$("${status_env_candidate}/bin/nim" --version 2>/dev/null | head -n 1)" in
		"Nim Compiler Version ${status_env_pin} "*)
			status_env_nim="${status_env_candidate}/bin"; break ;;
	esac
done < <(cd "${status_env_root}" && nimble path nim 2>/dev/null)

if [ -z "${status_env_nim}" ]; then
	echo "ERROR: no Nim ${status_env_pin} in nimble's store. Run \`./status help\` in ${status_env_root} first." 1>&2
	unset status_env_root status_env_pin status_env_nim status_env_candidate
	return 1 2>/dev/null || exit 1
fi

# Idempotent: re-sourcing must not grow PATH.
if [ "${PATH%%:*}" != "${status_env_nim}" ]; then
	PATH="${status_env_nim}:${PATH}"
fi
export PATH
unset status_env_root status_env_pin status_env_nim status_env_candidate

# EXECUTED with arguments: run them in this environment. A sourced file sees
# the CALLER's positional parameters, so this arm is gated on $0 being us.
if [ "${BASH_SOURCE[0]:-}" = "$0" ] && [ "$#" -gt 0 ]; then
	exec "$@"
fi
