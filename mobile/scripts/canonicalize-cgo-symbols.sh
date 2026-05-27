#!/usr/bin/env bash
# Canonicalize Go cgo's per-build symbol hash so libstatus.so is byte-identical
# across builds. `go build` regenerates the hash on every invocation because it
# derives from the build's temp dir path. No build flag fixes it; the hash is
# baked into actual symbol names like _cgo_<hash>_Cfunc_free and
# _cgoexp_<hash>_AcceptTerms. We rewrite the symbol table AND any embedded
# string copies (gopclntab, debug strings, rodata literals) to a fixed value.

set -euo pipefail

SO_PATH="${1:?Usage: $0 <path-to-libstatus.so>}"
CANONICAL_HASH="cafef00dcafef00d"
NM="${NM:-llvm-nm}"
OBJCOPY="${OBJCOPY:-llvm-objcopy}"

# Discover the per-build hash(es) present in the binary. Expected: exactly one.
mapfile -t HASHES < <(
  "$NM" -P "$SO_PATH" | awk '{print $1}' \
    | grep -Eo '^_cgo(exp)?_[0-9a-f]{12,16}_' \
    | sed -E 's/^_cgo(exp)?_([0-9a-f]+)_/\2/' \
    | sort -u
)

case ${#HASHES[@]} in
  0) echo "[canonicalize-cgo] no cgo hash symbols found in $SO_PATH"; exit 0 ;;
  1) ;;
  *) echo "[canonicalize-cgo] WARN: ${#HASHES[@]} distinct hashes (expected 1): ${HASHES[*]}" ;;
esac

HASH="${HASHES[0]}"
CANON="${CANONICAL_HASH:0:${#HASH}}"
if [[ "$HASH" == "$CANON" ]]; then
  echo "[canonicalize-cgo] already canonical ($HASH)"
  exit 0
fi

echo "[canonicalize-cgo] rewriting $HASH -> $CANON in $SO_PATH"

# Step 1: symbol-table rename. Maintains .gnu.hash, .dynsym, .symtab, relocs.
MAPPING=$(mktemp)
trap 'rm -f "$MAPPING"' EXIT
"$NM" -P "$SO_PATH" | awk '{print $1}' \
  | grep -E "_cgo(exp)?_${HASH}_" | sort -u \
  | while read -r SYM; do printf '%s %s\n' "$SYM" "${SYM/$HASH/$CANON}"; done \
  > "$MAPPING"
"$OBJCOPY" --redefine-syms="$MAPPING" "$SO_PATH"

# Step 2: catch embedded copies (Go's .gopclntab, debug strings, rodata
# literals). Same-length substitution preserves ELF layout — no relocations
# need updating.
perl -i -0777 -pe "
  s/_cgo_${HASH}_/_cgo_${CANON}_/g;
  s/_cgoexp_${HASH}_/_cgoexp_${CANON}_/g;
" "$SO_PATH"

echo "[canonicalize-cgo] done"
