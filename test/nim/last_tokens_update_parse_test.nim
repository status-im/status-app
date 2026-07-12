## The `lastTokensUpdate` settings
## timestamp used to be parsed with a single strict format, raising a TimeParseError
## on the GUI thread at wake for any value that didn't match (e.g. a "Z"-suffixed or
## fraction-less timestamp). The settings read paths now route through the robust
## `timestampToUnix`, which normalizes the formats seen in the field and never
## raises on the hot path (returns 0 on failure). Expected epochs below are
## independent ground truth (computed with `date -u`), not recomputed via `parse`.

import unittest

import app_service/common/utils

suite "robust lastTokensUpdate timestamp parsing":
  test "empty string returns 0 without raising":
    check timestampToUnix("") == 0
    check timestampToUnix("   ") == 0

  test "the full field format (6-digit fraction + offset) parses":
    # 2024-01-15T10:30:00 UTC == 1705314600
    check timestampToUnix("2024-01-15T10:30:00.000000+00:00") == 1705314600

  test "a Z-suffixed timestamp with no fractional seconds parses (was TimeParseError)":
    check timestampToUnix("2024-01-15T10:30:00Z") == 1705314600

  test "a Z-suffixed timestamp with fractional seconds parses":
    check timestampToUnix("2023-06-01T00:00:00.123Z") == 1685577600

  test "a space-separated timestamp parses":
    check timestampToUnix("2023-06-01 00:00:00Z") == 1685577600

  test "garbage input returns 0 without raising":
    check timestampToUnix("not-a-timestamp") == 0
