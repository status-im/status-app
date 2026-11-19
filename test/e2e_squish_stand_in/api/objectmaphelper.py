"""Squish's ``objectmaphelper`` module: patterns for object-map values."""
import re


def _wildcard(pattern):
    return re.compile(re.escape(pattern).replace(r"\*", ".*").replace(r"\?", "."))


class RegularExpression:
    def __init__(self, pattern):
        try:
            self.pattern = re.compile(pattern)
        except re.error:
            # The suite's map has RegularExpression("*"), which Squish accepts.
            self.pattern = _wildcard(pattern)


class Wildcard:
    def __init__(self, pattern):
        self.pattern = _wildcard(pattern)
