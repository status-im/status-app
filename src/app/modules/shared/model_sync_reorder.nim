## Pure reorder planning for model_sync.
##
## model_sync's syncModel does not detect moves (its Phase-3 move detection is an
## unimplemented TODO), so after inserts/removes/updates reconcile the *set*, a
## surviving-row REORDER would leave the model out of order. This module computes
## the moves that reorder one id sequence into another.
##
## MOVE-UP-ONLY selection: walk the target index i; when the working sequence at i
## is not the expected id, find that id at some j > i and move it up to i. Because
## every move is upward (fromIdx > toIdx), the Qt destination index is exactly the
## target index and Qt's move-DOWN destination-index quirk can never occur. The
## produced moves are in application order: applying each (fromIdx -> toIdx) as
## "delete at fromIdx, insert at toIdx" on a working copy transforms `current`
## into `target`.
##
## Kept nimqml-free so the algorithm is unit-testable in isolation (no Qt).
## Precondition: `current` and `target` hold the same set of unique ids.

type
  ReorderMove* = tuple[fromIdx, toIdx: int]

proc planReorderMovesUp*(current: seq[string], target: seq[string]): seq[ReorderMove] =
  result = @[]
  var work = current
  var i = 0
  while i < target.len and i < work.len:
    if work[i] == target[i]:
      inc i
      continue
    # find target[i] somewhere after i
    var j = i + 1
    while j < work.len and work[j] != target[i]:
      inc j
    if j >= work.len:
      # Not present — sets don't match; skip defensively rather than loop forever.
      inc i
      continue
    result.add((fromIdx: j, toIdx: i))
    let moved = work[j]
    work.delete(j)
    work.insert(moved, i)
    inc i

proc applyReorderMoves*(s: seq[string], moves: seq[ReorderMove]): seq[string] =
  ## Reference application of the planned moves (mirrors what reconcileOrder does
  ## to the model's backing seq). Used by tests to assert the moves reproduce the
  ## target order.
  result = s
  for m in moves:
    let moved = result[m.fromIdx]
    result.delete(m.fromIdx)
    result.insert(moved, m.toIdx)
