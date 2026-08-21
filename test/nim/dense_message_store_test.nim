## Unit tests for the dense message model's bookkeeping. Pure Nim — no Qt, no
## status-go: the store is the seam, a recorded `Change` log stands in for the
## model signals and a tiny in-test "server" stands in for the window RPC.

import std/[algorithm, random, sets, strutils, tables]
import unittest

import app/modules/shared_models/dense_message_store

# ------------------------------------------------------------------ harness

type Recorder = ref object
  before: seq[Change]
  after: seq[Change]

proc attach(store: DenseStore): Recorder =
  let rec = Recorder()
  store.beforeChange = proc(change: Change) = rec.before.add(change)
  store.afterChange = proc(change: Change) = rec.after.add(change)
  return rec

proc clear(rec: Recorder) =
  rec.before = @[]
  rec.after = @[]

proc kinds(rec: Recorder): seq[ChangeKind] =
  for change in rec.after:
    result.add(change.kind)

proc ranges(rec: Recorder, kind: ChangeKind): seq[(int, int)] =
  for change in rec.after:
    if change.kind == kind:
      result.add((change.first, change.last))

proc dropped(rec: Recorder): seq[string] =
  for change in rec.after:
    result.add(change.droppedIds)

proc row(id: string, clock: int64): LoadedRow =
  LoadedRow(id: id, clock: clock)

## A page as status-go returns it: newest-first, `rows[i]` has rank `firstRank - i`.
proc pageOfRanks(firstRank, lastRank: int): seq[LoadedRow] =
  for rank in countdown(firstRank, lastRank):
    result.add(row("m" & $rank, rank.int64))

proc loadedIds(store: DenseStore): seq[string] =
  for index in 0 ..< store.rowCount:
    if store.isLoaded(index):
      result.add(store.rowAt(index).id)

proc checkInvariants(store: DenseStore, expectedTotal: int) =
  check store.rowCount == expectedTotal
  check store.totalCount == expectedTotal

  var seen = initHashSet[string]()
  var loaded = 0
  for index in 0 ..< store.rowCount:
    if not store.isLoaded(index):
      check store.rowAt(index).id.len == 0
      continue
    loaded += 1
    let id = store.rowAt(index).id
    check id.len > 0
    check not seen.contains(id) # no duplicate ids
    seen.incl(id)
  check loaded == store.loadedCount

  let holes = store.holes()
  var dummies = 0
  for i in 0 ..< holes.len:
    let hole = holes[i]
    check hole.firstIndex <= hole.lastIndex
    dummies += hole.lastIndex - hole.firstIndex + 1
    for index in hole.firstIndex .. hole.lastIndex:
      check not store.isLoaded(index)
    # bounded by loaded rows with known cursors, or by a model edge
    if hole.firstIndex == 0:
      check hole.newerCursor.id.len == 0
    else:
      check store.isLoaded(hole.firstIndex - 1)
      check hole.newerCursor.id == store.rowAt(hole.firstIndex - 1).id
    if hole.lastIndex == store.rowCount - 1:
      check hole.olderCursor.id.len == 0
    else:
      check store.isLoaded(hole.lastIndex + 1)
      check hole.olderCursor.id == store.rowAt(hole.lastIndex + 1).id
    if i > 0:
      # holes are maximal: two of them are never adjacent
      check holes[i - 1].lastIndex + 1 < hole.firstIndex
  check dummies + loaded == expectedTotal

  # loaded rows are ordered newest-first by cursor
  var previous = LoadedRow()
  var havePrevious = false
  for index in 0 ..< store.rowCount:
    if not store.isLoaded(index):
      continue
    let current = store.rowAt(index)
    if havePrevious:
      check previous.isNewer(current)
    previous = current
    havePrevious = true

# ------------------------------------------------------------------- suites

suite "rank and index conversion":

  test "rank 0 is the oldest row, the last index":
    let store = newDenseStore()
    store.reset(10)
    check store.rowCount == 10
    check store.rankToIndex(0) == 9
    check store.rankToIndex(9) == 0
    check store.indexToRank(0) == 9
    check store.indexToRank(9) == 0
    for index in 0 ..< 10:
      check store.rankToIndex(store.indexToRank(index)) == index

  test "conversion follows the count, so the newest row keeps index 0":
    let store = newDenseStore()
    store.reset(10)
    check store.rankToIndex(9) == 0
    store.setTotalCount(13)
    check store.rankToIndex(9) == 3 # three newer rows appeared above it
    check store.rankToIndex(12) == 0

