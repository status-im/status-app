## A held resource exists only while a holder needs it. The first holder loads
## it; at zero holders it is dropped after the idle delay (Idle release), and at
## once when the app goes to the background. A failed load is retried with
## backoff while holders remain; once they go, or on background, the resource is
## dropped (a failed reload leaves the data of the previous load).
##
## Every load gets a generation, and results are reported with it. Only results
## of the latest load count. That load stays current after a success, so a later
## failure of it is still taken; once a failure is taken it is no longer current,
## so a later success of it is ignored.
##
## Stale results are ignored only for this bookkeeping: the consumer tags its
## loaded data with the generation and never applies data of a superseded load.
##
## `HeldResources[K]` keeps one such resource per key behind one shared release
## timer and one shared retry timer.

import std/[sequtils, tables]

type
  HeldResourceTimer* = object
    start*: proc(ms: int)
    stop*: proc()
    # optional; frees the timer once its resource is disposed
    dispose*: proc()

  LoadGenerations = ref object
    last: int

  HeldResource* = ref object
    count: int
    active: bool
    failedLoads: int
    generations: LoadGenerations
    # the latest load's generation, 0 once dropped or once its failure is taken
    latestLoad: int
    disposed: bool
    idleReleaseMs: int
    releaseTimer: HeldResourceTimer
    retryTimer: HeldResourceTimer
    onLoad: proc(generation: int)
    onDrop: proc()

const
  DefaultIdleReleaseMs* = 120_000
  # the last one repeats
  LoadRetryDelaysMs* = [2_000, 5_000, 15_000, 60_000]

proc newHeldResource(releaseTimer, retryTimer: HeldResourceTimer, onLoad: proc(generation: int),
    onDrop: proc(), idleReleaseMs: int, generations: LoadGenerations): HeldResource =
  HeldResource(releaseTimer: releaseTimer, retryTimer: retryTimer, onLoad: onLoad, onDrop: onDrop,
    idleReleaseMs: idleReleaseMs, generations: generations)

proc newHeldResource*(releaseTimer, retryTimer: HeldResourceTimer, onLoad: proc(generation: int),
    onDrop: proc(), idleReleaseMs = DefaultIdleReleaseMs): HeldResource =
  newHeldResource(releaseTimer, retryTimer, onLoad, onDrop, idleReleaseMs, LoadGenerations())

proc holderCount*(self: HeldResource): int =
  self.count

proc isActive*(self: HeldResource): bool =
  ## A load was requested and the resource has not been dropped since.
  self.active

proc load(self: HeldResource) =
  self.active = true
  inc self.generations.last
  self.latestLoad = self.generations.last
  self.onLoad(self.latestLoad)

proc isLatestLoad(self: HeldResource, generation: int): bool =
  self.latestLoad != 0 and generation == self.latestLoad

proc retryPending(self: HeldResource): bool =
  not self.active and self.failedLoads > 0

proc stopRetrying(self: HeldResource) =
  self.retryTimer.stop()
  self.failedLoads = 0

proc drop(self: HeldResource) =
  self.active = false
  self.latestLoad = 0
  self.stopRetrying()
  self.onDrop()

proc acquire*(self: HeldResource) =
  if self.disposed:
    return
  inc self.count
  if self.count > 1:
    return
  self.releaseTimer.stop()
  if not self.active:
    self.stopRetrying()
    self.load()

proc release*(self: HeldResource) =
  if self.disposed or self.count == 0:
    return
  dec self.count
  if self.count > 0:
    return
  let stale = self.retryPending()
  self.stopRetrying()
  if self.active:
    self.releaseTimer.start(self.idleReleaseMs)
  elif stale:
    self.drop()

proc invalidate*(self: HeldResource) =
  ## The loaded data is outdated: a held resource loads again (the old data
  ## stays until the new load replaces it), an idle one is dropped now.
  if self.disposed:
    return
  if self.count > 0:
    if self.active:
      self.load()
    elif self.failedLoads > 0:
      self.stopRetrying()
      self.load()
  elif self.active:
    self.releaseTimer.stop()
    self.drop()

