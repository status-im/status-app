#!/bin/sh
# Prints the path of the Nim compiler nim_status_client.nimble pins: $STATUS_NIM,
# else the store entry (`nimble path nim` lists every nim in the store, so it is
# picked by name), else a `nim` on PATH. Version-checked in every case.
set -eu
root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
pin=$(sed -n -E 's/^[[:space:]]*requires[[:space:]]+"nim[[:space:]]*==[[:space:]]*([^"[:space:]]+)".*/\1/p' \
      "$root/nim_status_client.nimble" | head -n 1)
nim=${STATUS_NIM:-}
if [ -z "$nim" ]; then
	# Line by line: a store under a spaced HOME must not be word-split. A prefix
	# test, not `case`: bash 3.2 cannot parse a case pattern's closing paren inside $( ).
	nim=$(cd "$root" && nimble path nim 2>/dev/null | while IFS= read -r entry; do
		# nimble emits native paths: backslash-separated on Windows.
		base=${entry##*/}
		base=${base##*\\}
		if [ "${base#"nim-$pin-"}" != "$base" ] && [ -x "$entry/bin/nim" ]; then
			printf '%s\n' "$entry/bin/nim"; break
		fi
	done)
	[ -n "$nim" ] || nim=$(command -v nim 2>/dev/null || true)
fi
# Forward slashes: sh strips the backslashes of a native Windows path.
nim=$(printf '%s' "$nim" | tr '\\' '/')
[ -n "$nim" ] || { echo "resolve-nim: nimble's store has no Nim $pin yet; 'make update' (or the make you just started) runs 'nimble setup' to fetch it" >&2; exit 1; }
case $("$nim" --version 2>/dev/null | head -n 1) in
	"Nim Compiler Version $pin "*) ;;
	*) echo "resolve-nim: $nim is not Nim $pin (the manifest pin); run 'nimble setup' or remove it from PATH" >&2; exit 1 ;;
esac
printf '%s\n' "$nim"