suite "fill in place":

  setup:
    let store = newDenseStore()
    store.reset(10)
    let rec = attach(store)

  test "a page covering a hole exactly is dataChanged only":
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)
    checkInvariants(store, 10)
    check ckRowsInserted notin rec.kinds()
    check ckRowsRemoved notin rec.kinds()
    check rec.ranges(ckRowsChanged) == @[(0, 4)]
    check store.loadedIds() == @["m9", "m8", "m7", "m6", "m5"]
    check store.holes().len == 1
    check store.holes()[0].firstIndex == 5
    check store.holes()[0].lastIndex == 9

  test "the second page closes the model without moving a row":
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)
    rec.clear()
    store.applyPage(pageOfRanks(4, 0), firstRank = 4, totalCount = 10)
    checkInvariants(store, 10)
    check ckRowsInserted notin rec.kinds()
    check ckRowsRemoved notin rec.kinds()
    check rec.ranges(ckRowsChanged) == @[(5, 9)]
    check store.holes().len == 0
    check store.loadedCount == 10

  test "the row bordering the filled range re-reads its neighbour roles":
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)
    rec.clear()
    store.applyPage(pageOfRanks(4, 0), firstRank = 4, totalCount = 10)
    check rec.ranges(ckNeighbourRolesChanged) == @[(4, 4)]

  test "a page landing in the middle leaves a hole on each side":
    store.applyPage(pageOfRanks(6, 4), firstRank = 6, totalCount = 10)
    checkInvariants(store, 10)
    let holes = store.holes()
    check holes.len == 2
    check (holes[0].firstIndex, holes[0].lastIndex) == (0, 2)
    check (holes[1].firstIndex, holes[1].lastIndex) == (6, 9)
    check holes[0].olderCursor.id == "m6"
    check holes[0].newerCursor.id.len == 0
    check holes[1].newerCursor.id == "m4"
    check holes[1].olderCursor.id.len == 0

suite "holes grow and shrink by cursor":

  test "a page re-anchors an island whose rank drifted":
    let store = newDenseStore()
    store.reset(100)
    store.applyPage(pageOfRanks(9, 0), firstRank = 9, totalCount = 100)
    # the same ten messages m50..m59, but recorded two ranks too high
    var drifted: seq[LoadedRow] = @[]
    for rank in countdown(59, 50):
      drifted.add(row("m" & $rank, rank.int64))
    store.applyPage(drifted, firstRank = 61, totalCount = 100)
    checkInvariants(store, 100)
    check store.indexOfId("m50") == store.rankToIndex(52)

    let rec = attach(store)
    store.applyPage(pageOfRanks(52, 45), firstRank = 52, totalCount = 100)
    checkInvariants(store, 100)
    check ckRowsInserted notin rec.kinds()
    check ckRowsRemoved notin rec.kinds()

    # the drifted island slid down by two and merged with the page
    for rank in 45 .. 59:
      check store.rowAt(store.rankToIndex(rank)).id == "m" & $rank
    let holes = store.holes()
    check holes.len == 2
    check (holes[0].firstIndex, holes[0].lastIndex) == (0, store.rankToIndex(60))
    check (holes[1].firstIndex, holes[1].lastIndex) == (store.rankToIndex(44), store.rankToIndex(10))

  test "an island contradicting the page's cursor order is dropped":
    let store = newDenseStore()
    store.reset(50)
    # m10..m14 recorded at ranks 20..24: believable until the true content of
    # ranks 15..19 arrives and turns out to be newer than they are
    var bogus: seq[LoadedRow] = @[]
    for rank in countdown(14, 10):
      bogus.add(row("m" & $rank, rank.int64))
    store.applyPage(bogus, firstRank = 24, totalCount = 50)
    check store.loadedCount == 5

    store.applyPage(pageOfRanks(19, 15), firstRank = 19, totalCount = 50)
    checkInvariants(store, 50)
    for rank in 15 .. 19:
      check store.rowAt(store.rankToIndex(rank)).id == "m" & $rank
    check store.loadedCount == 5
    check not store.contains("m14")

