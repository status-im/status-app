#!/usr/bin/env python3
"""Build the emoji catalogue from the pinned emojibase data.

The catalogue backs the picker grid, the `:shortname` suggestions, the ascii
emoticons, the recents list and the reaction id lookups. It is a generated
artifact: everything it is built from is pinned in manifest.json, and
fetch-sources.sh puts those files in .work/emojibase/.

Shortcodes come from the joypixels preset. It does not name the Emoji 15.1
additions (head shaking, "… facing right", broken chain, lime, family …), and
neither do emojibase's other presets, so those fall back to a slug of the CLDR
label - without a shortname the suggestion list draws a blank row.

Usage:
    build-catalogue.py            write the catalogue and the e2e copy
    build-catalogue.py --check    regenerate in memory and diff; non-zero on drift
"""
import argparse
import hashlib
import json
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.dirname(os.path.dirname(HERE))

CATALOGUE = os.path.join(REPO, "ui/StatusQ/src/StatusQ/Core/Utils/emojiList.json")
# The e2e suite reads its own copy; keeping it generated stops the two drifting.
E2E_COPY = os.path.join(REPO, "test/e2e/ext/test_files/emojis_unicodes_list.json")

# StatusEmojiModel::categories() hard-codes this list, and the picker's tab row
# is index-aligned with it. "recent" is synthesised at runtime.
CATEGORIES = ["smileys, people & body", "animals & nature", "food & drink",
              "travel & places", "activities", "objects", "symbols", "flags"]
# emojibase splits what the picker shows as one tab.
MERGED_GROUPS = {0: "smileys, people & body", 1: "smileys, people & body"}
COMPONENT_GROUP = 2          # skin tones and hair, not pickable on their own
REGIONAL_INDICATORS = range(0x1F1E6, 0x1F200)
SHORTNAME_RE = re.compile(r"^:[a-z0-9_+-]+:$")


def load_sources(work):
    """Return (data, shortcodes, messages), checked against the manifest."""
    with open(os.path.join(HERE, "manifest.json"), encoding="utf-8") as f:
        manifest = json.load(f)
    loaded = {}
    for entry in manifest["metadata"]["files"]:
        name = os.path.basename(entry["path"])
        path = os.path.join(work, "emojibase", name)
        if not os.path.exists(path):
            sys.exit(f"ERROR: {path} is missing; run ./fetch-sources.sh first")
        with open(path, "rb") as f:
            blob = f.read()
        got = hashlib.sha256(blob).hexdigest()
        if got != entry["sha256"]:
            sys.exit(f"ERROR: {name} does not match the manifest\n"
                     f"  expected {entry['sha256']}\n  got      {got}\n"
                     f"  re-run ./fetch-sources.sh")
        loaded[name] = json.loads(blob)
    return (manifest, loaded["data.raw.json"], loaded["joypixels.raw.json"],
            loaded["messages.raw.json"])


def slug(label):
    """A shortcode body from a CLDR label: "head shaking horizontally" -> ..."""
    return re.sub(r"[^a-z0-9]+", "_", label.lower()).strip("_")


def tone_suffix(tone):
    """joypixels' own convention: one tone per modifier, in sequence order."""
    tones = tone if isinstance(tone, list) else [tone]
    return "".join(f"_tone{t}" for t in tones)


def shortcodes_of(hexcode, shortcodes):
    """joypixels stores a bare string for some entries and a list for others."""
    value = shortcodes.get(hexcode)
    if value is None:
        return []
    return [value] if isinstance(value, str) else list(value)


def is_regional_indicator(hexcode):
    parts = hexcode.split("-")
    return len(parts) == 1 and int(parts[0], 16) in REGIONAL_INDICATORS


def row(entry, category, keywords, ascii_aliases, shortname, aliases, has_skins):
    return {
        "aliases": aliases,
        "aliases_ascii": ascii_aliases,
        "category": category,
        "emoji": entry["emoji"],
        "emoji_order": entry["order"],
        "hasSkins": has_skins,
        "keywords": keywords,
        "name": entry["label"],
        "shortname": shortname,
        "unicode": entry["hexcode"].lower(),
    }


def build_rows(data, shortcodes, messages):
    """Flatten emojibase into catalogue rows: each base followed by its skins."""
    group_names = {g["order"]: g["message"] for g in messages["groups"]}
    rows, dropped = [], {"components": 0, "regional indicators": 0}

    for entry in data:
        group = entry.get("group")
        if group is None and is_regional_indicator(entry["hexcode"]):
            dropped["regional indicators"] += 1
            continue
        if group == COMPONENT_GROUP:
            dropped["components"] += 1
            continue
        if group is None:
            sys.exit(f"ERROR: {entry['hexcode']} ({entry['label']}) has no group")

        category = MERGED_GROUPS.get(group) or group_names[group]
        keywords = entry.get("tags", [])
        emoticon = entry.get("emoticon", [])
        ascii_aliases = [emoticon] if isinstance(emoticon, str) else list(emoticon)
        skins = entry.get("skins", [])

        codes = shortcodes_of(entry["hexcode"], shortcodes)
        # Nothing names the 15.1 additions, so derive one from the CLDR label.
        base_body = codes[0] if codes else slug(entry["label"])
        shortname = f":{base_body}:"
        aliases = [f":{c}:" for c in codes[1:]]

        rows.append(row(entry, category, keywords, ascii_aliases,
                        shortname, aliases, bool(skins)))

        for skin in skins:
            skin_codes = shortcodes_of(skin["hexcode"], shortcodes)
            if skin_codes:
                skin_shortname = f":{skin_codes[0]}:"
                skin_aliases = [f":{c}:" for c in skin_codes[1:]]
            else:
                # The 15.1 skins carry the bare base label, so the tone has to
                # come from the `tone` field or every variant collides.
                skin_shortname = f":{base_body}{tone_suffix(skin['tone'])}:"
                skin_aliases = []
            # Keywords and emoticons stay the base's; the tone is not searchable.
            rows.append(row(skin, category, keywords, ascii_aliases,
                            skin_shortname, skin_aliases, False))

    return rows, dropped


