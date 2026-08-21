## Sparse bookkeeping behind the dense message model: the model has one row per
## stored message of the chat (`rowCount == totalCount`), but only the rows that
## were actually fetched carry data — the rest are dummies the delegates render
## as skeleton.
##
## Everything here is pure Nim (no Qt, no status-go) so the part that is easy to
## get wrong can be tested on its own; the model shell only translates the
## `Change` stream into `beginInsertRows` / `dataChanged` and keeps the payloads.
##
## Coordinates. `rank` counts from the OLDEST message (rank 0), the way the
## status-go window API hands them out, because inserts at the newest end then
## never shift a rank that was already handed out. The model is newest-first, so
## `index = totalCount - 1 - rank`. Loaded rows live in `islands` (maximal
## contiguous runs, kept sorted oldest-first); a hole is simply the complement.
##
## The load-bearing rule: **row count only ever changes when the chat's message
## count changes**. Fetched pages, drifted ranks and eviction move loadedness
## around inside a fixed row count, so they are `dataChanged` and never
## insert/remove. Ranks are advisory — when a fresh page disagrees with a stored
## rank, the page wins and the affected island is re-anchored, which grows one
## hole and shrinks another.

import std/[algorithm, sets, tables]

const DEFAULT_LOADED_ROW_CAP* = 500

type
  LoadedRow* = object
    ## The only per-row data the bookkeeping needs: an identity and a cursor.
    ## `(clock, id)` is the same ordering the non-dense model sorts by.
    id*: string
    clock*: int64

  ChangeKind* = enum
    ckReset
    ckRowsInserted
    ckRowsRemoved
    ckRowsChanged            ## a row range gained, lost or replaced its payload
    ckNeighbourRolesChanged  ## only the prev/next-derived roles of a range changed

  Change* = object
    kind*: ChangeKind
    first*, last*: int       ## model-index space, inclusive; unused for ckReset
    droppedIds*: seq[string] ## payloads the shell may release

  Hole* = object
    firstIndex*, lastIndex*: int          ## model-index space, inclusive
    olderCursor*, newerCursor*: LoadedRow ## bounding loaded rows; empty id at a model edge

  Island = object
    startRank: int         ## rank of rows[0]
    rows: seq[LoadedRow]   ## oldest-first: rows[k] has rank startRank + k
    rankStale: bool        ## rank survived an ambiguous count change unverified
    reanchored: bool       ## a page already corrected this island's rank once
    trusted: bool          ## transient: carries a rank a fetch response just confirmed

  ChangeHandler* = proc(change: Change) {.closure.}

  DenseStore* = ref object
    total: int
    islands: seq[Island]
    ids: HashSet[string]
    cap: int
    windowFirst, windowLast, windowMargin: int
    # `beforeChange` fires with the store still holding the pre-change state so
    # the shell can call beginInsertRows/beginRemoveRows; `afterChange` fires
    # once the change is applied.
    beforeChange*, afterChange*: ChangeHandler

proc newDenseStore*(cap: int = DEFAULT_LOADED_ROW_CAP): DenseStore =
  DenseStore(total: 0, islands: @[], ids: initHashSet[string](), cap: cap,
             windowFirst: 0, windowLast: 0, windowMargin: 0)

# ---------------------------------------------------------------- primitives

proc endRank(isl: Island): int {.inline.} =
  isl.startRank + isl.rows.len - 1

proc isNewer*(lhs, rhs: LoadedRow): bool {.inline.} =
  lhs.clock > rhs.clock or (lhs.clock == rhs.clock and lhs.id > rhs.id)

proc totalCount*(self: DenseStore): int {.inline.} =
  self.total

proc rowCount*(self: DenseStore): int {.inline.} =
  self.total

proc rankToIndex*(self: DenseStore, rank: int): int {.inline.} =
  self.total - 1 - rank

proc indexToRank*(self: DenseStore, index: int): int {.inline.} =
  self.total - 1 - index

proc loadedCount*(self: DenseStore): int =
  for isl in self.islands:
    result += isl.rows.len

proc islandOfRank(self: DenseStore, rank: int): int =
  result = -1
  for i in 0 ..< self.islands.len:
    if rank < self.islands[i].startRank:
      return -1
    if rank <= self.islands[i].endRank:
      return i

