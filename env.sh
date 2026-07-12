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
#
# This file is the bootstrap SPOF: `fdroid/build-app.sh` (`set -eou pipefail`),
# `mobile/ContainerBuilds.mk` (`bash -c 'set -e && …'`) and CI all source it, so
# it must survive being sourced under `set -e`, from a caller that has its own
# positional parameters, in both bash and zsh (issue 0018 review, C1–C3):
#
#   * no command in it may return non-zero on a normal run — a `grep` that
#     matches nothing would kill an `set -e` caller before its own error
#     handling ever ran (C1);
#   * the `exec "$@"` arm is gated on having been EXECUTED, because a SOURCED
#     file inherits the CALLER's "$@" and would otherwise exec the caller's own
#     argv and never return (C2);
#   * the hoisted compiler is asserted against the manifest's `requires "nim ==
#     X"` — hoisting the FIRST pkgs2 nim on PATH asserts nothing about its
#     version, and a second store nim would silently win (C3).

# --- was this file sourced, or executed? --------------------------------------
# bash: BASH_SOURCE[0] is this file, $0 is the caller's script when sourced.
# zsh:  BASH_SOURCE is unset and $0 is this file in BOTH cases — ZSH_EVAL_CONTEXT
#       is the discriminator (`toplevel:file` sourced, `toplevel` executed).
STATUS_ENV_SOURCED=0
if [ -n "${BASH_VERSION:-}" ]; then
	if [ "${BASH_SOURCE[0]}" != "$0" ]; then
		STATUS_ENV_SOURCED=1
	fi
elif [ -n "${ZSH_VERSION:-}" ]; then
	case "${ZSH_EVAL_CONTEXT:-}" in
		*:file*) STATUS_ENV_SOURCED=1 ;;
	esac
fi

# ${BASH_SOURCE[0]} rather than $0 so the file can also be sourced; the Zsh
# fallback keeps `source ./env.sh` working there too.
STATUS_ENV_REL="$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")"
STATUS_ENV_ROOT="$(cd "${STATUS_ENV_REL}" && pwd)"

# One cleanup point: every exit path runs it, so a sourced shell keeps no
# STATUS_ENV_* / STATUS_NIM_* leftovers (issue 0018 review, M1).
status_env_cleanup() {
	unset STATUS_ENV_SOURCED STATUS_ENV_REL STATUS_ENV_ROOT \
		STATUS_ENV_SHELLENV STATUS_NIM_BIN STATUS_NIM_PIN STATUS_NIM_FOUND
	unset -f status_env_cleanup
}

if ! command -v nimble >/dev/null 2>&1; then
	echo "ERROR: nimble is not on PATH — it is the ONE prerequisite of this build (see BUILDING.md)." 1>&2
	status_env_cleanup
	return 1 2>/dev/null || exit 1
fi

# `nimble shellenv` prints `export PATH=…` including the pinned compiler's
# <store>/pkgs2/nim-<version>-<checksum>/bin. It must run from the package root.
STATUS_ENV_SHELLENV="$(cd "${STATUS_ENV_ROOT}" && nimble shellenv)" || {
	echo "ERROR: \`nimble shellenv\` failed. Run \`nimble setup\` in ${STATUS_ENV_ROOT} first." 1>&2
	status_env_cleanup
	return 1 2>/dev/null || exit 1
}
eval "${STATUS_ENV_SHELLENV}"

# WALL (measured 2026-07-12, nimble 0.22.3): shellenv emits the store's own
# `bin` directory ($NIMBLE_DIR/bin) BEFORE the pinned compiler's
# pkgs2/nim-<version>-<checksum>/bin. That directory usually carries a `nim`
# symlink — normally the pin itself, but choosenim (or `nimble install nim@X`)
# repoints it — and it would then SHADOW the pin for every `nim` we run. So
# hoist the pinned compiler's bin to the front: after this line `nim` is the
# pin, whatever else the machine has installed.
#
# `|| true`: `grep` exits 1 when it matches nothing, and a command substitution
# propagates that status — under a caller's `set -e` this file would DIE here,
# silently, before the WARNING below could ever print (C1).
STATUS_NIM_BIN="$(printf '%s' "${PATH}" | tr ':' '\n' | grep -m1 -E '/pkgs2/nim-[^/]+/bin$' || true)"

# The pin, parsed from the manifest — never hardcoded (C3).
STATUS_NIM_PIN="$(sed -n -E 's/^[[:space:]]*requires[[:space:]]+"nim[[:space:]]*==[[:space:]]*([^"[:space:]]+)".*/\1/p' \
	"${STATUS_ENV_ROOT}/nim_status_client.nimble" 2>/dev/null | head -1 || true)"

if [ -n "${STATUS_NIM_BIN}" ]; then
	# Assert the hoisted entry against the pin BEFORE putting it on PATH: the
	# store can hold several nims (a choosenim install, an older pin, a
	# transitively required version), shellenv lists whatever it lists, and
	# hoisting "the first pkgs2 nim" asserts nothing about which one it is.
	# The version is embedded in the store entry's own name, so this costs no
	# subprocess: pkgs2/nim-<version>-<checksum>/bin.
	STATUS_NIM_FOUND="$(printf '%s' "${STATUS_NIM_BIN}" | sed -n -E 's|.*/pkgs2/nim-([^/-]+)-[^/]*/bin$|\1|p' || true)"
	if [ -n "${STATUS_NIM_PIN}" ] && [ "${STATUS_NIM_FOUND}" != "${STATUS_NIM_PIN}" ]; then
		echo "ERROR: the Nim that \`nimble shellenv\` puts first is NOT the pinned compiler." 1>&2
		echo "  pinned by nim_status_client.nimble: nim == ${STATUS_NIM_PIN}" 1>&2
		echo "  first on shellenv's PATH:           ${STATUS_NIM_BIN} (version ${STATUS_NIM_FOUND:-unknown})" 1>&2
		echo "Another Nim is in the store's PATH ahead of the pin (choosenim? \`nimble install nim@X\`?)." 1>&2
		echo "Re-resolve with \`nimble setup\` in ${STATUS_ENV_ROOT}; if it persists, remove the foreign nim from the store." 1>&2
		status_env_cleanup
		return 1 2>/dev/null || exit 1
	fi
	# Idempotent: re-sourcing must not grow PATH (M1).
	if [ "${PATH%%:*}" != "${STATUS_NIM_BIN}" ]; then
		PATH="${STATUS_NIM_BIN}:${PATH}"
	fi
	# shellenv itself re-prepends its dirs to the PATH it inherits, so a second
	# `source ./env.sh` would duplicate them: keep the first occurrence of each.
	PATH="$(printf '%s' "${PATH}" | awk -v RS=: -v ORS= '!seen[$0]++ { if (n++) printf ":"; printf "%s", $0 }')"
	export PATH
else
	echo "WARNING: no pinned Nim (pkgs2/nim-*/bin) in \`nimble shellenv\`'s PATH — is the graph resolved?" 1>&2
fi

if [ "${STATUS_ENV_SOURCED}" = "0" ] && [ $# -gt 0 ]; then
	# EXECUTED with arguments: run them in this environment. Never when sourced —
	# a sourced file sees the CALLER's positional parameters, and `exec`ing those
	# would replace the caller with its own argv (C2).
	if [ $# = 1 ] && [ "$1" = "bash" ]; then
		export PS1="[status env] \[\033[0;32m\]\w\[\033[0m\]\n\u\$ "
		status_env_cleanup
		exec bash --login --noprofile
	fi
	status_env_cleanup
	exec "$@"
fi

status_env_cleanup
