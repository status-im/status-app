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
# COST (issue 0018 review, R6): `nimble shellenv` re-solves the whole graph on
# every call — ~50 s on this machine, warm store. That is nimble's dispatch tax
# (recorded in issue 0013), not something this file adds. Bootstrap ONCE per
# shell (or per CI stage) and run many commands in it; never once per build
# step. A cached-shellenv follow-up (key = nimble.lock + the manifests, like the
# Qt env cache) is recorded in issue 0018's follow-ups.
#
# This file is the bootstrap SPOF: `fdroid/build-app.sh` (`set -eou pipefail`),
# `mobile/ContainerBuilds.mk` (`bash -c 'set -e && …'`) and CI all source it, so
# it must survive being sourced under `set -e`/`set -u`, from a caller that has
# its own positional parameters, in bash, in zsh — and, the round-2 finding, in
# any other POSIX shell (issue 0018 review, C1–C3 + R1/R2/R5):
#
#   * NOTHING above the shell detection below may be a bashism. A `#!/bin/sh`
#     (dash) caller doing `. ./env.sh` used to die on `${BASH_SOURCE[0]}` with
#     "Bad substitution" and then CARRY ON into the exec arm, which exec'd the
#     CALLER's $1 — a full hijack (R1). Every shell-specific expansion is now
#     hidden inside `eval` (a string to every other parser), and a shell we
#     cannot interrogate is treated as SOURCED, so it can never exec.
#   * no command may return non-zero on a normal run — a `grep` that matches
#     nothing would kill a `set -e` caller before its own error handling ever
#     ran (C1);
#   * the `exec "$@"` arm is gated on having been EXECUTED, because a SOURCED
#     file inherits the CALLER's "$@" and would otherwise exec the caller's own
#     argv and never return (C2);
#   * the hoisted compiler is asserted against the FULL pinned store entry —
#     `requires "nim == X"` from the manifest AND `packages.nim.checksums.sha1`
#     from nimble.lock, the same two facts the driver's guardPinnedCompiler()
#     reads — and that entry must really carry an executable `nim` (C3 + R2).
#     Hoisting "the first pkgs2 nim on PATH" asserts nothing: a second store
#     nim, or a same-version entry with a different checksum, silently wins;
#   * every error path restores the PATH this file was entered with, so a
#     failed bootstrap never leaves a foreign nim in front (R5).

# --- which shell, and were we sourced?  (pure POSIX — precedes every bashism) --
# bash: BASH_SOURCE[0] is THIS file; $0 is the caller's script when sourced.
# zsh:  BASH_SOURCE is unset and $0 is this file in BOTH cases — ZSH_EVAL_CONTEXT
#       is the discriminator (`toplevel:file` sourced, `toplevel` executed).
# else: undecidable ⇒ assume SOURCED. Executing this file always lands in bash
#       (the shebang), so the exec arm loses nothing by being bash/zsh-only.
STATUS_ENV_SHELL=other
STATUS_ENV_SOURCED=1
STATUS_ENV_SELF=""

if [ -n "${BASH_VERSION:-}" ]; then
	STATUS_ENV_SHELL=bash
	# eval: the array subscript is a bashism — no foreign parser may see it.
	eval 'STATUS_ENV_SELF="${BASH_SOURCE[0]}"'
	if [ "${STATUS_ENV_SELF}" = "$0" ]; then
		STATUS_ENV_SOURCED=0
	fi
elif [ -n "${ZSH_VERSION:-}" ]; then
	STATUS_ENV_SHELL=zsh
	eval 'STATUS_ENV_SELF="${(%):-%x}"'
	STATUS_ENV_SOURCED=0
	case "${ZSH_EVAL_CONTEXT:-}" in
		*:file*) STATUS_ENV_SOURCED=1 ;;
	esac
fi

# The repo root. bash and zsh can name the running file; a foreign shell that
# SOURCES us cannot ($0 is the CALLER there), so fall back to the working
# directory when that IS the package root, and say so plainly when it is not.
STATUS_ENV_ROOT=""
if [ -n "${STATUS_ENV_SELF}" ]; then
	STATUS_ENV_ROOT="$(cd "$(dirname "${STATUS_ENV_SELF}")" && pwd)"
elif [ -f "${PWD}/nim_status_client.nimble" ]; then
	STATUS_ENV_ROOT="${PWD}"
fi

STATUS_ENV_PATH0="${PATH}"   # restored by every error path (R5)