proc rowAtRank*(self: DenseStore, rank: int): LoadedRow =
  let i = self.islandOfRank(rank)
  if i == -1:
    return LoadedRow()
  return self.islands[i].rows[rank - self.islands[i].startRank]

proc rowAt*(self: DenseStore, index: int): LoadedRow =
  if index < 0 or index >= self.total:
    return LoadedRow()
  self.rowAtRank(self.indexToRank(index))

proc isLoaded*(self: DenseStore, index: int): bool =
  if index < 0 or index >= self.total:
    return false
  self.islandOfRank(self.indexToRank(index)) != -1

proc contains*(self: DenseStore, id: string): bool {.inline.} =
  self.ids.contains(id)

proc olderNeighbourIndex*(self: DenseStore, index: int): int =
  ## Neighbour rule for the prev/next-derived roles. A real row can sit next to
  ## a dummy, and a dummy's content is simply unknown — guessing "same sender,
  ## same day" would silently swallow a header that belongs there. So an
  ## unloaded neighbour is reported exactly like a model edge: no neighbour
  ## (-1), which makes the row render its full header. When the dummy is later
  ## filled the affected row is re-emitted (ckNeighbourRolesChanged) and the
  ## grouping settles.
  let older = index + 1 # newest-first model: the older message is the next row
  if older >= self.total or not self.isLoaded(older): -1 else: older

proc newerNeighbourIndex*(self: DenseStore, index: int): int =
  let newer = index - 1
  if newer < 0 or not self.isLoaded(newer): -1 else: newer

proc rankOfId*(self: DenseStore, id: string): int =
  result = -1
  if id.len == 0 or not self.ids.contains(id):
    return
  for isl in self.islands:
    for k in 0 ..< isl.rows.len:
      if isl.rows[k].id == id:
        return isl.startRank + k

proc indexOfId*(self: DenseStore, id: string): int =
  let rank = self.rankOfId(id)
  if rank == -1: -1 else: self.rankToIndex(rank)

proc byStartRank(lhs, rhs: Island): int =
  cmp(lhs.startRank, rhs.startRank)

proc mergeIslands(self: DenseStore) =
  ## Islands are maximal runs: whatever became contiguous is one island again.
  if self.islands.len == 0:
    return
  self.islands.sort(byStartRank)
  var merged: seq[Island] = @[]
  for isl in self.islands:
    if isl.rows.len == 0:
      continue
    # only a seam whose cursors agree is a real run; merging across a
    # contradiction would hide it from the order check in `normalize`
    if merged.len > 0 and merged[^1].endRank + 1 == isl.startRank and
       isl.rows[0].isNewer(merged[^1].rows[^1]):
      merged[^1].rows.add(isl.rows)
      # a run is only as trustworthy as its least trustworthy part
      merged[^1].rankStale = merged[^1].rankStale or isl.rankStale
      merged[^1].reanchored = merged[^1].reanchored or isl.reanchored
      merged[^1].trusted = merged[^1].trusted or isl.trusted
    else:
      merged.add(isl)
  self.islands = merged

proc emitBefore(self: DenseStore, change: Change) =
  if self.beforeChange != nil:
    self.beforeChange(change)

proc emitAfter(self: DenseStore, change: Change) =
  if self.afterChange != nil:
    self.afterChange(change)

proc emitNeighbourRoles(self: DenseStore, indices: openArray[int]) =
  ## Neighbour-derived roles are read off the adjacent row, so a row whose
  ## neighbour just appeared, vanished or changed has to re-read them.
  var wanted: seq[int] = @[]
  for index in indices:
    if index >= 0 and index < self.total and self.isLoaded(index) and index notin wanted:
      wanted.add(index)
  if wanted.len == 0:
    return
  wanted.sort()
  var runStart = wanted[0]
  var prev = wanted[0]
  for i in 1 ..< wanted.len:
    if wanted[i] == prev + 1:
      prev = wanted[i]
      continue
    self.emitAfter(Change(kind: ckNeighbourRolesChanged, first: runStart, last: prev))
    runStart = wanted[i]
    prev = wanted[i]
  self.emitAfter(Change(kind: ckNeighbourRolesChanged, first: runStart, last: prev))

proc rankMap(self: DenseStore): Table[int, string] =
  result = initTable[int, string]()
  for isl in self.islands:
    for k in 0 ..< isl.rows.len:
      result[isl.startRank + k] = isl.rows[k].id