suite "live messages":

  setup:
    let store = newDenseStore()
    store.reset(10)
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)
    let rec = attach(store)

  test "a live message is inserted at the newest end":
    store.appendLive(@[row("m10", 10)], totalCount = 11)
    checkInvariants(store, 11)
    check rec.ranges(ckRowsInserted) == @[(0, 0)]
    check store.rowAt(0).id == "m10"
    check store.rowAt(1).id == "m9"
    check store.indexOfId("m5") == 5 # the older rows kept their index
    check rec.ranges(ckNeighbourRolesChanged) == @[(1, 1)]

  test "a live batch keeps the newest-first order":
    store.appendLive(@[row("m12", 12), row("m11", 11)], totalCount = 12)
    checkInvariants(store, 12)
    check rec.ranges(ckRowsInserted) == @[(0, 1)]
    check store.rowAt(0).id == "m12"
    check store.rowAt(1).id == "m11"
    check store.rowAt(2).id == "m9"

  test "a live message already in the model is not duplicated":
    store.appendLive(@[row("m9", 9)], totalCount = 10)
    checkInvariants(store, 10)
    check ckRowsInserted notin rec.kinds()
    check store.loadedCount == 5

  test "a backfilled message lands between its cursor neighbours":
    store.insertBackfilled(row("m7b", 7), totalCount = 11)
    checkInvariants(store, 11)
    check rec.ranges(ckRowsInserted) == @[(2, 2)]
    check store.loadedIds() == @["m9", "m8", "m7b", "m7", "m6", "m5"]

  test "a backfilled message older than everything loaded lands in the hole":
    store.insertBackfilled(row("m2b", 2), totalCount = 11)
    checkInvariants(store, 11)
    check store.rowAt(10).id == "m2b" # oldest end, inside the hole
    check store.indexOfId("m9") == 0

suite "deletions":

  setup:
    let store = newDenseStore()
    store.reset(10)
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)
    let rec = attach(store)

  test "deleting a loaded row removes it and its payload":
    store.removeMessage("m7", clock = 7, totalCount = 9)
    checkInvariants(store, 9)
    check rec.ranges(ckRowsRemoved) == @[(2, 2)]
    check rec.dropped() == @["m7"]
    check store.loadedIds() == @["m9", "m8", "m6", "m5"]
    check store.indexOfId("m9") == 0 # newer rows kept their index

  test "deleting a message inside a hole shrinks the hole":
    store.removeMessage("m2", clock = 2, totalCount = 9)
    checkInvariants(store, 9)
    check rec.ranges(ckRowsRemoved) == @[(5, 5)]
    check rec.dropped().len == 0
    check store.loadedIds() == @["m9", "m8", "m7", "m6", "m5"]
    check store.holes().len == 1
    check (store.holes()[0].firstIndex, store.holes()[0].lastIndex) == (5, 8)

  test "a deletion that cannot be located falls back to the count":
    store.removeMessage("unknown", clock = 8, totalCount = 9)
    checkInvariants(store, 9)
    check store.hasStaleRanks()

suite "count signals":

  setup:
    let store = newDenseStore()
    store.reset(10)
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)
    let rec = attach(store)

  test "growth adds dummies at the newest end and marks the ranks stale":
    store.setTotalCount(13)
    checkInvariants(store, 13)
    check rec.ranges(ckRowsInserted) == @[(0, 2)]
    check store.indexOfId("m9") == 3
    check store.hasStaleRanks()

  test "shrinkage eats dummies before loaded rows":
    store.setTotalCount(8)
    checkInvariants(store, 8)
    check rec.ranges(ckRowsRemoved) == @[(5, 6)]
    check store.loadedCount == 5
    check store.indexOfId("m9") == 0

  test "a shrink with no dummies left gives up loaded rows":
    store.applyPage(pageOfRanks(4, 0), firstRank = 4, totalCount = 10)
    check store.loadedCount == 10
    rec.clear()
    store.setTotalCount(8)
    checkInvariants(store, 8)
    check store.loadedCount == 8
    check store.rowAt(0).id == "m9"

  test "an unchanged count is not a change":
    store.setTotalCount(10)
    check rec.after.len == 0

suite "stale hole reconciliation":

  test "a page re-anchors islands after an ambiguous count change":
    let store = newDenseStore()
    store.reset(10)
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)
    # two messages actually arrived at the OLDEST end; the count signal alone
    # cannot say that, so the store puts the dummies at the newest end
    store.setTotalCount(12)
    checkInvariants(store, 12)
    check store.hasStaleRanks()
    check store.indexOfId("m5") == store.rankToIndex(5)

    # the next fetch says where those five really live now
    var refreshed: seq[LoadedRow] = @[]
    for rank in countdown(11, 7):
      refreshed.add(row("m" & $(rank - 2), (rank - 2).int64))
    store.applyPage(refreshed, firstRank = 11, totalCount = 12)
    checkInvariants(store, 12)
    check not store.hasStaleRanks()
    check store.loadedIds() == @["m9", "m8", "m7", "m6", "m5"]
    check store.indexOfId("m5") == store.rankToIndex(7)
    check store.holes().len == 1
    check (store.holes()[0].firstIndex, store.holes()[0].lastIndex) == (5, 11)

