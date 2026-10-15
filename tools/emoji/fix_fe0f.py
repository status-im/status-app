#!/usr/bin/env python3
"""Add FE0F-less aliases to a colour font's ccmp ligatures.

HarfBuzz (and therefore Qt) deletes variation selectors before GSUB runs, so a
ligature rule keyed on an explicit U+FE0F glyph can never match: 👩‍⚕️ 🏳️‍🌈 🏴‍☠️
and friends would render as their separate components.

nanoemoji derives its ligatures from the input filenames, and Twemoji keeps
`fe0f` in the names of ZWJ sequences, so ~950 rules need an FE0F-less twin.
Google's own Noto emoji fonts sidestep this by not mapping FE0F at all.

Usage: fix_fe0f.py IN.ttf OUT.ttf
"""
import sys

from fontTools.ttLib import TTFont
from fontTools.ttLib.tables.otTables import Ligature, LigatureSubst


def add_aliases(src: str, dst: str) -> int:
    font = TTFont(src)
    fe0f = font.getBestCmap().get(0xFE0F)
    if fe0f is None:
        print("font does not map FE0F; nothing to do")
        font.save(dst)
        return 0

    added = 0
    for lookup in font["GSUB"].table.LookupList.Lookup:
        for sub in lookup.SubTable:
            if not isinstance(sub, LigatureSubst):
                continue

            known = {(first, tuple(lig.Component))
                     for first, ligs in sub.ligatures.items() for lig in ligs}
            new_entries = []
            for first, ligs in sub.ligatures.items():
                for lig in ligs:
                    sequence = [first] + list(lig.Component)
                    if fe0f not in sequence:
                        continue
                    stripped = [g for g in sequence if g != fe0f]
                    if len(stripped) < 2:
                        continue
                    key = (stripped[0], tuple(stripped[1:]))
                    if key in known:
                        continue
                    known.add(key)
                    new_entries.append((key, lig.LigGlyph))

            for (first, components), lig_glyph in new_entries:
                alias = Ligature()
                alias.Component = list(components)
                alias.CompCount = len(components) + 1
                alias.LigGlyph = lig_glyph
                sub.ligatures.setdefault(first, []).append(alias)
                added += 1

            # longest match must come first
            for ligs in sub.ligatures.values():
                ligs.sort(key=lambda lig: len(lig.Component), reverse=True)

    font.save(dst)
    return added


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    count = add_aliases(sys.argv[1], sys.argv[2])
    print(f"added {count} FE0F-less ligature aliases -> {sys.argv[2]}")
