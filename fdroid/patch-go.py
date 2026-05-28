#!/usr/bin/env python3
import os
import re
import sys

def patch_file(path, anchor_re, replacement, marker):
    """Replace `anchor_re` match with `replacement` in file at `path`.

    `marker` is a unique substring present in `replacement`. If `marker` is
    already in the file, the patch is treated as already-applied and skipped.
    This makes re-running safe (idempotent) even when the anchor would still
    match a region that already contains the inserted code.

    - marker present: skip silently, return False.
    - 0 anchor matches AND no marker: raise; source has drifted.
    - 1 anchor match: apply the patch, return True.
    - 2+ anchor matches: raise; anchor is too loose.
    """
    with open(path) as f:
        src = f.read()
    if marker in src:
        return False
    matches = list(re.finditer(anchor_re, src))
    if len(matches) == 0:
        raise RuntimeError(
            f"{path}: anchor did not match and marker {marker!r} not present. "
            f"Go source may have drifted; patch needs updating."
        )
    if len(matches) > 1:
        raise RuntimeError(
            f"{path}: anchor matched {len(matches)} times (expected 1). "
            f"Go source may have drifted; patch needs updating."
        )
    src = src[: matches[0].start()] + replacement + src[matches[0].end() :]
    with open(path, "w") as f:
        f.write(src)
    print(f"[patch-go-repro] {path}: patched ({marker})")
    return True


def add_import(path, new_import):
    """Add `new_import` to the file's import block if not already present."""
    with open(path) as f:
        src = f.read()
    if f'"{new_import}"' in src:
        return False
    pattern = r'(\n\t"strings")'
    if not re.search(pattern, src):
        raise RuntimeError(f'{path}: could not find anchor "strings" import')
    src = re.sub(pattern, f'\n\t"{new_import}"\\1', src, count=1)
    with open(path, "w") as f:
        f.write(src)
    print(f"[patch-go-repro] {path}: added import {new_import}")
    return True


def patch_deadcode(goroot):
    """Sort d.markableMethods before the iteration that decides reachability."""
    path = os.path.join(goroot, "src/cmd/link/internal/ld/deadcode.go")

    anchor = re.compile(
        r"(\t\trem := d\.markableMethods\[:0\]\n"
        r"\t\tfor _, m := range d\.markableMethods \{)",
    )
    replacement = (
        "\t\t// REPRO_PATCH_markableMethods: sort markableMethods so reachability\n"
        "\t\t// decisions are made in deterministic order. Without this, Go's\n"
        "\t\t// per-process random map iteration produces different itab tables\n"
        "\t\t// in runtime metadata between back-to-back -buildmode=c-shared builds.\n"
        "\t\tsort.Slice(d.markableMethods, func(i, j int) bool {\n"
        "\t\t\ta, b := d.markableMethods[i], d.markableMethods[j]\n"
        "\t\t\tif a.src != b.src {\n"
        "\t\t\t\treturn a.src < b.src\n"
        "\t\t\t}\n"
        "\t\t\tif a.m.name != b.m.name {\n"
        "\t\t\t\treturn a.m.name < b.m.name\n"
        "\t\t\t}\n"
        "\t\t\treturn a.m.typ < b.m.typ\n"
        "\t\t})\n"
        "\t\trem := d.markableMethods[:0]\n"
        "\t\tfor _, m := range d.markableMethods {"
    )

    if patch_file(path, anchor, replacement, marker="REPRO_PATCH_markableMethods"):
        add_import(path, "sort")


def patch_pcln(goroot):
    """Sort seen and fileOffsets iterations in pcln.go."""
    path = os.path.join(goroot, "src/cmd/link/internal/ld/pcln.go")

    pctab_anchor = re.compile(
        r"(\t\tsb := ldr\.MakeSymbolUpdater\(s\)\n"
        r"\t\tfor sym := range seen \{\n"
        r"\t\t\tsb\.SetBytesAt\(ldr\.SymValue\(sym\), ldr\.Data\(sym\)\)\n"
        r"\t\t\}\n"
        r"\t\}\n)",
    )
    pctab_replacement = (
        "\t\tsb := ldr.MakeSymbolUpdater(s)\n"
        "\t\t// REPRO_PATCH_pctabSeen: iterate in symbol-id order.\n"
        "\t\tseenSorted := make([]loader.Sym, 0, len(seen))\n"
        "\t\tfor sym := range seen {\n"
        "\t\t\tseenSorted = append(seenSorted, sym)\n"
        "\t\t}\n"
        "\t\tsort.Slice(seenSorted, func(i, j int) bool { return seenSorted[i] < seenSorted[j] })\n"
        "\t\tfor _, sym := range seenSorted {\n"
        "\t\t\tsb.SetBytesAt(ldr.SymValue(sym), ldr.Data(sym))\n"
        "\t\t}\n"
        "\t}\n"
    )

    filetab_anchor = re.compile(
        r"(\t\t// Write the strings\.\n"
        r"\t\tfor filename, loc := range fileOffsets \{\n"
        r"\t\t\tsb\.AddStringAt\(int64\(loc\), expandFile\(filename\)\)\n"
        r"\t\t\}\n)",
    )
    filetab_replacement = (
        "\t\t// REPRO_PATCH_filetabFileOffsets: write in filename-sorted order.\n"
        "\t\tnames := make([]string, 0, len(fileOffsets))\n"
        "\t\tfor filename := range fileOffsets {\n"
        "\t\t\tnames = append(names, filename)\n"
        "\t\t}\n"
        "\t\tsort.Strings(names)\n"
        "\t\tfor _, filename := range names {\n"
        "\t\t\tloc := fileOffsets[filename]\n"
        "\t\t\tsb.AddStringAt(int64(loc), expandFile(filename))\n"
        "\t\t}\n"
    )

    patched_any = False
    patched_any |= patch_file(path, pctab_anchor, pctab_replacement, marker="REPRO_PATCH_pctabSeen")
    patched_any |= patch_file(path, filetab_anchor, filetab_replacement, marker="REPRO_PATCH_filetabFileOffsets")
    if patched_any:
        add_import(path, "sort")


def main():
    if len(sys.argv) != 2:
        print(__doc__, file=sys.stderr)
        sys.exit(2)
    goroot = sys.argv[1]
    if not os.path.isdir(os.path.join(goroot, "src/cmd/link")):
        print(f"[patch-go-repro] {goroot} is not a valid GOROOT", file=sys.stderr)
        sys.exit(1)

    print(f"[patch-go-repro] applying linker reproducibility patches to {goroot}")
    patch_deadcode(goroot)
    patch_pcln(goroot)
    print("[patch-go-repro] done")


if __name__ == "__main__":
    main()
