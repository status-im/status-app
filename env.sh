#!/usr/bin/env bash
# The pinned Nim on PATH for editor tools (nimsuggest, nimlangserver); no build needs it.
# Usage: `./env.sh code .`, `./env.sh bash`, `source ./env.sh` (bash or zsh).
nim=$("$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/scripts/resolve-nim.sh") || { return 1 2>/dev/null || exit 1; }
nim_bin=$(dirname "$nim")
case ":$PATH:" in
	*":$nim_bin:"*) ;;
	*) export PATH="$nim_bin:$PATH" ;;
esac
unset nim nim_bin
# exec only when executed, never when sourced.
if [ "${BASH_SOURCE[0]:-}" = "$0" ] && [ "$#" -gt 0 ]; then
	exec "$@"
fi