# One cleanup point: every exit path runs it, so a sourced shell keeps no
# STATUS_ENV_* / STATUS_NIM_* leftovers (issue 0018 review, M1).
status_env_cleanup() {
	unset STATUS_ENV_SHELL STATUS_ENV_SOURCED STATUS_ENV_SELF STATUS_ENV_ROOT \
		STATUS_ENV_PATH0 STATUS_ENV_SHELLENV STATUS_NIM_BIN STATUS_NIM_ENTRY \
		STATUS_NIM_PIN STATUS_NIM_SHA STATUS_NIM_WANT STATUS_NIM_HAVE
	unset -f status_env_cleanup
}

if [ -z "${STATUS_ENV_ROOT}" ]; then
	echo "ERROR: env.sh cannot locate the repo root under this shell (${STATUS_ENV_SHELL})." 1>&2
	echo "  A sourced file cannot name itself here — \$0 is the caller's script." 1>&2
	echo "  Bootstrap with bash or zsh (\`bash -c 'source ./env.sh && …'\`), or source" 1>&2
	echo "  this file from the repo root (the directory holding nim_status_client.nimble)." 1>&2
	PATH="${STATUS_ENV_PATH0}"
	export PATH
	status_env_cleanup
	return 1 2>/dev/null || exit 1
fi

if ! command -v nimble >/dev/null 2>&1; then
	echo "ERROR: nimble is not on PATH — it is the ONE prerequisite of this build (see BUILDING.md)." 1>&2
	PATH="${STATUS_ENV_PATH0}"
	export PATH
	status_env_cleanup
	return 1 2>/dev/null || exit 1
fi

