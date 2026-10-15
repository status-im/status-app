# Emoji assets

The emoji font and the emoji catalogue are **generated artifacts**. Everything
they are built from is pinned in [`manifest.json`](manifest.json).

| Artifact | Built from | Lands in |
|---|---|---|
| `StatusTwemoji-COLRv0.ttf` | Twemoji SVGs | `ui/StatusQ/src/assets/fonts/` |
| `emojiList.json` | emojibase raw data | `ui/StatusQ/src/StatusQ/Core/Utils/` |

## Rebuilding

```sh
./fetch-sources.sh     # downloads the pinned sources into .work/ (checksummed)
./build-font.sh        # ~7 min; writes the font and prints a summary
```

Then run the StatusQ emoji conformance test before committing. The generated
font is committed to the repo, so this is only needed when `manifest.json`
changes.

## Bumping a version

1. Edit `manifest.json` (and the tarball checksum for new artwork).
2. Re-run both scripts, plus the catalogue generator for metadata bumps.
3. Run the conformance test: it checks ZWJ sequences, VS16 sequences, skin
   tones, flags and keycaps, and that every `emojiList.json` entry resolves to
   a real glyph.

Keep the artwork and metadata versions compatible: the font comes from Twemoji,
the picker list from emojibase, and an entry the font has no glyph for shows up
as tofu in the picker.

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
