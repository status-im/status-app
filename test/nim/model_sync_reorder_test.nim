## Reorder-matrix coverage for syncModel's inline LIS reorder detection.
##
## syncModel emits reorders as remove+insert pairs (no Qt moveRows). These tests
## exercise the diff (no Qt model): for each (current, target) pair, apply the
## computed removes (descending) then inserts (ascending) to a working seq and
## check it reproduces the target order, with the LIS keeping a maximal stable
## subsequence (so a pure reorder never touches more rows than necessary).

import unittest, sequtils, algorithm
import app/modules/shared/model_sync

type Item = object
  id: string

let itemId: ItemIdentifier[Item] = proc(it: Item): string = it.id

proc applyDiff(current, target: seq[string]): seq[string] =
  ## Mirror of applySync's ordering on a plain seq.
  let old = current.mapIt(Item(id: it))
  let nu = target.mapIt(Item(id: it))
  var work = old
  let r = syncModel(old, nu, itemId)
  for rem in r.toRemove:            # descending from syncModel
    work.delete(rem.index)
  var ins = r.toInsert
  ins.sort(proc(a, b: InsertOp[Item]): int = cmp(a.index, b.index))
  for op in ins:
    work.insert(op.item, op.index)
  result = work.mapIt(it.id)

proc movedRows(current, target: seq[string]): int =
  ## Number of rows the reorder touches (insert count == remove count here).
  let old = current.mapIt(Item(id: it))
  let nu = target.mapIt(Item(id: it))
  syncModel(old, nu, itemId).toInsert.len

suite "syncModel reorder matrix (LIS remove+insert)":

  test "already in order -> no changes":
    let s = @["a", "b", "c", "d"]
    let r = syncModel(s.mapIt(Item(id: it)), s.mapIt(Item(id: it)), itemId)
    check not r.hasChanges

  test "empty -> no changes":
    let r = syncModel[Item](@[], @[], itemId)
    check not r.hasChanges

  test "adjacent swap":
    check applyDiff(@["a", "b", "c"], @["b", "a", "c"]) == @["b", "a", "c"]

  test "full reversal keeps a length-1 stable subsequence":
    check applyDiff(@["a", "b", "c", "d", "e"], @["e", "d", "c", "b", "a"]) ==
      @["e", "d", "c", "b", "a"]

  test "rotate left by one":
    check applyDiff(@["a", "b", "c", "d"], @["b", "c", "d", "a"]) ==
      @["b", "c", "d", "a"]

  test "rotate right by one":
    check applyDiff(@["a", "b", "c", "d"], @["d", "a", "b", "c"]) ==
      @["d", "a", "b", "c"]

  test "arbitrary shuffle":
    check applyDiff(@["a", "b", "c", "d", "e", "f"], @["c", "f", "a", "e", "b", "d"]) ==
      @["c", "f", "a", "e", "b", "d"]

  test "two elements swapped":
    check applyDiff(@["x", "y"], @["y", "x"]) == @["y", "x"]

  test "hash-order-change proxy (survivors reordered, same set)":
    check applyDiff(@["eth", "dai", "usdc", "snt"], @["snt", "eth", "usdc", "dai"]) ==
      @["snt", "eth", "usdc", "dai"]

  test "rotate-right touches only one row (LIS is minimal)":
    # [a,b,c,d] -> [d,a,b,c]: a,b,c stay stable, only d moves.
    check movedRows(@["a", "b", "c", "d"], @["d", "a", "b", "c"]) == 1