proc emitDiff(self: DenseStore, before: Table[int, string]) =
  ## Emits the `dataChanged` runs implied by the difference between a snapshot
  ## and the current state. Only valid while `total` has not moved since the
  ## snapshot was taken — structural changes announce themselves separately.
  let after = self.rankMap()
  var changedRanks: seq[int] = @[]
  var dropped: seq[string] = @[]
  for rank, id in before:
    if after.getOrDefault(rank, "") != id:
      changedRanks.add(rank)
    if not self.ids.contains(id):
      dropped.add(id)
  for rank in after.keys:
    if not before.hasKey(rank):
      changedRanks.add(rank)
  if changedRanks.len == 0:
    return

  var indices: seq[int] = @[]
  for rank in changedRanks:
    indices.add(self.rankToIndex(rank))
  indices.sort()

  var ranges: seq[(int, int)] = @[]
  var runStart = indices[0]
  var prev = indices[0]
  for i in 1 ..< indices.len:
    if indices[i] == prev + 1:
      prev = indices[i]
      continue
    ranges.add((runStart, prev))
    runStart = indices[i]
    prev = indices[i]
  ranges.add((runStart, prev))

  for i in 0 ..< ranges.len:
    let (first, last) = ranges[i]
    var change = Change(kind: ckRowsChanged, first: first, last: last)
    if i == 0:
      change.droppedIds = dropped
    self.emitAfter(change)

  var neighbours: seq[int] = @[]
  for (first, last) in ranges:
    for candidate in [first - 1, last + 1]:
      var inChangedRange = false
      for (rangeFirst, rangeLast) in ranges:
        if candidate >= rangeFirst and candidate <= rangeLast:
          inChangedRange = true
          break
      if not inChangedRange:
        neighbours.add(candidate)
  self.emitNeighbourRoles(neighbours)

proc splitAt(self: DenseStore, pivotRank: int) =
  var split: seq[Island] = @[]
  for isl in self.islands:
    if isl.startRank < pivotRank and pivotRank <= isl.endRank:
      let offset = pivotRank - isl.startRank
      split.add(Island(startRank: isl.startRank, rows: isl.rows[0 ..< offset],
                       rankStale: isl.rankStale, reanchored: isl.reanchored, trusted: isl.trusted))
      split.add(Island(startRank: pivotRank, rows: isl.rows[offset .. ^1],
                       rankStale: isl.rankStale, reanchored: isl.reanchored, trusted: isl.trusted))
    else:
      split.add(isl)
  self.islands = split

proc shiftRanksFrom(self: DenseStore, pivotRank, delta: int) =
  ## Every loaded row at or above `pivotRank` moves by `delta`. Used when the
  ## chat gained or lost a message older than those rows.
  if delta == 0:
    return
  self.splitAt(pivotRank)
  for isl in self.islands.mitems:
    if isl.startRank >= pivotRank:
      isl.startRank += delta

proc clearBand(self: DenseStore, loRank, hiRank: int): seq[string] =
  ## Turns every loaded row in the rank band back into a dummy.
  if hiRank < loRank:
    return
  var kept: seq[Island] = @[]
  for isl in self.islands:
    if isl.endRank < loRank or isl.startRank > hiRank:
      kept.add(isl)
      continue
    if isl.startRank < loRank:
      kept.add(Island(startRank: isl.startRank, rows: isl.rows[0 ..< (loRank - isl.startRank)],
                      rankStale: isl.rankStale, reanchored: isl.reanchored, trusted: isl.trusted))
    if isl.endRank > hiRank:
      let offset = hiRank - isl.startRank + 1
      kept.add(Island(startRank: hiRank + 1, rows: isl.rows[offset .. ^1],
                      rankStale: isl.rankStale, reanchored: isl.reanchored, trusted: isl.trusted))
    for k in (max(loRank, isl.startRank) - isl.startRank) .. (min(hiRank, isl.endRank) - isl.startRank):
      result.add(isl.rows[k].id)
      self.ids.excl(isl.rows[k].id)
  self.islands = kept
  self.islands.sort(byStartRank)

proc placeRun(self: DenseStore, startRank: int, rows: seq[LoadedRow], trusted = false) =
  ## Places a contiguous run of loaded rows over a band that holds no loaded
  ## rows any more (callers clear it first).
  if rows.len == 0:
    return
  for row in rows:
    self.ids.incl(row.id)
  # deliberately not merged here: applyPage has to settle overlaps and cursor
  # order against the neighbours before contiguous runs become one island
  self.islands.add(Island(startRank: startRank, rows: rows, rankStale: false, trusted: trusted))
  self.islands.sort(byStartRank)

