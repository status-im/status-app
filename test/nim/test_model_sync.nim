## Tests for src/app/modules/shared/model_sync.nim
##
## Coverage focus:
##   - Pure inserts / pure removes / no-op
##   - In-place updates (role detection)
##   - B4 fix: LIS-based reorder detection produces correct deltas without
##     emitting spurious operations on pure mid-list insertion
##   - Bulk operations group consecutive runs
##
## These tests exercise syncModel directly (the diff algorithm) without
## involving Qt - the applySync side is integration-tested via the
## showcase model.

import unittest
import app/modules/shared/model_sync

type Item = object
  id: string
  payload: int

let itemId: ItemIdentifier[Item] = proc(it: Item): string = it.id
let itemRoles: RoleDetector[Item] = proc(o, n: Item): seq[int] =
  if o.payload != n.payload: @[1] else: @[]

suite "syncModel - trivial cases":
  test "both empty -> no changes":
    let r = syncModel[Item](@[], @[], itemId)
    check not r.hasChanges
    check r.toInsert.len == 0
    check r.toRemove.len == 0

  test "old empty -> all inserts":
    let r = syncModel[Item](@[], @[Item(id: "a"), Item(id: "b")], itemId)
    check r.hasChanges
    check r.toInsert.len == 2
    check r.toInsert[0].index == 0
    check r.toInsert[1].index == 1
    check r.toRemove.len == 0

  test "new empty -> all removes (descending)":
    let r = syncModel[Item](@[Item(id: "a"), Item(id: "b"), Item(id: "c")], @[], itemId)
    check r.hasChanges
    check r.toRemove.len == 3
    check r.toRemove[0].index == 2  # descending so applySync can delete in place
    check r.toRemove[1].index == 1
    check r.toRemove[2].index == 0

suite "syncModel - in-place updates":
  test "identical lists with no role detector -> no ops":
    let items = @[Item(id: "a", payload: 1), Item(id: "b", payload: 2)]
    let r = syncModel(items, items, itemId)
    check not r.hasChanges

  test "identical IDs, payload changed -> updates only":
    let old = @[Item(id: "a", payload: 1), Item(id: "b", payload: 2)]
    let nu = @[Item(id: "a", payload: 10), Item(id: "b", payload: 2)]
    let r = syncModel(old, nu, itemId, itemRoles)
    check r.hasChanges
    check r.toUpdate.len == 1
    check r.toUpdate[0].index == 0
    check r.toUpdate[0].roles == @[1]
    check r.toInsert.len == 0
    check r.toRemove.len == 0

  test "all rows updated":
    let old = @[Item(id: "a", payload: 1), Item(id: "b", payload: 2)]
    let nu = @[Item(id: "a", payload: 11), Item(id: "b", payload: 22)]
    let r = syncModel(old, nu, itemId, itemRoles)
    check r.toUpdate.len == 2

suite "syncModel - inserts at any position (B4 regression guard)":
  test "insert at head does NOT cause spurious removes":
    # The old "oldIdx == newIdx" cheap fix would have flagged every B/C as
    # reordered.  The LIS algorithm must keep them as stable updates.
    let old = @[Item(id: "a"), Item(id: "b"), Item(id: "c")]
    let nu = @[Item(id: "x"), Item(id: "a"), Item(id: "b"), Item(id: "c")]
    let r = syncModel(old, nu, itemId)
    check r.toInsert.len == 1
    check r.toInsert[0].index == 0
    check r.toRemove.len == 0

  test "insert in middle":
    let old = @[Item(id: "a"), Item(id: "b"), Item(id: "c")]
    let nu = @[Item(id: "a"), Item(id: "x"), Item(id: "b"), Item(id: "c")]
    let r = syncModel(old, nu, itemId)
    check r.toInsert.len == 1
    check r.toInsert[0].index == 1
    check r.toRemove.len == 0

  test "insert at tail":
    let old = @[Item(id: "a"), Item(id: "b")]
    let nu = @[Item(id: "a"), Item(id: "b"), Item(id: "c")]
    let r = syncModel(old, nu, itemId)
    check r.toInsert.len == 1
    check r.toInsert[0].index == 2
    check r.toRemove.len == 0

  test "remove from middle":
    let old = @[Item(id: "a"), Item(id: "b"), Item(id: "c")]
    let nu = @[Item(id: "a"), Item(id: "c")]
    let r = syncModel(old, nu, itemId)
    check r.toRemove.len == 1
    check r.toRemove[0].index == 1
    check r.toInsert.len == 0

suite "syncModel - reorders":
  test "swap last two -> minimal remove+insert":
    # old = [A, B, C], new = [A, C, B]
    # LIS over (oldIdx for newItems present in old) = [0, 2, 1] -> {0, 2}
    # so common pairs (0, 0) and (1, 2) are stable, (2, 1) is moved.
    # Expected: insert C at newIdx=1, remove old C at oldIdx=2.
    let old = @[Item(id: "a"), Item(id: "b"), Item(id: "c")]
    let nu = @[Item(id: "a"), Item(id: "c"), Item(id: "b")]
    let r = syncModel(old, nu, itemId)
    check r.hasChanges
    check r.toInsert.len == 1
    check r.toInsert[0].index == 1
    check r.toRemove.len == 1
    check r.toRemove[0].index == 2

  test "full reverse - LIS picks the longest stable subsequence":
    let old = @[Item(id: "a"), Item(id: "b"), Item(id: "c")]
    let nu = @[Item(id: "c"), Item(id: "b"), Item(id: "a")]
    let r = syncModel(old, nu, itemId)
    # LIS over [2, 1, 0] is length 1 -> only one stable element.
    # Two items must be moved (insert + remove).
    check r.toInsert.len == 2
    check r.toRemove.len == 2

suite "syncModel - mixed":
  test "insert + update + remove combined":
    # old = [A(1), B(2), C(3)], new = [A(10), X, C(3)]
    let old = @[Item(id: "a", payload: 1), Item(id: "b", payload: 2), Item(id: "c", payload: 3)]
    let nu = @[Item(id: "a", payload: 10), Item(id: "x", payload: 0), Item(id: "c", payload: 3)]
    let r = syncModel(old, nu, itemId, itemRoles)
    # A is stable but updated.
    check r.toUpdate.len == 1
    check r.toUpdate[0].index == 0
    # X is a true insert.
    check r.toInsert.len == 1
    check r.toInsert[0].index == 1
    # B is removed.
    check r.toRemove.len == 1
    check r.toRemove[0].index == 1

suite "groupConsecutiveRanges":
  type Range = tuple[first: int, last: int]

  test "empty input":
    check groupConsecutiveRanges(@[]).len == 0

  test "single element":
    check groupConsecutiveRanges(@[5]) == @[(first: 5, last: 5)]

  test "consecutive run":
    check groupConsecutiveRanges(@[0, 1, 2, 3]) == @[(first: 0, last: 3)]

  test "mixed":
    let expected: seq[Range] = @[(0, 2), (5, 6), (9, 9)]
    check groupConsecutiveRanges(@[0, 1, 2, 5, 6, 9]) == expected

  test "unsorted input is sorted":
    let expected: seq[Range] = @[(0, 2), (5, 6), (9, 9)]
    check groupConsecutiveRanges(@[5, 0, 1, 2, 9, 6]) == expected
