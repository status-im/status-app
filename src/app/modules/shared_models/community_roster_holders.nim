## Who keeps a community roster alive. The first holder loads it; at zero
## holders it is dropped after RosterIdleReleaseMs (Idle release), and at once
## when the app goes to the background. A failed load is retried with backoff
## while holders remain; once they go, or on background, the roster is dropped
## (a failed reload leaves the rows of the old snapshot).

type
  RosterTimer* = object
    start*: proc(ms: int)
    stop*: proc()

  RosterHolders* = ref object
    count: int
    active: bool
    failedLoads: int
    releaseTimer: RosterTimer
    retryTimer: RosterTimer
    onLoad: proc()
    onDrop: proc()

const
  RosterIdleReleaseMs* = 120_000
  # the last one repeats
  RosterRetryDelaysMs* = [2_000, 5_000, 15_000, 60_000]

proc newRosterHolders*(releaseTimer, retryTimer: RosterTimer, onLoad: proc(), onDrop: proc()): RosterHolders =
  RosterHolders(releaseTimer: releaseTimer, retryTimer: retryTimer, onLoad: onLoad, onDrop: onDrop)

proc holderCount*(self: RosterHolders): int =
  self.count

proc isActive*(self: RosterHolders): bool =
  ## A load was requested and the roster has not been dropped since.
  self.active

proc load(self: RosterHolders) =
  self.active = true
  self.onLoad()

proc drop(self: RosterHolders) =
  self.active = false
  self.onDrop()

proc retryPending(self: RosterHolders): bool =
  not self.active and self.failedLoads > 0

proc stopRetrying(self: RosterHolders) =
  self.retryTimer.stop()
  self.failedLoads = 0

proc acquire*(self: RosterHolders) =
  inc self.count
  if self.count > 1:
    return
  self.releaseTimer.stop()
  if not self.active:
    self.stopRetrying()
    self.load()

proc release*(self: RosterHolders) =
  if self.count == 0:
    return
  dec self.count
  if self.count > 0:
    return
  let stale = self.retryPending()
  self.stopRetrying()
  if self.active:
    self.releaseTimer.start(RosterIdleReleaseMs)
  elif stale:
    self.drop()

proc onReleaseTimeout*(self: RosterHolders) =
  if self.count == 0 and self.active:
    self.drop()

proc onRetryTimeout*(self: RosterHolders) =
  if self.count > 0 and not self.active:
    self.load()

proc onBackgrounded*(self: RosterHolders) =
  let stale = self.retryPending()
  self.stopRetrying()
  if not self.active:
    if stale:
      self.drop()
    return
  self.releaseTimer.stop()
  self.drop()

proc onForegrounded*(self: RosterHolders) =
  if self.count > 0 and not self.active:
    self.load()

proc onLoadSucceeded*(self: RosterHolders) =
  self.failedLoads = 0

proc onLoadFailed*(self: RosterHolders) =
  if not self.active:
    return
  if self.count == 0:
    # nobody waits for a retry; a reload left the rows of the old snapshot
    self.releaseTimer.stop()
    self.drop()
    return
  self.active = false
  let delay = RosterRetryDelaysMs[min(self.failedLoads, RosterRetryDelaysMs.high)]
  inc self.failedLoads
  self.retryTimer.start(delay)