# ------------------------------------------------------------ structural ops

proc insertRowsStructural(self: DenseStore, index: int, rows: seq[LoadedRow], count: int) =
  ## Inserts `count` rows at model index `index`. `rows` (oldest-first, either
  ## empty for dummies or exactly `count` long) are the payload-carrying rows.
  ## Rows older than the insertion point keep their rank; newer ones gain
  ## `count`, which is what keeps their model index stable.
  if count <= 0:
    return
  let pivotRank = self.total - index
  self.emitBefore(Change(kind: ckRowsInserted, first: index, last: index + count - 1))
  self.shiftRanksFrom(pivotRank, count)
  self.total += count
  if rows.len > 0:
    self.placeRun(pivotRank, rows)
  self.mergeIslands()
  self.emitAfter(Change(kind: ckRowsInserted, first: index, last: index + count - 1))
  self.emitNeighbourRoles([index - 1, index + count])

proc removeRowsStructural(self: DenseStore, index, count: int) =
  if count <= 0 or index < 0 or index >= self.total:
    return
  let clamped = min(count, self.total - index)
  let hiRank = self.total - 1 - index
  let loRank = hiRank - clamped + 1
  self.emitBefore(Change(kind: ckRowsRemoved, first: index, last: index + clamped - 1))
  let dropped = self.clearBand(loRank, hiRank)
  self.shiftRanksFrom(hiRank + 1, -clamped)
  self.total -= clamped
  self.mergeIslands()
  self.emitAfter(Change(kind: ckRowsRemoved, first: index, last: index + clamped - 1,
                        droppedIds: dropped))
  self.emitNeighbourRoles([index - 1, index])

# ------------------------------------------------------------------- eviction

proc protectedRange(self: DenseStore): (int, int) =
  if self.total == 0:
    return (0, -1)
  let first = max(0, min(self.windowFirst, self.windowLast) - self.windowMargin)
  let last = min(self.total - 1, max(self.windowFirst, self.windowLast) + self.windowMargin)
  (first, last)

proc setWindow*(self: DenseStore, firstIndex, lastIndex: int, margin = 0) =
  self.windowFirst = firstIndex
  self.windowLast = lastIndex
  self.windowMargin = max(0, margin)

proc setLoadedRowCap*(self: DenseStore, cap: int) =
  self.cap = cap

proc loadedRowCap*(self: DenseStore): int {.inline.} =
  self.cap

proc evictRows(self: DenseStore) =
  ## Drops loaded rows back to dummies, farthest from the window first, until
  ## the cap is met. The farthest loaded row is always at an island end, so
  ## eviction only ever trims islands — it never splits one, and never touches
  ## a row inside the window or its margins.
  if self.cap <= 0:
    return
  var remaining = self.loadedCount
  if remaining <= self.cap:
    return
  let (protFirst, protLast) = self.protectedRange()

  proc distance(index: int): int =
    if index < protFirst: protFirst - index
    elif index > protLast: index - protLast
    else: 0

  while remaining > self.cap and self.islands.len > 0:
    # lowest model index == highest rank == newest end of the newest island
    let newestIdx = self.rankToIndex(self.islands[^1].endRank)
    let oldestIdx = self.rankToIndex(self.islands[0].startRank)
    let newestDistance = distance(newestIdx)
    let oldestDistance = distance(oldestIdx)
    if newestDistance == 0 and oldestDistance == 0:
      break # everything still loaded is inside the window or its margins
    if oldestDistance >= newestDistance:
      self.ids.excl(self.islands[0].rows[0].id)
      self.islands[0].rows.delete(0)
      self.islands[0].startRank += 1
      if self.islands[0].rows.len == 0:
        self.islands.delete(0)
    else:
      self.ids.excl(self.islands[^1].rows[^1].id)
      self.islands[^1].rows.setLen(self.islands[^1].rows.len - 1)
      if self.islands[^1].rows.len == 0:
        self.islands.setLen(self.islands.len - 1)
    remaining -= 1

proc evictIfNeeded*(self: DenseStore) =
  let before = self.rankMap()
  self.evictRows()
  self.emitDiff(before)

