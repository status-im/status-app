#!/usr/bin/env bash
# Generate an MSVC import library (.lib) for a DLL from its C header.
#
# The Windows build links the nim client with clang/lld-link (MSVC ABI) so it can
# use Qt's msvc2022_64 build. Unlike mingw's `ld`, lld-link cannot link against a
# .dll directly — it needs an import library. The project's Go/Nim c-shared DLLs
# (libstatus, libkeycard, libsds) ship only a .dll + .h, so we synthesize the
# import lib here: extract the exported symbols from the header (cleaner than the
# DLL's raw export table, which re-exports unrelated Windows API names) and feed
# them to llvm-dlltool.
#
# Usage: gen-import-lib.sh <header> <dll-file-name> <output.lib>
#   <header>        path to the c-shared header (… __declspec(dllexport) decls)
#   <dll-file-name> the DLL's on-disk name, e.g. libstatus.dll (recorded in the
#                   import lib so the loader finds the right DLL at runtime)
#   <output.lib>    path of the import library to create
set -eu

header="$1"
dll_name="$2"
out_lib="$3"

if [ ! -f "$header" ]; then
  echo "gen-import-lib: header not found: $header" >&2
  exit 1
fi

def_file="${out_lib%.lib}.def"

# Pull the exported function names out of the header. Two header styles:
#  * Go c-shared:  extern __declspec(dllexport) char* SomeFunc(char* x);
#  * Nim c-shared (plain): void* SomeFunc(SomeCb cb, void* userData);
# In both cases capture the identifier immediately before the '(' that follows
# the return type. For the plain style, skip typedefs/comments/preprocessor and
# function-pointer typedefs so we only pick up real exported functions.
if grep -q "__declspec(dllexport)" "$header"; then
  names=$(sed -nE 's/.*__declspec\(dllexport\)[[:space:]]+[A-Za-z_][A-Za-z0-9_[:space:]\*]*[[:space:]\*]([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\1/p' "$header" | sort -u)
else
  names=$(grep -vE '^[[:space:]]*(typedef|//|/\*|\*|#|extern[[:space:]]+"C")' "$header" \
    | sed -nE 's/^[[:space:]]*[A-Za-z_][A-Za-z0-9_[:space:]\*]*[[:space:]\*]([A-Za-z_][A-Za-z0-9_]*)[[:space:]]*\(.*/\1/p' | sort -u)
fi

if [ -z "$names" ]; then
  echo "gen-import-lib: no __declspec(dllexport) symbols found in $header" >&2
  exit 1
fi

{
  echo "LIBRARY $dll_name"
  echo "EXPORTS"
  echo "$names"
} > "$def_file"

# Resolve llvm-dlltool. The compiler is invoked via its absolute path
# (CLANGWRAP_CLANG), so the LLVM bin isn't necessarily on PATH here. Fall back to
# asking clang for its toolchain bin (works even when clang is a shim).
dlltool=""
if command -v llvm-dlltool >/dev/null 2>&1; then
  dlltool="llvm-dlltool"
else
  clang="${CLANGWRAP_CLANG:-}"
  if [ -z "$clang" ] || [ ! -e "$clang" ]; then
    clang="$(command -v clang 2>/dev/null || true)"
  fi
  if [ -n "$clang" ]; then
    progdir="$("$clang" -print-search-dirs 2>/dev/null | sed -n 's/^programs: =//p' | tr ';' '\n' | head -1 | tr '\\' '/')"
    for cand in "$progdir/llvm-dlltool.exe" "$progdir/llvm-dlltool" \
                "$(dirname "$clang")/llvm-dlltool.exe" "$(dirname "$clang")/llvm-dlltool"; do
      if [ -n "$cand" ] && [ -e "$cand" ]; then dlltool="$cand"; break; fi
    done
  fi
fi
if [ -z "$dlltool" ]; then
  echo "gen-import-lib: llvm-dlltool not found (not on PATH and not next to clang)" >&2
  exit 1
fi

# i386:x86-64 == x64.
"$dlltool" -m i386:x86-64 -d "$def_file" -D "$dll_name" -l "$out_lib"
echo "gen-import-lib: wrote $out_lib ($(printf '%s\n' "$names" | wc -l) symbols) for $dll_name"