def canonical(unicode_id):
    """The spelling-insensitive form of an id: no FE0F, no leading zeros.

    StatusEmojiModel resolves stored ids (recents, reactions) through the same
    normalisation, so two rows sharing a canonical form would be ambiguous.
    """
    parts = [p for p in unicode_id.split("-") if p != "fe0f"]
    return "-".join(p.lstrip("0") or "0" for p in parts)


def validate(rows, manifest, dropped):
    """Fail loudly rather than ship a catalogue the app cannot use."""
    problems = []

    def check(condition, message):
        if not condition:
            problems.append(message)

    expected = manifest["metadata"]["expected_entries"]
    check(len(rows) == expected,
          f"expected {expected} entries, built {len(rows)} "
          f"(bump expected_entries in manifest.json if this is intended)")
    check(dropped["regional indicators"] == 26,
          f"dropped {dropped['regional indicators']} regional indicators, expected 26")

    for field in ("unicode", "shortname"):
        seen = {}
        for r in rows:
            seen.setdefault(r[field], []).append(r["name"])
        dupes = {k: v for k, v in seen.items() if len(v) > 1}
        check(not dupes, f"duplicate {field}: {list(dupes.items())[:5]}")

    canon = {}
    for r in rows:
        canon.setdefault(canonical(r["unicode"]), []).append(r["unicode"])
    collisions = {k: v for k, v in canon.items() if len(v) > 1}
    check(not collisions,
          f"ids that collide once normalised: {list(collisions.items())[:5]}")

    unnamed = [r["name"] for r in rows if not r["shortname"].strip(":")]
    check(not unnamed, f"entries with no shortname: {unnamed[:5]}")

    malformed = [r["shortname"] for r in rows if not SHORTNAME_RE.match(r["shortname"])]
    malformed += [a for r in rows for a in r["aliases"] if not SHORTNAME_RE.match(a)]
    check(not malformed, f"malformed shortnames: {malformed[:5]}")

    unknown = sorted({r["category"] for r in rows} - set(CATEGORIES))
    check(not unknown,
          f"categories StatusEmojiModel::categories() does not know: {unknown}")

    # The picker jumps to a category by index, so a category must be one block.
    blocks = [r["category"] for i, r in enumerate(rows)
              if i == 0 or rows[i - 1]["category"] != r["category"]]
    check(len(blocks) == len(set(blocks)), f"categories are not contiguous: {blocks}")

    # The random account emoji excludes flags by taking only what comes before them.
    flags = [i for i, r in enumerate(rows) if r["category"] == "flags"]
    check(flags and flags[-1] == len(rows) - 1, "flags are not the last block")

    # skinColor is derived by looking for a tone codepoint inside the id.
    tones = tuple(f"1f3f{c}" for c in "bcdef")
    for r in rows:
        if r["hasSkins"]:
            check(not any(t in r["unicode"] for t in tones),
                  f"{r['name']} is a base entry but its id carries a tone")

    if problems:
        sys.exit("ERROR: " + "\nERROR: ".join(problems))


def dumps(rows):
    """Serialise the way QJsonDocument::Indented did, so diffs stay readable."""
    text = json.dumps(rows, indent=4, sort_keys=True, ensure_ascii=False)
    # Qt puts the closing bracket of an empty array on its own line.
    text = re.sub(r'( *)("[a-z_]+": )\[\]', r"\1\2[\n\1]", text)
    return text + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--work", default=os.path.join(HERE, ".work"),
                        help="where fetch-sources.sh put the sources")
    parser.add_argument("--check", action="store_true",
                        help="do not write; fail if the committed files differ")
    parser.add_argument("--out", default=CATALOGUE)
    parser.add_argument("--e2e-out", default=E2E_COPY)
    args = parser.parse_args()

    manifest, data, shortcodes, messages = load_sources(args.work)
    rows, dropped = build_rows(data, shortcodes, messages)
    validate(rows, manifest, dropped)
    text = dumps(rows)

    synthesised = sum(1 for r in rows
                      if not shortcodes_of(r["unicode"].upper(), shortcodes))
    print(f"{len(rows)} entries "
          f"({dropped['components']} components and "
          f"{dropped['regional indicators']} regional indicators dropped, "
          f"{synthesised} shortnames derived from CLDR labels)")

    status = 0
    for path in (args.out, args.e2e_out):
        if args.check:
            current = ""
            if os.path.exists(path):
                with open(path, encoding="utf-8") as f:
                    current = f.read()
            if current != text:
                print(f"DRIFT: {os.path.relpath(path, REPO)} is not what the "
                      f"pinned sources produce")
                status = 1
        else:
            with open(path, "w", encoding="utf-8") as f:
                f.write(text)
            print(f"wrote {os.path.relpath(path, REPO)}")
    return status


if __name__ == "__main__":
    sys.exit(main())
