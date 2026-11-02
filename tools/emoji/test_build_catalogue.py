#!/usr/bin/env python3
"""Unit tests for build-catalogue.py. Run: python3 -m unittest discover -s tools/emoji"""
import importlib.util
import json
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "build_catalogue", os.path.join(HERE, "build-catalogue.py"))
bc = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bc)

MESSAGES = {"groups": [
    {"key": "smileys-emotion", "message": "smileys & emotion", "order": 0},
    {"key": "people-body", "message": "people & body", "order": 1},
    {"key": "component", "message": "components", "order": 2},
    {"key": "flags", "message": "flags", "order": 9},
]}


def entry(hexcode, label, emoji, order, group=0, **extra):
    return dict(hexcode=hexcode, label=label, emoji=emoji, order=order,
                group=group, **extra)


def minimal_rows():
    """A base with one skin, plus a flag so the flags-are-last check passes."""
    data = [
        entry("1F44D", "thumbs up", "👍", 1, tags=["like"], emoticon=":+1:", skins=[
            entry("1F44D-1F3FB", "thumbs up: light skin tone", "👍🏻", 2, tone=1)]),
        entry("1F1FA-1F1F8", "flag: United States", "🇺🇸", 3, group=9),
    ]
    shortcodes = {"1F44D": ["thumbsup", "+1"], "1F44D-1F3FB": "thumbsup_tone1",
                  "1F1FA-1F1F8": "flag_us"}
    return bc.build_rows(data, shortcodes, MESSAGES)


class Helpers(unittest.TestCase):
    def test_slug(self):
        self.assertEqual(bc.slug("head shaking horizontally"),
                         "head_shaking_horizontally")
        self.assertEqual(bc.slug("flag: St. Kitts & Nevis"), "flag_st_kitts_nevis")
        self.assertEqual(bc.slug("keycap: *"), "keycap")

    def test_tone_suffix(self):
        self.assertEqual(bc.tone_suffix(1), "_tone1")
        # handshakes and couples carry one tone per person
        self.assertEqual(bc.tone_suffix([1, 2]), "_tone1_tone2")

    def test_shortcodes_of_accepts_both_shapes(self):
        codes = {"A": "one", "B": ["two", "three"]}
        self.assertEqual(bc.shortcodes_of("A", codes), ["one"])
        self.assertEqual(bc.shortcodes_of("B", codes), ["two", "three"])
        self.assertEqual(bc.shortcodes_of("missing", codes), [])

    def test_canonical_ignores_selectors_and_padding(self):
        self.assertEqual(bc.canonical("0031-fe0f-20e3"), "31-20e3")
        self.assertEqual(bc.canonical("00a9"), "a9")
        self.assertEqual(bc.canonical("2764"), "2764")
        self.assertEqual(bc.canonical("1f441-fe0f-200d-1f5e8-fe0f"),
                         "1f441-200d-1f5e8")


class BuildRows(unittest.TestCase):
    def test_base_and_skin(self):
        rows, _ = minimal_rows()
        base, skin, _flag = rows
        self.assertEqual(base["unicode"], "1f44d")
        self.assertEqual(base["shortname"], ":thumbsup:")
        self.assertEqual(base["aliases"], [":+1:"])
        self.assertTrue(base["hasSkins"])
        # the skin gets its own code, not the base's
        self.assertEqual(skin["shortname"], ":thumbsup_tone1:")
        self.assertFalse(skin["hasSkins"])
        # and inherits what is not tone-specific
        self.assertEqual(skin["keywords"], base["keywords"])
        self.assertEqual(skin["aliases_ascii"], base["aliases_ascii"])
        self.assertEqual(skin["category"], base["category"])
        self.assertEqual(skin["emoji_order"], 2)

    def test_emoticon_is_always_a_list(self):
        rows, _ = minimal_rows()
        self.assertEqual(rows[0]["aliases_ascii"], [":+1:"])
        data = [entry("1F600", "grinning face", "😀", 1, emoticon=[":)", ":-)"])]
        rows, _ = bc.build_rows(data, {"1F600": "grinning"}, MESSAGES)
        self.assertEqual(rows[0]["aliases_ascii"], [":)", ":-)"])

    def test_merged_and_named_categories(self):
        data = [entry("1F600", "grinning face", "😀", 1, group=0),
                entry("1F44B", "waving hand", "👋", 2, group=1),
                entry("1F1FA-1F1F8", "flag: United States", "🇺🇸", 3, group=9)]
        rows, _ = bc.build_rows(data, {}, MESSAGES)
        self.assertEqual([r["category"] for r in rows],
                         ["smileys, people & body", "smileys, people & body", "flags"])

    def test_components_and_regional_indicators_are_dropped(self):
        data = [entry("1F3FB", "light skin tone", "🏻", 1, group=2),
                dict(hexcode="1F1FA", label="regional indicator symbol letter u",
                     emoji="🇺", order=2),
                entry("1F600", "grinning face", "😀", 3)]
        rows, dropped = bc.build_rows(data, {"1F600": "grinning"}, MESSAGES)
        self.assertEqual([r["unicode"] for r in rows], ["1f600"])
        self.assertEqual(dropped, {"components": 1, "regional indicators": 1})

    def test_unnamed_entries_fall_back_to_the_label(self):
        """The Emoji 15.1 additions: no preset names them, and their skins
        carry the bare base label, so the tone has to come from `tone`."""
        data = [entry("1F6B6-200D-27A1-FE0F", "person walking facing right", "🚶‍➡️",
                      1, tags=["walk"], skins=[
                          entry("1F6B6-1F3FB-200D-27A1-FE0F",
                                "person walking facing right", "🚶🏻‍➡️", 2, tone=1),
                          entry("1FAF1-1F3FB-200D-1FAF2-1F3FC",
                                "person walking facing right", "🚶🏻‍➡️", 3, tone=[1, 2]),
                      ])]
        rows, _ = bc.build_rows(data, {}, MESSAGES)
        self.assertEqual([r["shortname"] for r in rows],
                         [":person_walking_facing_right:",
                          ":person_walking_facing_right_tone1:",
                          ":person_walking_facing_right_tone1_tone2:"])
        self.assertEqual([r["aliases"] for r in rows], [[], [], []])