suite "chat switch":

  test "reset drops every loaded row and re-sizes the model":
    let store = newDenseStore()
    store.reset(10)
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)
    let rec = attach(store)

    store.reset(42)
    checkInvariants(store, 42)
    check rec.before.len == 1
    check rec.before[0].kind == ckReset
    check rec.kinds() == @[ckReset]
    check rec.dropped().sorted() == @["m5", "m6", "m7", "m8", "m9"]
    check store.loadedCount == 0
    check store.holes().len == 1
    check (store.holes()[0].firstIndex, store.holes()[0].lastIndex) == (0, 41)

  test "reset to an empty chat leaves no rows":
    let store = newDenseStore()
    store.reset(10)
    store.reset(0)
    checkInvariants(store, 0)
    check store.holes().len == 0

suite "neighbour roles across a dummy boundary":

  setup:
    let store = newDenseStore()
    store.reset(10)
    store.applyPage(pageOfRanks(9, 5), firstRank = 9, totalCount = 10)

  test "an unloaded neighbour reads as no neighbour at all":
    # index 4 is the oldest loaded row; index 5 is a dummy
    check store.olderNeighbourIndex(4) == -1
    check store.newerNeighbourIndex(4) == 3
    # the newest row has no newer neighbour either way
    check store.newerNeighbourIndex(0) == -1
    check store.olderNeighbourIndex(0) == 1

  test "the neighbour appears once the dummy is filled":
    let rec = attach(store)
    store.applyPage(pageOfRanks(4, 0), firstRank = 4, totalCount = 10)
    check store.olderNeighbourIndex(4) == 5
    check store.newerNeighbourIndex(5) == 4
    check rec.ranges(ckNeighbourRolesChanged) == @[(4, 4)]

  test "the neighbour disappears again when the row is evicted":
    store.setWindow(0, 0, margin = 0)
    store.setLoadedRowCap(3)
    store.evictIfNeeded()
    check store.loadedCount == 3
    check store.olderNeighbourIndex(2) == -1
    check store.newerNeighbourIndex(2) == 1

suite "eviction":

  setup:
    let store = newDenseStore(cap = 0) # unlimited while the fixture loads
    store.reset(1000)
    store.applyPage(pageOfRanks(699, 400), firstRank = 699, totalCount = 1000)

  test "loaded rows farthest from the window go first":
    store.setWindow(310, 319, margin = 5)
    store.setLoadedRowCap(20)
    let rec = attach(store)
    store.evictIfNeeded()
    checkInvariants(store, 1000)
    check store.loadedCount == 20
    for index in 305 .. 324:
      check store.isLoaded(index)
    check not store.isLoaded(304)
    check not store.isLoaded(325)
    check ckRowsInserted notin rec.kinds()
    check ckRowsRemoved notin rec.kinds()
    check rec.dropped().len == 280

  test "the cap never costs a window or margin row":
    store.setWindow(310, 319, margin = 5)
    store.setLoadedRowCap(4)
    store.evictIfNeeded()
    checkInvariants(store, 1000)
    check store.loadedCount == 20 # the protected rows survive the cap
    for index in 305 .. 324:
      check store.isLoaded(index)

  test "eviction is applied on every fill, keeping memory bounded":
    store.setWindow(0, 9, margin = 0)
    store.setLoadedRowCap(50)
    for start in countdown(399, 100, 100):
      store.applyPage(pageOfRanks(store.indexToRank(start - 99), store.indexToRank(start)),
                      firstRank = store.indexToRank(start - 99), totalCount = 1000)
      checkInvariants(store, 1000)
      check store.loadedCount <= 50

  test "an evicted region refetches correctly":
    store.setWindow(0, 9, margin = 0)
    store.setLoadedRowCap(20)
    store.evictIfNeeded()
    check store.loadedCount == 20
    check not store.isLoaded(500)

    store.setWindow(500, 509, margin = 0) # the user scrolled back down there
    let firstRank = store.indexToRank(500)
    store.applyPage(pageOfRanks(firstRank, firstRank - 9), firstRank = firstRank,
                    totalCount = 1000)
    checkInvariants(store, 1000)
    for index in 500 .. 509:
      check store.isLoaded(index)
      check store.rowAt(index).id == "m" & $store.indexToRank(index)

  test "dummies cost nothing: a 100k model holds only what was fetched":
    let big = newDenseStore(cap = 0)
    big.reset(100_000)
    big.applyPage(pageOfRanks(99_999, 99_950), firstRank = 99_999, totalCount = 100_000)
    checkInvariants(big, 100_000)
    check big.loadedCount == 50
    check big.holes().len == 1

