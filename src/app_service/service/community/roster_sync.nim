## Per-community roster load and delta ordering, without the roster itself.
## Snapshot and delta clocks are comparable (status-go#7932): a delta is applied
## only above the snapshot clock and never behind the last applied one.

import std/algorithm

import ./dto/roster

type
  RosterSyncState* {.pure.} = enum
    Empty
    Loading
    Loaded

  RosterSync* = object
    state*: RosterSyncState
    generation: int
    snapshotClock: uint64
    lastAppliedClock: uint64
    held: seq[RosterDelta]

proc beginLoad*(self: var RosterSync, generation: int): bool =
  ## True when a load has to start; `generation` identifies it.
  if self.state != RosterSyncState.Empty:
    return false
  self.state = RosterSyncState.Loading
  self.generation = generation
  self.held = @[]
  true

proc beginReload*(self: var RosterSync, generation: int): bool =
  ## Reloads the snapshot under a loaded roster, or supersedes the load in
  ## flight; deltas are held until the new snapshot. False without a roster.
  if self.state == RosterSyncState.Empty:
    return false
  self.state = RosterSyncState.Loading
  self.generation = generation
  true

proc needsReload*(self: RosterSync, deltas: openArray[RosterDelta]): bool =
  ## Channel gating comes from the snapshot only, so a token permission change
  ## takes a new one.
  if self.state == RosterSyncState.Empty:
    return false
  for delta in deltas:
    if delta.permissionsChanged:
      return true

proc release*(self: var RosterSync) =
  self = RosterSync()

proc failLoad*(self: var RosterSync, generation: int) =
  if self.state == RosterSyncState.Loading and self.generation == generation:
    self.release()

proc byClock(a, b: RosterDelta): int =
  cmp(a.clock, b.clock)

proc takeApplicable(self: var RosterSync, deltas: var seq[RosterDelta]): seq[RosterDelta] =
  deltas.sort(byClock)
  for delta in deltas.mitems:
    if delta.clock > self.snapshotClock and delta.clock >= self.lastAppliedClock:
      self.lastAppliedClock = delta.clock
      result.add move(delta)

proc acceptSnapshot*(self: var RosterSync, generation: int, clock: uint64,
    held: var seq[RosterDelta]): bool =
  ## False for a load that was released or superseded. Otherwise the roster is
  ## loaded and `held` gets the deltas to apply on top of the snapshot.
  if self.state != RosterSyncState.Loading or self.generation != generation:
    return false
  self.state = RosterSyncState.Loaded
  self.snapshotClock = clock
  self.lastAppliedClock = clock
  var pending = move(self.held)
  self.held = @[]
  held = self.takeApplicable(pending)
  true

proc acceptDeltas*(self: var RosterSync, deltas: seq[RosterDelta]): seq[RosterDelta] =
  ## The deltas to apply now, in clock order: none without a roster, none
  ## while loading (they are held).
  case self.state
  of RosterSyncState.Empty:
    discard
  of RosterSyncState.Loading:
    self.held.add deltas
  of RosterSyncState.Loaded:
    var pending = deltas
    result = self.takeApplicable(pending)
