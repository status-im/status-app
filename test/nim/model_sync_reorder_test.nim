import unittest

import app/modules/shared/model_sync_reorder

proc check_reorder(current, target: seq[string]) =
  ## Every case must: (1) reproduce the target order when the moves are applied,
  ## and (2) use MOVE-UP only (fromIdx > toIdx) so Qt's move-down quirk can't occur.
  let moves = planReorderMovesUp(current, target)
  check applyReorderMoves(current, moves) == target
  for m in moves:
    check m.fromIdx > m.toIdx

suite "model_sync_reorder - move-up-only planning (reorder matrix)":

  test "already in order -> no moves":
    let s = @["a", "b", "c", "d"]
    check planReorderMovesUp(s, s).len == 0

  test "empty -> no moves":
    check planReorderMovesUp(@[], @[]).len == 0

  test "adjacent swap":
    check_reorder(@["a", "b", "c"], @["b", "a", "c"])

  test "full reversal (worst case for move-up selection)":
    check_reorder(@["a", "b", "c", "d", "e"], @["e", "d", "c", "b", "a"])

  test "rotate left by one":
    check_reorder(@["a", "b", "c", "d"], @["b", "c", "d", "a"])

  test "rotate right by one":
    check_reorder(@["a", "b", "c", "d"], @["d", "a", "b", "c"])

  test "move first to last":
    check_reorder(@["a", "b", "c", "d"], @["b", "c", "d", "a"])

  test "move last to first":
    check_reorder(@["a", "b", "c", "d"], @["d", "a", "b", "c"])

  test "arbitrary shuffle":
    check_reorder(@["a", "b", "c", "d", "e", "f"], @["c", "f", "a", "e", "b", "d"])

  test "two elements swapped":
    check_reorder(@["x", "y"], @["y", "x"])

  test "hash-order-change proxy (survivors reordered, same set)":
    # Mimics token groups: same group keys, order shifted by a rehash.
    check_reorder(@["eth", "dai", "usdc", "snt"], @["snt", "eth", "usdc", "dai"])