# -------------------------------------------------------------------- public

proc reset*(self: DenseStore, totalCount: int) =
  ## Chat switch: everything loaded is gone, the row count becomes the new
  ## chat's message count and the whole model is dummies.
  var dropped: seq[string] = @[]
  for id in self.ids:
    dropped.add(id)
  self.emitBefore(Change(kind: ckReset))
  self.islands = @[]
  self.ids.clear()
  self.total = max(0, totalCount)
  self.windowFirst = 0
  self.windowLast = 0
  self.emitAfter(Change(kind: ckReset, droppedIds: dropped))

proc holes*(self: DenseStore): seq[Hole] =
  ## Maximal runs of dummies, newest-first, each bounded by the loaded rows on
  ## either side (an empty bounding row means the model edge).
  if self.total == 0:
    return
  var bounds: seq[(int, int)] = @[] # rank bands of dummies, oldest-first
  var cursor = 0
  for isl in self.islands:
    if isl.startRank > cursor:
      bounds.add((cursor, isl.startRank - 1))
    cursor = isl.endRank + 1
  if cursor <= self.total - 1:
    bounds.add((cursor, self.total - 1))

  for i in countdown(bounds.len - 1, 0):
    let (loRank, hiRank) = bounds[i]
    result.add(Hole(
      firstIndex: self.rankToIndex(hiRank),
      lastIndex: self.rankToIndex(loRank),
      olderCursor: (if loRank > 0: self.rowAtRank(loRank - 1) else: LoadedRow()),
      newerCursor: (if hiRank < self.total - 1: self.rowAtRank(hiRank + 1) else: LoadedRow()),
    ))

proc markRanksStale(self: DenseStore) =
  for isl in self.islands.mitems:
    isl.rankStale = true

proc hasStaleRanks*(self: DenseStore): bool =
  for isl in self.islands:
    if isl.rankStale:
      return true

proc setTotalCount*(self: DenseStore, totalCount: int) =
  ## The count-only signal: the chat's message count moved but the batch did not
  ## say where. Growth is assumed to be at the newest end (where messages
  ## normally arrive, and the only end that leaves handed-out ranks valid);
  ## shrinkage eats dummies nearest the newest end. Either way every rank is
  ## marked stale so the next fetch re-anchors instead of trusting it.
  if totalCount < 0 or totalCount == self.total:
    return
  if totalCount > self.total:
    self.insertRowsStructural(0, @[], totalCount - self.total)
    self.markRanksStale()
    return

  var toRemove = self.total - totalCount
  while toRemove > 0:
    var removedHere = false
    for hole in self.holes():
      let take = min(toRemove, hole.lastIndex - hole.firstIndex + 1)
      self.removeRowsStructural(hole.firstIndex, take)
      toRemove -= take
      removedHere = true
      break
    if not removedHere:
      # no dummies left to absorb the shrink: give up the loaded rows farthest
      # from the window rather than let rowCount disagree with the chat
      let (_, protLast) = self.protectedRange()
      let oldestIdx = self.rankToIndex(self.islands[0].startRank)
      let index = if oldestIdx > protLast: oldestIdx else: self.total - 1
      self.removeRowsStructural(index, 1)
      toRemove -= 1
    if self.total == 0:
      break
  self.markRanksStale()

proc appendLive*(self: DenseStore, rows: seq[LoadedRow], totalCount = -1) =
  ## Live messages: they land at the newest end, so their rank is the old total
  ## and no rank already handed out moves.
  var fresh: seq[LoadedRow] = @[]
  for i in countdown(rows.len - 1, 0): # incoming is newest-first, islands are oldest-first
    if not self.ids.contains(rows[i].id):
      fresh.add(rows[i])
  if fresh.len > 0:
    self.insertRowsStructural(0, fresh, fresh.len)
  self.setTotalCount(totalCount)
  self.evictIfNeeded()

