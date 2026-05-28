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

# Fail loudly if our toolchain isn't on PATH — silent skip masks a broken
# build (e.g., post-link stripping leaves no .symtab, then a misconfigured
# nm reports "no symbols" and we never canonicalize anything).
command -v "$NM" >/dev/null      || { echo "[canonicalize-cgo] $NM not found on PATH" >&2; exit 1; }
command -v "$OBJCOPY" >/dev/null || { echo "[canonicalize-cgo] $OBJCOPY not found on PATH" >&2; exit 1; }

# Read BOTH static and dynamic symbol tables (-D includes .dynsym, needed
# when -s stripping has removed .symtab).
list_symbols() { "$NM" -D -P "$SO_PATH"; "$NM" -P "$SO_PATH" 2>/dev/null || true; }

mapfile -t HASHES < <(
  list_symbols | awk '{print $1}' \
    | grep -Eo '^_cgo(exp)?_[0-9a-f]{12,16}_' \
    | sed -E 's/^_cgo(exp)?_([0-9a-f]+)_/\2/' \
    | sort -u
)

if [[ ${#HASHES[@]} -eq 0 ]]; then
  echo "[canonicalize-cgo] no cgo hash symbols found in $SO_PATH" >&2
  echo "[canonicalize-cgo] this is unexpected for a cgo build; check that nm reads .dynsym" >&2
  exit 1
fi

# Build the mapping: every discovered hash -> c0de<sha256-prefix>, where the
# sha256 is computed over the sorted set of symbol names that use this hash
# (with the hash itself replaced by a placeholder so the input is content-only).
# Same package source → same symbol set → same canonical, every build, every
# machine. Sort-order-based assignment is NOT safe here: when two builds
# produce different random hashes, sorting them yields different orderings
# and the same package gets a different canonical position. Content-derivation
# avoids that.
MAPPING=$(mktemp)
PERL_SCRIPT=""
trap 'rm -f "$MAPPING"' EXIT

# Pick a sha256 tool that's available on both macOS and Debian-derived fdroid
# builders. Both ship at least one of these.
if command -v sha256sum >/dev/null 2>&1; then
  SHA256="sha256sum"
else
  SHA256="shasum -a 256"
fi

rewrites=0
for HASH in "${HASHES[@]}"; do
  LEN=${#HASH}
  SHA_LEN=$((LEN - 4))
  STABLE=$(
    list_symbols | awk '{print $1}' \
      | grep -E "_cgo(exp)?_${HASH}_" \
      | sed "s/${HASH}/X/g" \
      | sort -u \
      | $SHA256 | awk '{print $1}'
  )
  CANON="c0de${STABLE:0:$SHA_LEN}"

  if [[ "$HASH" == "$CANON" ]]; then
    continue
  fi
  rewrites=$((rewrites + 1))

  list_symbols | awk '{print $1}' \
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
