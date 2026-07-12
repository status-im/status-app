#!/usr/bin/env bash

# The Nim environment of this repo, for tools that need `nim` on PATH but are
# not started by nimble or by the driver — an editor, a shell session:
#
#     ./env.sh code .        # VS Code with the pinned compiler on PATH
#     ./env.sh bash          # a shell in the same environment
#     source ./env.sh        # this shell, no child process
#
# There is no vendored compiler any more (issue 0018: nimbus-build-system is
# gone, and this file used to source its scripts/env.sh). The compiler is the
# one `nim_status_client.nimble` pins — nimble materialises it in its store and
# `nimble shellenv` prints the PATH that reaches it. A bootstrapped shell
# therefore cannot drift from the pin.
#
# Prerequisite: `nimble` on PATH, and `nimble setup` run once (see BUILDING.md).

# ${BASH_SOURCE[0]} rather than $0 so the file can also be sourced; the Zsh
# fallback keeps `source ./env.sh` working there too.
REL_PATH="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")"
ABS_PATH="$(cd "${REL_PATH}"; pwd)"

if ! command -v nimble >/dev/null 2>&1; then
	echo "ERROR: nimble is not on PATH — it is the ONE prerequisite of this build (see BUILDING.md)." 1>&2
	return 1 2>/dev/null || exit 1
fi

# `nimble shellenv` prints `export PATH=…` including the pinned compiler's
# <store>/pkgs2/nim-<version>-<checksum>/bin. It must run from the package root.
STATUS_SHELLENV="$(cd "${ABS_PATH}" && nimble shellenv)" || {
	echo "ERROR: \`nimble shellenv\` failed. Run \`nimble setup\` in ${ABS_PATH} first." 1>&2
	return 1 2>/dev/null || exit 1
}
eval "${STATUS_SHELLENV}"

# WALL (measured 2026-07-12, nimble 0.22.3): shellenv emits the store's own
# `bin` directory ($NIMBLE_DIR/bin) BEFORE the pinned compiler's
# pkgs2/nim-<version>-<checksum>/bin. That directory usually carries a `nim`
# symlink — normally the pin itself, but choosenim (or `nimble install nim@X`)
# repoints it — and it would then SHADOW the pin for every `nim` we run. So
# hoist the pinned compiler's bin to the front: after this line `nim` is the
# pin, whatever else the machine has installed.
STATUS_NIM_BIN="$(printf '%s' "${PATH}" | tr ':' '\n' | grep -m1 -E '/pkgs2/nim-[^/]+/bin$')"
if [[ -n "${STATUS_NIM_BIN}" ]]; then
	export PATH="${STATUS_NIM_BIN}:${PATH}"
else
	echo "WARNING: no pinned Nim (pkgs2/nim-*/bin) in \`nimble shellenv\`'s PATH — is the graph resolved?" 1>&2
fi

if [[ $# -gt 0 ]]; then
	if [[ $# == 1 && $1 == "bash" ]]; then
		export PS1="[status env] \[\033[0;32m\]\w\[\033[0m\]\n\u\$ "
		exec "$1" --login --noprofile
	else
		exec "$@"
	fi
fi