proc insertBackfilled*(self: DenseStore, row: LoadedRow, totalCount = -1) =
  ## A message that belongs somewhere other than the newest end. Its position is
  ## found by cursor: inside an island it lands between its two neighbours;
  ## inside a hole it lands at the hole's newest end, since the exact slot in a
  ## run of dummies is both unknown and indistinguishable.
  if self.ids.contains(row.id):
    return
  # the row goes directly above the newest loaded row that is older than it;
  # older than every loaded row means the oldest end
  var index = self.total
  block locate:
    for i in countdown(self.islands.len - 1, 0):
      let isl = self.islands[i]
      for k in countdown(isl.rows.len - 1, 0):
        if row.isNewer(isl.rows[k]):
          index = self.rankToIndex(isl.startRank + k)
          break locate

  self.insertRowsStructural(index, @[row], 1)
  self.setTotalCount(totalCount)
  self.evictIfNeeded()

proc removeMessage*(self: DenseStore, id: string, clock: int64, totalCount = -1) =
  ## Deletion by clock: a loaded row is removed outright; a message that falls
  ## inside a hole shrinks that hole by one dummy — any slot in the run is as
  ## good as any other. When neither applies only the count is believed.
  let index = self.indexOfId(id)
  if index != -1:
    self.removeRowsStructural(index, 1)
    self.setTotalCount(totalCount)
    return

  let target = LoadedRow(id: id, clock: clock)
  for hole in self.holes():
    let olderOk = hole.olderCursor.id.len == 0 or target.isNewer(hole.olderCursor)
    let newerOk = hole.newerCursor.id.len == 0 or hole.newerCursor.isNewer(target)
    if olderOk and newerOk:
      self.removeRowsStructural(hole.firstIndex, 1)
      self.setTotalCount(totalCount)
      return

  self.setTotalCount(totalCount)
  self.markRanksStale()

proc trustScore(isl: Island): int =
  if isl.trusted: 2
  elif not isl.rankStale: 1
  else: 0

proc dropIslandRows(self: DenseStore, islandIdx, loRank, hiRank: int) =
  var isl = self.islands[islandIdx]
  let lo = max(loRank, isl.startRank)
  let hi = min(hiRank, isl.endRank)
  if hi < lo:
    return
  for k in (lo - isl.startRank) .. (hi - isl.startRank):
    self.ids.excl(isl.rows[k].id)
  var replacement: seq[Island] = @[]
  if isl.startRank < lo:
    replacement.add(Island(startRank: isl.startRank, rows: isl.rows[0 ..< (lo - isl.startRank)],
                           rankStale: isl.rankStale, reanchored: isl.reanchored, trusted: isl.trusted))
  if isl.endRank > hi:
    replacement.add(Island(startRank: hi + 1, rows: isl.rows[(hi - isl.startRank + 1) .. ^1],
                           rankStale: isl.rankStale, reanchored: isl.reanchored, trusted: isl.trusted))
  self.islands.delete(islandIdx)
  for j in countdown(replacement.len - 1, 0):
    self.islands.insert(replacement[j], islandIdx)

proc dropIds(self: DenseStore, ids: Table[string, int]) =
  ## A fetch response is the authority on where its ids live, so any other copy
  ## of them in the model is stale by construction. Dropping them before the
  ## page is placed is what keeps a re-anchored island from keeping a second
  ## copy of a row the page also carries.
  var kept: seq[Island] = @[]
  for isl in self.islands:
    var runStart = 0
    for k in 0 ..< isl.rows.len:
      if not ids.hasKey(isl.rows[k].id):
        continue
      self.ids.excl(isl.rows[k].id)
      if k > runStart:
        kept.add(Island(startRank: isl.startRank + runStart, rows: isl.rows[runStart ..< k],
                        rankStale: isl.rankStale, reanchored: isl.reanchored, trusted: isl.trusted))
      runStart = k + 1
    if runStart < isl.rows.len:
      kept.add(Island(startRank: isl.startRank + runStart, rows: isl.rows[runStart .. ^1],
                      rankStale: isl.rankStale, reanchored: isl.reanchored, trusted: isl.trusted))
  self.islands = kept
  self.islands.sort(byStartRank)

proc dropIsland(self: DenseStore, islandIdx: int) =
  for row in self.islands[islandIdx].rows:
    self.ids.excl(row.id)
  self.islands.delete(islandIdx)

