#!/usr/bin/env bash
# Canonicalize Go cgo's per-build symbol hashes so libstatus.so is byte-identical
# across builds. `go build` regenerates these hashes on every invocation because
# they derive from the build's temp dir path. No build flag fixes it; the hash
# is baked into actual symbol names like _cgo_<hash>_Cfunc_free and
# _cgoexp_<hash>_AcceptTerms.
#
# cgo emits ONE hash per cgo-using package (status-go core, libwaku, libsds,
# ethereum bindings, etc.), so a c-shared library that aggregates many such
# packages contains many distinct hashes. We discover them all, assign each
# a unique deterministic canonical value based on its sorted order, then
# rewrite both the symbol table (objcopy) and any embedded copies (perl).

set -euo pipefail

SO_PATH="${1:?Usage: $0 <path-to-libstatus.so>}"
NM="${NM:-llvm-nm}"
OBJCOPY="${OBJCOPY:-llvm-objcopy}"

# Discover every per-build hash present in the binary, sorted.
mapfile -t HASHES < <(
  "$NM" -P "$SO_PATH" | awk '{print $1}' \
    | grep -Eo '^_cgo(exp)?_[0-9a-f]{12,16}_' \
    | sed -E 's/^_cgo(exp)?_([0-9a-f]+)_/\2/' \
    | sort -u
)

if [[ ${#HASHES[@]} -eq 0 ]]; then
  echo "[canonicalize-cgo] no cgo hash symbols found in $SO_PATH"
  exit 0
fi

# Build the mapping: every discovered hash -> cafef00d<index>, where <index>
# is zero-padded hex of position in the sorted list. Same set of hashes
# (same source code) always yields the same canonical mapping.
MAPPING=$(mktemp)
PERL_SCRIPT=""
trap 'rm -f "$MAPPING"' EXIT

i=0
rewrites=0
for HASH in "${HASHES[@]}"; do
  LEN=${#HASH}
  SUFFIX_LEN=$((LEN - 8))
  printf -v CANON "cafef00d%0${SUFFIX_LEN}x" "$i"
  i=$((i + 1))

  if [[ "$HASH" == "$CANON" ]]; then
    continue
  fi
  rewrites=$((rewrites + 1))

  "$NM" -P "$SO_PATH" | awk '{print $1}' \
    | grep -E "_cgo(exp)?_${HASH}_" | sort -u \
    | while read -r SYM; do
        printf '%s %s\n' "$SYM" "${SYM/$HASH/$CANON}"
      done \
    >> "$MAPPING"

  PERL_SCRIPT+="s/_cgo_${HASH}_/_cgo_${CANON}_/g;"
  PERL_SCRIPT+="s/_cgoexp_${HASH}_/_cgoexp_${CANON}_/g;"
done

if [[ $rewrites -eq 0 ]]; then
  echo "[canonicalize-cgo] all ${#HASHES[@]} hashes already canonical"
  exit 0
fi

echo "[canonicalize-cgo] rewriting $rewrites of ${#HASHES[@]} hashes in $SO_PATH"

# Step 1: symbol-table rename. Maintains .gnu.hash, .dynsym, .symtab, relocs.
"$OBJCOPY" --redefine-syms="$MAPPING" "$SO_PATH"

# Step 2: catch embedded copies (Go's .gopclntab, debug strings, rodata
# literals). Same-length substitution preserves ELF layout — no relocations
# need updating. One perl invocation handles all hashes at once to avoid
# rewriting the 80MB file N times.
perl -i -0777 -pe "$PERL_SCRIPT" "$SO_PATH"

echo "[canonicalize-cgo] done"