proc onReleaseTimeout*(self: HeldResource) =
  if not self.disposed and self.count == 0 and self.active:
    self.drop()

proc onRetryTimeout*(self: HeldResource) =
  if not self.disposed and self.count > 0 and not self.active:
    self.load()

proc onBackgrounded*(self: HeldResource) =
  if self.disposed:
    return
  let stale = self.retryPending()
  self.stopRetrying()
  if not self.active:
    if stale:
      self.drop()
    return
  self.releaseTimer.stop()
  self.drop()

proc onForegrounded*(self: HeldResource) =
  if not self.disposed and self.count > 0 and not self.active:
    self.load()

proc onLoadSucceeded*(self: HeldResource, generation: int) =
  if not self.disposed and self.isLatestLoad(generation):
    self.failedLoads = 0

proc onLoadFailed*(self: HeldResource, generation: int) =
  if self.disposed or not self.active or not self.isLatestLoad(generation):
    return
  if self.count == 0:
    # nobody waits for a retry; a reload left the data of the previous load
    self.releaseTimer.stop()
    self.drop()
    return
  self.active = false
  self.latestLoad = 0
  let delay = LoadRetryDelaysMs[min(self.failedLoads, LoadRetryDelaysMs.high)]
  inc self.failedLoads
  self.retryTimer.start(delay)

proc disposeTimer(timer: HeldResourceTimer) =
  timer.stop()
  if not timer.dispose.isNil:
    timer.dispose()

proc dispose*(self: HeldResource) =
  ## For teardown: every call afterwards does nothing and no callback runs.
  if self.disposed:
    return
  self.disposed = true
  self.releaseTimer.disposeTimer()
  self.retryTimer.disposeTimer()

const NoDeadline = int64.high

type
  HeldEntry = ref object
    resource: HeldResource
    releaseDue: int64
    retryDue: int64

  HeldResources*[K] = ref object
    entries: Table[K, HeldEntry]
    releaseTimer: HeldResourceTimer
    retryTimer: HeldResourceTimer
    # the deadline each shared timer is armed for
    releaseArmed: int64
    retryArmed: int64
    generations: LoadGenerations
    disposed: bool
    now: proc(): int64
    onLoad: proc(key: K, generation: int)
    onDrop: proc(key: K)
    idleReleaseMs: int

proc newHeldResources*[K](releaseTimer, retryTimer: HeldResourceTimer, now: proc(): int64,
    onLoad: proc(key: K, generation: int), onDrop: proc(key: K), idleReleaseMs = DefaultIdleReleaseMs): HeldResources[K] =
  ## `now` is a monotonic clock in milliseconds.
  HeldResources[K](releaseTimer: releaseTimer, retryTimer: retryTimer, now: now, onLoad: onLoad,
    onDrop: onDrop, idleReleaseMs: idleReleaseMs, releaseArmed: NoDeadline, retryArmed: NoDeadline,
    generations: LoadGenerations())