proc normalize(self: DenseStore) =
  ## Restores the island invariants after re-anchoring: inside the model bounds,
  ## disjoint, ordered by cursor, maximal. Conflicts are decided by trust — the
  ## island a fresh page just confirmed beats one carrying an unverified rank.
  self.islands.sort(byStartRank)

  var i = 0
  while i < self.islands.len:
    if self.islands[i].rows.len == 0:
      self.islands.delete(i)
      continue
    if self.islands[i].endRank < 0 or self.islands[i].startRank >= self.total:
      self.dropIsland(i)
      continue
    if self.islands[i].startRank < 0:
      self.dropIslandRows(i, self.islands[i].startRank, -1)
      continue
    if self.islands[i].endRank >= self.total:
      self.dropIslandRows(i, self.total, self.islands[i].endRank)
      continue
    i += 1

  i = 1
  while i < self.islands.len:
    let prev = self.islands[i - 1]
    let cur = self.islands[i]
    if cur.startRank <= prev.endRank:
      if prev.trustScore >= cur.trustScore:
        self.dropIslandRows(i, prev.startRank, prev.endRank)
      else:
        self.dropIslandRows(i - 1, cur.startRank, cur.endRank)
      self.islands.sort(byStartRank)
      i = max(1, i - 1)
      continue
    if not cur.rows[0].isNewer(prev.rows[^1]):
      # cursors contradict the ranks: the less trusted side is the wrong one
      if prev.trustScore >= cur.trustScore:
        self.dropIsland(i)
      else:
        self.dropIsland(i - 1)
      self.islands.sort(byStartRank)
      i = max(1, i - 1)
      continue
    i += 1

  self.mergeIslands()
  for isl in self.islands.mitems:
    isl.trusted = false

proc applyPage*(self: DenseStore, rows: seq[LoadedRow], firstRank: int, totalCount = -1) =
  ## Applies a fetched page. `rows` is newest-first as status-go returns it and
  ## `rows[i]` has rank `firstRank - i`. When the page exactly covers a hole
  ## this is a pure fill-in-place; when a stored rank disagrees with the page,
  ## the island holding the shared ids is re-anchored, which grows one hole and
  ## shrinks another without moving a single row count.
  self.setTotalCount(totalCount)
  if rows.len == 0:
    return
  let pageEnd = firstRank
  let pageStart = firstRank - rows.len + 1
  if pageStart < 0 or pageEnd >= self.total:
    self.markRanksStale()
    return

  var pageRows: seq[LoadedRow] = @[] # oldest-first
  for i in countdown(rows.len - 1, 0):
    pageRows.add(rows[i])

  var pageRankById = initTable[string, int]()
  for k in 0 ..< pageRows.len:
    pageRankById[pageRows[k].id] = pageStart + k

  let before = self.rankMap()

  # re-anchor: the page's ranks are fresh, so an island sharing an id with it
  # moves to agree
  var contradicted: seq[int] = @[]
  for islandIdx in 0 ..< self.islands.len:
    var delta = 0
    var shared = false
    for k in 0 ..< self.islands[islandIdx].rows.len:
      let pageRank = pageRankById.getOrDefault(self.islands[islandIdx].rows[k].id, -1)
      if pageRank == -1:
        continue
      delta = pageRank - (self.islands[islandIdx].startRank + k)
      shared = true
      break
    if not shared:
      continue
    if delta == 0:
      self.islands[islandIdx].rankStale = false
      self.islands[islandIdx].reanchored = false
    elif self.islands[islandIdx].reanchored:
      # A slide assumes the island stayed contiguous while its anchor moved. A
      # second page disagreeing with an island already slid once says that
      # assumption is wrong — the run spans a divergence and no shift can make
      # it true — so the island goes back to dummies and is refetched. Without
      # this the same island slides back and forth between two wrong positions
      # forever.
      contradicted.add(islandIdx)
    else:
      self.islands[islandIdx].startRank += delta
      # only the shared row's rank is confirmed; the rest of the island rides
      # on the assumption that it stayed contiguous
      self.islands[islandIdx].rankStale = true
      self.islands[islandIdx].reanchored = true
  for i in countdown(contradicted.high, 0):
    self.dropIsland(contradicted[i])

  self.dropIds(pageRankById)
  discard self.clearBand(pageStart, pageEnd)
  self.placeRun(pageStart, pageRows, trusted = true)
  self.normalize()
  self.evictRows()
  self.emitDiff(before)

proc `$`*(self: DenseStore): string =
  result = "DenseStore(total: " & $self.total & ", islands: ["
  for i, isl in self.islands:
    if i > 0:
      result &= ", "
    result &= $isl.startRank & ".." & $isl.endRank
    if isl.rankStale:
      result &= "!"
  result &= "])"
