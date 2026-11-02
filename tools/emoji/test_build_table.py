#!/usr/bin/env python3
"""Unit tests for build-table.py. Run: python3 -m unittest discover -s tools/emoji"""
import importlib.util
import json
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
_spec = importlib.util.spec_from_file_location(
    "build_table", os.path.join(HERE, "build-table.py"))
bt = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(bt)


class Table(unittest.TestCase):
    def test_committed_table_is_what_the_catalogue_produces(self):
        with open(bt.bc.CATALOGUE, encoding="utf-8") as f:
            rows = json.load(f)
        with open(bt.OUT, encoding="utf-8") as f:
            committed = f.read()
        self.assertEqual(bt.generate(rows), committed,
                         "run tools/emoji/build-table.py")

    def test_skin_follows_the_first_tone_in_tone_order(self):
        self.assertEqual(bt.skin_of({"unicode": "1f600", "hasSkins": False}), 0)
        self.assertEqual(bt.skin_of({"unicode": "1f44d", "hasSkins": True}), 1)
        self.assertEqual(bt.skin_of({"unicode": "1f44d-1f3fd", "hasSkins": False}), 4)
        self.assertEqual(
            bt.skin_of({"unicode": "1f9d1-1f3ff-200d-1f91d-200d-1f9d1-1f3fb",
                        "hasSkins": False}), 2)


if __name__ == "__main__":
    unittest.main()