# `nimble shellenv` prints `export PATH=…` including the pinned compiler's
# <store>/pkgs2/nim-<version>-<checksum>/bin. It must run from the package root.
STATUS_ENV_SHELLENV="$(cd "${STATUS_ENV_ROOT}" && nimble shellenv)" || {
	echo "ERROR: \`nimble shellenv\` failed. Run \`nimble setup\` in ${STATUS_ENV_ROOT} first." 1>&2
	PATH="${STATUS_ENV_PATH0}"
	export PATH
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

# The pin, parsed — never hardcoded (C3/R2). Two facts, two files:
#   version:  nim_status_client.nimble's `requires "nim == X"`
#   checksum: nimble.lock's packages.nim.checksums.sha1 — which IS the store
#             entry's checksum (verified 2026-07-12), so version+checksum name
#             the store directory exactly: pkgs2/nim-<version>-<checksum>.
STATUS_NIM_PIN="$(sed -n -E 's/^[[:space:]]*requires[[:space:]]+"nim[[:space:]]*==[[:space:]]*([^"[:space:]]+)".*/\1/p' \
	"${STATUS_ENV_ROOT}/nim_status_client.nimble" 2>/dev/null || true)"
# ([{] / [}] rather than escaped braces: an ERE brace is an interval operator,
#  and BSD and GNU sed disagree about what `\{` means inside `-E`.)
STATUS_NIM_SHA="$(sed -n -E '/"nim"[[:space:]]*:[[:space:]]*[{]/,/[}]/{s/.*"sha1"[[:space:]]*:[[:space:]]*"([0-9a-f]+)".*/\1/p;}' \
	"${STATUS_ENV_ROOT}/nimble.lock" 2>/dev/null || true)"

if [ -n "${STATUS_NIM_BIN}" ]; then
	# Assert the hoisted entry against the pin BEFORE putting it on PATH: the
	# store can hold several nims (a choosenim install, an older pin, the same
	# version rebuilt at another checksum), shellenv lists whatever it lists,
	# and hoisting "the first pkgs2 nim" asserts nothing about which one it is.
	# The whole entry name is in the path, so this costs no subprocess:
	# pkgs2/nim-<version>-<checksum>/bin.
	STATUS_NIM_ENTRY="$(basename "$(dirname "${STATUS_NIM_BIN}")")"
	STATUS_NIM_HAVE="${STATUS_NIM_ENTRY#nim-}"
	STATUS_NIM_HAVE="${STATUS_NIM_HAVE%%-*}"
	STATUS_NIM_WANT=""
	if [ -n "${STATUS_NIM_PIN}" ] && [ -n "${STATUS_NIM_SHA}" ]; then
		STATUS_NIM_WANT="nim-${STATUS_NIM_PIN}-${STATUS_NIM_SHA}"
	fi

	if [ -n "${STATUS_NIM_WANT}" ] && [ "${STATUS_NIM_ENTRY}" != "${STATUS_NIM_WANT}" ]; then
		echo "ERROR: the Nim that \`nimble shellenv\` puts first is NOT the pinned compiler." 1>&2
		echo "  pinned (nim_status_client.nimble + nimble.lock): ${STATUS_NIM_WANT}" 1>&2
		echo "  first on shellenv's PATH:                        ${STATUS_NIM_ENTRY}" 1>&2
		echo "    (${STATUS_NIM_BIN})" 1>&2
		echo "Another Nim sits ahead of the pin in the store's PATH (choosenim? \`nimble install nim@X\`?)," 1>&2
		echo "or the store entry was built from a different source than the lock records." 1>&2
		echo "Re-resolve with \`nimble setup\` in ${STATUS_ENV_ROOT}; if it persists, remove the foreign nim from the store." 1>&2
		PATH="${STATUS_ENV_PATH0}"
		export PATH
		status_env_cleanup
		return 1 2>/dev/null || exit 1
	fi

	if [ -z "${STATUS_NIM_WANT}" ] && [ -n "${STATUS_NIM_PIN}" ]; then
		# Degraded assert (R2): the lock records no `nim` package, so the
		# checksum half of the entry name is unknown — version only, and say so.
		if [ "${STATUS_NIM_HAVE}" != "${STATUS_NIM_PIN}" ]; then
			echo "ERROR: the Nim that \`nimble shellenv\` puts first is NOT the pinned version." 1>&2
			echo "  pinned by nim_status_client.nimble: nim == ${STATUS_NIM_PIN}" 1>&2
			echo "  first on shellenv's PATH:           ${STATUS_NIM_BIN} (entry ${STATUS_NIM_ENTRY})" 1>&2
			echo "Re-resolve with \`nimble setup\` in ${STATUS_ENV_ROOT}; if it persists, remove the foreign nim from the store." 1>&2
			PATH="${STATUS_ENV_PATH0}"
			export PATH
			status_env_cleanup
			return 1 2>/dev/null || exit 1
		fi
		echo "WARNING: nimble.lock records no \`nim\` package — asserting the pinned VERSION only" 1>&2
		echo "  (${STATUS_NIM_PIN}); the store entry's checksum could not be checked. Run \`nimble lock\`." 1>&2
	fi

	# The entry must actually carry a compiler: shellenv prints the PATH the
	# resolution names, not proof that anything materialised there (R2).
	if [ ! -x "${STATUS_NIM_BIN}/nim" ]; then
		echo "ERROR: the pinned Nim entry on shellenv's PATH has no executable compiler:" 1>&2
		echo "  ${STATUS_NIM_BIN}/nim" 1>&2
		echo "The store entry is incomplete (an interrupted \`nimble setup\`?)." 1>&2
		echo "Re-run \`nimble setup\` in ${STATUS_ENV_ROOT}." 1>&2
		PATH="${STATUS_ENV_PATH0}"
		export PATH
		status_env_cleanup
		return 1 2>/dev/null || exit 1
	fi

	# Idempotent: re-sourcing must not grow PATH (M1).
	if [ "${PATH%%:*}" != "${STATUS_NIM_BIN}" ]; then
		PATH="${STATUS_NIM_BIN}:${PATH}"
	fi
else
	echo "WARNING: no pinned Nim (pkgs2/nim-*/bin) in \`nimble shellenv\`'s PATH — is the graph resolved?" 1>&2
fi

# shellenv itself re-prepends its dirs to the PATH it inherits, so a second
# `source ./env.sh` would duplicate them: keep the first occurrence of each.
# Both arms dedupe — the WARNING path grew PATH per re-source before (R5).
PATH="$(printf '%s' "${PATH}" | awk -v RS=: -v ORS= '!seen[$0]++ { if (n++) printf ":"; printf "%s", $0 }')"
export PATH

if [ "${STATUS_ENV_SOURCED}" = "0" ] && [ "$#" -gt 0 ]; then
	# EXECUTED with arguments: run them in this environment. Never when sourced —
	# a sourced file sees the CALLER's positional parameters, and `exec`ing those
	# would replace the caller with its own argv (C2/R1).
	if [ "$#" = 1 ] && [ "$1" = "bash" ]; then
		export PS1="[status env] \[\033[0;32m\]\w\[\033[0m\]\n\u\$ "
		status_env_cleanup
		exec bash --login --noprofile
	fi
	status_env_cleanup
	exec "$@"
fi

status_env_cleanup
