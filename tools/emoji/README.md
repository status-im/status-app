# Emoji assets

The emoji font and the emoji catalogue are **generated artifacts**. Everything
they are built from is pinned in [`manifest.json`](manifest.json).

| Artifact | Built from | Lands in |
|---|---|---|
| `StatusTwemoji-COLRv0.ttf` | Twemoji SVGs | `ui/StatusQ/src/assets/fonts/` |
| `StatusTwemoji-COLRv0.LICENSE` | Twemoji's own LICENSE, verbatim | `ui/StatusQ/src/assets/fonts/` |
| `emojiList.json` | emojibase raw data | `ui/StatusQ/src/StatusQ/Core/Utils/` and `test/e2e/ext/test_files/emojis_unicodes_list.json` |
| `emojitable_data.cpp` | `emojiList.json` | `ui/StatusQ/src/` |

## Rebuilding

```sh
./fetch-sources.sh      # downloads the pinned sources into .work/ (checksummed)
./build-font.sh         # ~7 min; writes the font and prints a summary
./build-catalogue.py    # writes emojiList.json and the e2e copy
./build-table.py        # writes emojitable_data.cpp from emojiList.json
```

Then run the StatusQ emoji conformance test before committing. Both artifacts
are committed to the repo, so this is only needed when `manifest.json` changes.

`StatusEmojiModel` serves the catalogue from `emojitable_data.cpp`, a table of
read-only data with no pointers in it: the catalogue is never parsed nor copied
to the heap, and its pages stay file-backed. The json is not shipped in the app.
The table is committed rather than generated during the build so StatusQ builds
need no Python. CI catches drift through StatusQ's `TestStatusEmojiModel`
(ctest, run by `make run-statusq-tests`): it compares every row against
`emojiList.json` and looks every entry up through each sorted index (hexcode,
its normalised form, shortname, ASCII emoticon) and the category starts.
`build-table.py --check` (fails if `emojitable_data.cpp` is not what
`emojiList.json` produces) and `test_build_table.py` are not run by CI; run them
by hand after a rebuild.

`build-catalogue.py --check` regenerates in memory and fails if the committed
files are not what the pinned sources produce;
`python3 -m unittest discover -s tools/emoji` covers the generators themselves.
Both are manual too. `build-catalogue.py` refuses to write a catalogue that
would break the app: it checks the entry count, that ids are unique (also once
normalised, which is how stored ids are resolved), that every entry has a unique
well-formed shortname, that categories match the list
`StatusEmojiModel::categories()` hard-codes and form one block each, and that
flags are the last block (the random account emoji relies on it).

## Bumping a version

1. Edit `manifest.json`, including the checksums: the tarball sha256 for new
   artwork, the per-file sha256 for new metadata.
2. Re-run the scripts (`build-catalogue.py` and `build-table.py` for a metadata
   bump, the font scripts for an artwork bump) and review the diff.
3. Run the conformance test: it checks ZWJ sequences, VS16 sequences, skin
   tones, flags and keycaps, and that every `emojiList.json` entry resolves to
   a real glyph.

Keep the artwork and metadata versions compatible: the font comes from Twemoji,
the picker list from emojibase, and an entry the font has no glyph for shows up
as tofu in the picker.

Shortcodes come from emojibase's joypixels preset, which does not name the Emoji
15.1 additions (head shaking, "… facing right", broken chain, lime, family) -
and neither do its cldr and emojibase presets. Those fall back to a slug of the
CLDR label, `:head_shaking_horizontally:`, with joypixels' `_tone1`…`_tone5`
suffix for skin variants. Without a shortname the suggestion list draws a blank
row, so `build-catalogue.py` fails rather than emit one.

The font is a derivative of the Twemoji artwork, so its licence ships with it:
`StatusTwemoji-COLRv0.LICENSE` sits next to the font and `fonts.qrc` embeds it
as `:/assets/licenses/StatusTwemoji-COLRv0.LICENSE` (not under `/assets/fonts`,
where every file is expected to be a loadable font).

## Why these settings

**`glyf_colr_0`** — COLRv0 is the only colour-font format that renders on all
three desktop platforms with our Qt. COLRv1 draws nothing on Linux (Qt's
FreeType COLRv1 path needs FreeType >= 2.13 at build time; the official Qt
binaries link an older one) and has no implementation in Qt's CoreText engine
on macOS. CBDT does not render on macOS either. Twemoji artwork is almost
entirely flat fills, so COLRv0 loses nothing.

**`upem 1024 / width 1024 / ascender 824 / descender -200`** — an em-square box,
so `font.pixelSize` *is* the rendered emoji size and emoji do not change the
height of a line of text. nanoemoji's defaults (1.245 em advance, 1.172 em
artwork) draw noticeably larger than the surrounding text.

**`fix_fe0f.py`** — mandatory post-pass; see the docstring. Without it every
sequence containing U+FE0F renders as separate components.