class Serialisation(unittest.TestCase):
    def test_matches_the_committed_style(self):
        text = bc.dumps([{"aliases": [], "emoji": "😀", "unicode": "1f600",
                          "hasSkins": False, "keywords": ["face"]}])
        self.assertEqual(text, """[
    {
        "aliases": [
        ],
        "emoji": "😀",
        "hasSkins": false,
        "keywords": [
            "face"
        ],
        "unicode": "1f600"
    }
]
""")

    def test_reproduces_the_committed_catalogue_byte_for_byte(self):
        """Guards the serialiser against the real file, not a sample."""
        if not os.path.exists(bc.CATALOGUE):
            self.skipTest("catalogue not present")
        with open(bc.CATALOGUE, encoding="utf-8") as f:
            committed = f.read()
        self.assertEqual(bc.dumps(json.loads(committed)), committed)


class Validation(unittest.TestCase):
    def setUp(self):
        self.rows, self.dropped = minimal_rows()
        self.dropped["regional indicators"] = 26
        self.manifest = {"metadata": {"expected_entries": len(self.rows)}}

    def validate(self, rows=None, manifest=None):
        bc.validate(rows or self.rows, manifest or self.manifest, self.dropped)

    def assertRejects(self, fragment, rows=None, manifest=None):
        with self.assertRaises(SystemExit) as caught:
            self.validate(rows, manifest)
        self.assertIn(fragment, str(caught.exception))

    def test_accepts_a_sound_catalogue(self):
        self.validate()

    def test_rejects_a_changed_entry_count(self):
        self.assertRejects("expected 99 entries",
                           manifest={"metadata": {"expected_entries": 99}})

    def test_rejects_duplicate_ids(self):
        rows = json.loads(json.dumps(self.rows))
        rows[1]["unicode"] = rows[0]["unicode"]
        self.assertRejects("duplicate unicode", rows)

    def test_rejects_ids_that_collide_once_normalised(self):
        rows = json.loads(json.dumps(self.rows))
        rows[1]["unicode"] = "0001f44d"
        self.assertRejects("collide once normalised", rows)

    def test_rejects_duplicate_or_empty_shortnames(self):
        rows = json.loads(json.dumps(self.rows))
        rows[1]["shortname"] = rows[0]["shortname"]
        self.assertRejects("duplicate shortname", rows)

        rows = json.loads(json.dumps(self.rows))
        rows[1]["shortname"] = "::"
        self.assertRejects("no shortname", rows)

    def test_rejects_malformed_shortnames(self):
        rows = json.loads(json.dumps(self.rows))
        rows[1]["shortname"] = "thumbsup_tone1"
        self.assertRejects("malformed shortnames", rows)

    def test_rejects_an_unknown_category(self):
        rows = json.loads(json.dumps(self.rows))
        rows[1]["category"] = "component"
        self.assertRejects("does not know", rows)

    def test_rejects_a_split_category_block(self):
        # the picker jumps to a category by index, so one block per category
        rows = json.loads(json.dumps(self.rows))
        rows.insert(1, dict(rows[0], category="animals & nature",
                            unicode="1f436", shortname=":dog:"))
        self.assertRejects("not contiguous", rows,
                           manifest={"metadata": {"expected_entries": len(rows)}})

    def test_rejects_flags_that_are_not_last(self):
        rows = list(reversed(json.loads(json.dumps(self.rows))))
        self.assertRejects("flags are not the last block", rows)

    def test_rejects_a_base_entry_carrying_a_tone(self):
        rows = json.loads(json.dumps(self.rows))
        rows[0]["unicode"] = "1f44d-1f3fb"
        self.assertRejects("carries a tone", rows)


if __name__ == "__main__":
    unittest.main()