# --------------------------------------------------------------------- fuzz

type Server = object
  ids: seq[string]      ## oldest-first; the position is the rank
  clocks: seq[int64]

proc pageFrom(server: Server, firstRank, limit: int): seq[LoadedRow] =
  var rank = min(firstRank, server.ids.high)
  while rank >= 0 and result.len < limit:
    result.add(row(server.ids[rank], server.clocks[rank]))
    rank -= 1

suite "random interleave":

  proc interleave(seed: int64) =
    var rng = initRand(seed)
    var server = Server()
    for i in 0 ..< 300:
      server.ids.add("s" & $i)
      server.clocks.add(int64((i + 1) * 4096))

    let store = newDenseStore(cap = 200)
    store.reset(server.ids.len)
    var nextId = 300

    for step in 0 ..< 600:
      case rng.rand(0 .. 5)
      of 0, 1:
        # fetch a page somewhere in the model
        if server.ids.len > 0:
          let firstRank = rng.rand(0 .. server.ids.high)
          let page = server.pageFrom(firstRank, rng.rand(1 .. 40))
          store.applyPage(page, firstRank, server.ids.len)
      of 2:
        # live message at the newest end
        let id = "s" & $nextId
        nextId += 1
        let clock = server.clocks[^1] + 4096
        server.ids.add(id)
        server.clocks.add(clock)
        store.appendLive(@[row(id, clock)], server.ids.len)
      of 3:
        # backfill: a message that belongs somewhere in the middle
        let at = rng.rand(1 .. server.ids.high)
        let gap = server.clocks[at] - server.clocks[at - 1]
        if gap >= 2:
          let id = "s" & $nextId
          nextId += 1
          let clock = server.clocks[at - 1] + gap div 2
          server.ids.insert(id, at)
          server.clocks.insert(clock, at)
          if rng.rand(0 .. 3) == 0:
            store.setTotalCount(server.ids.len) # ambiguous: count only
          else:
            store.insertBackfilled(row(id, clock), server.ids.len)
      of 4:
        # deletion
        if server.ids.len > 10:
          let at = rng.rand(0 .. server.ids.high)
          let id = server.ids[at]
          let clock = server.clocks[at]
          server.ids.delete(at)
          server.clocks.delete(at)
          if rng.rand(0 .. 3) == 0:
            store.setTotalCount(server.ids.len)
          else:
            store.removeMessage(id, clock, server.ids.len)
      else:
        # the window moves, which is what eviction is measured against
        let first = rng.rand(0 .. max(0, store.rowCount - 1))
        store.setWindow(first, min(store.rowCount - 1, first + 20), margin = 10)
        store.evictIfNeeded()

      checkInvariants(store, server.ids.len)
      check store.loadedCount <= 200 + 41 # cap, plus the window it may not evict
      if step mod 97 == 0:
        check store.rowCount == server.ids.len

    # fetching every hole until none is left must leave the model agreeing with
    # the server everywhere
    store.setLoadedRowCap(0)
    var passes = 0
    while store.holes().len > 0:
      passes += 1
      require passes <= 20
      for hole in store.holes():
        let firstRank = store.indexToRank(hole.firstIndex)
        let page = server.pageFrom(firstRank, min(25, hole.lastIndex - hole.firstIndex + 1))
        store.applyPage(page, firstRank, server.ids.len)
    checkInvariants(store, server.ids.len)
    check store.loadedCount == server.ids.len

    # holes are only half the story: a deletion the batch could not locate
    # leaves a stale row behind, and only a page covering it can retire that.
    # A full refetch must therefore reconcile the model to the server exactly.
    var sweeps = 0
    while true:
      sweeps += 1
      require sweeps <= 5
      var firstRank = server.ids.high
      while firstRank >= 0:
        let page = server.pageFrom(firstRank, 25)
        store.applyPage(page, firstRank, server.ids.len)
        firstRank -= page.len
      # a sweep releases the islands it contradicts, so it can leave holes of
      # its own behind; it has converged once it stops doing that
      if store.holes().len == 0:
        break
    checkInvariants(store, server.ids.len)
    check store.loadedCount == server.ids.len
    for index in 0 ..< store.rowCount:
      check store.rowAt(index).id == server.ids[store.indexToRank(index)]

  test "invariants survive fetches, live inserts, backfills and deletions":
    for seed in [20260821'i64, 7, 99, 123456, 2718281828]:
      interleave(seed)