proc rearm(timer: HeldResourceTimer, armed: var int64, earliest, now: int64) =
  if earliest == armed:
    return
  armed = earliest
  if earliest == NoDeadline:
    timer.stop()
  else:
    timer.start(int(max(0'i64, earliest - now)))

proc rearmRelease[K](self: HeldResources[K]) =
  if self.disposed:
    return
  var earliest = NoDeadline
  for entry in self.entries.values:
    earliest = min(earliest, entry.releaseDue)
  self.releaseTimer.rearm(self.releaseArmed, earliest, self.now())

proc rearmRetry[K](self: HeldResources[K]) =
  if self.disposed:
    return
  var earliest = NoDeadline
  for entry in self.entries.values:
    earliest = min(earliest, entry.retryDue)
  self.retryTimer.rearm(self.retryArmed, earliest, self.now())

proc newEntry[K](self: HeldResources[K], key: K): HeldEntry =
  let entry = HeldEntry(releaseDue: NoDeadline, retryDue: NoDeadline)
  let registry = self
  entry.resource = newHeldResource(
    HeldResourceTimer(
      start: proc(ms: int) =
        entry.releaseDue = registry.now() + ms
        registry.rearmRelease(),
      stop: proc() =
        entry.releaseDue = NoDeadline
        registry.rearmRelease(),
    ),
    HeldResourceTimer(
      start: proc(ms: int) =
        entry.retryDue = registry.now() + ms
        registry.rearmRetry(),
      stop: proc() =
        entry.retryDue = NoDeadline
        registry.rearmRetry(),
    ),
    onLoad = proc(generation: int) = registry.onLoad(key, generation),
    onDrop = proc() = registry.onDrop(key),
    idleReleaseMs = self.idleReleaseMs,
    # shared, so a key held again does not reuse a dropped load's generation
    generations = self.generations,
  )
  entry

proc prune[K](self: HeldResources[K], key: K) =
  let entry = self.entries.getOrDefault(key)
  if not entry.isNil and entry.resource.holderCount == 0 and not entry.resource.isActive:
    self.entries.del(key)

proc len*[K](self: HeldResources[K]): int =
  ## Keys that are held or still loaded.
  self.entries.len

proc holderCount*[K](self: HeldResources[K], key: K): int =
  let entry = self.entries.getOrDefault(key)
  if entry.isNil: 0 else: entry.resource.holderCount

proc isActive*[K](self: HeldResources[K], key: K): bool =
  let entry = self.entries.getOrDefault(key)
  not entry.isNil and entry.resource.isActive

proc acquire*[K](self: HeldResources[K], key: K) =
  if self.disposed:
    return
  var entry = self.entries.getOrDefault(key)
  if entry.isNil:
    entry = self.newEntry(key)
    self.entries[key] = entry
  entry.resource.acquire()

template withEntry[K](self: HeldResources[K], key: K, action: untyped) =
  let entry {.inject.} = self.entries.getOrDefault(key)
  if not entry.isNil:
    action
    self.prune(key)

proc release*[K](self: HeldResources[K], key: K) =
  self.withEntry(key):
    entry.resource.release()

proc invalidate*[K](self: HeldResources[K], key: K) =
  self.withEntry(key):
    entry.resource.invalidate()

proc onLoadSucceeded*[K](self: HeldResources[K], key: K, generation: int) =
  self.withEntry(key):
    entry.resource.onLoadSucceeded(generation)

proc onLoadFailed*[K](self: HeldResources[K], key: K, generation: int) =
  self.withEntry(key):
    entry.resource.onLoadFailed(generation)

# Callbacks may add or remove keys, so these walk a snapshot of the keys.
proc invalidateAll*[K](self: HeldResources[K]) =
  for key in toSeq(self.entries.keys):
    self.invalidate(key)

proc onBackgrounded*[K](self: HeldResources[K]) =
  for key in toSeq(self.entries.keys):
    self.withEntry(key):
      entry.resource.onBackgrounded()

proc onForegrounded*[K](self: HeldResources[K]) =
  for key in toSeq(self.entries.keys):
    self.withEntry(key):
      entry.resource.onForegrounded()

proc onReleaseTimeout*[K](self: HeldResources[K]) =
  self.releaseArmed = NoDeadline
  let now = self.now()
  for key in toSeq(self.entries.keys):
    self.withEntry(key):
      if entry.releaseDue <= now:
        entry.releaseDue = NoDeadline
        entry.resource.onReleaseTimeout()
  self.rearmRelease()

proc onRetryTimeout*[K](self: HeldResources[K]) =
  self.retryArmed = NoDeadline
  let now = self.now()
  for key in toSeq(self.entries.keys):
    self.withEntry(key):
      if entry.retryDue <= now:
        entry.retryDue = NoDeadline
        entry.resource.onRetryTimeout()
  self.rearmRetry()

proc dispose*[K](self: HeldResources[K]) =
  ## For teardown: every call afterwards does nothing and no callback runs.
  if self.disposed:
    return
  self.disposed = true
  for entry in self.entries.values:
    entry.resource.dispose()
  self.entries.clear()
  self.releaseTimer.disposeTimer()
  self.retryTimer.disposeTimer()
